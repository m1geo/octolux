# frozen_string_literal: true

# this rules file attempts to intelligently set charging periods overnight,
# using the cheapest energy possible with Agile half-hourly prices. it attempts
# to get your batteries up to the "required_soc" percentage. This is worked out
# on the first run after 9pm (so we have overnight Agile prices).
#
# This works best if the script knows your current SOC, which means server.rb
# needs to be accessible. If it's not, this will assume the batteries are empty.
#
# TODO: the required_soc is currently hardcoded. If you have solar panels, this
# should be high in winter (90-100%) as there will be no sun, but lower in summer,
# as otherwise you may charge your batteries using energy costing money, but then
# the sun comes out and you could have charged them for free. So lowering it in
# summer will avoid using too much imported energy. A future improvement here is
# to integrate Solcast data to try and determine exactly which days will be sunny,
# automatically.
#
# It charges if the price is less than 2p, even if the SOC is high. It also
# enables charging for an "emergency boost" if it detects a peak period is
# approaching (defined as over 15p) and your SOC is below 50%.
#
# Additionally, it turns off discharging (making the inverter idle) if the
# Agile price is "cheap enough". This is a bit rudimentary at the moment but
# is currently set to activate if you're below 50% SOC, and the price is less
# than 1.2x the highest price we have in the cheap_slots file.

LOGGER.info "Current Price = #{octopus.price}p"

# constants that could move to config
battery_count = 6
charge_rate = 3.3 # kW

required_soc = 90 # TODO: solcast forecast could bias this
soc = ls.inputs['soc'] || 10 # assume 10% if we don't have it

system_size = 2.4 * battery_count # kWh per battery * number of batteries
usable_size = system_size * 0.8
charge_size = usable_size * ((required_soc - soc) / 100.0)
hours_required = charge_size / charge_rate # at a charge rate of 3.3kW
slots_required = (hours_required * 2).ceil # half-hourly Agile periods

slots_required = 0 if slots_required.negative?

LOGGER.info "SOC = #{soc}% / #{required_soc}%, " \
  "charge_size = #{charge_size.round(2)} kWh, " \
  "hours = #{hours_required.round(2)}"

# cheap_slot_data.json is our cache of what we'll be doing tonight.
f = Pathname.new('cheap_slot_data.json')
data = f.readable? ? JSON.parse(f.read) : {}
updated_at = data['updated_at']

after_8 = Time.now.hour >= 20
# stale = updated_at.nil? || Time.now - Time.parse(updated_at) > 14_400
have_prices = octopus.prices.count > 20

if after_8 && have_prices
  # if it is later than 9pm and we haven't run today, do so now
  cheapest_slots = octopus.prices
                          .take(20) # 10 hours
                          .sort_by { |_k, v| v }.to_h
                          .take(slots_required)
                          .sort.to_h

  cheapest_slots.each { |time, price| LOGGER.debug "Charge Slot: #{time} at #{price}p" }

  data = { 'updated_at' => Time.now, 'slots' => cheapest_slots }
  f.write(JSON.generate(data))
end

# enable charge if any of the keys in data['slots'] match the current half-hour period
now = Time.at(1800 * (Time.now.to_i / 1800))
charge = data['slots'].any? do |time, _price|
  time = Time.parse(time) unless time.is_a?(Time)
  time == now
end

LOGGER.info 'Charging due to cheap_slot_data' if charge

# override for any really cheap energy as a failsafe
if octopus.price < 2
  LOGGER.info 'Charging due to price < 2p'
  charge = true
end

# if a peak period is approaching and we're under 50%, start emergency charge
if soc < 50 && octopus.prices.values.take(3).max > 15 && octopus.price < 15
  LOGGER.warn 'Peak approaching, emergency charging'
  charge = true
end

# do not discharge if the electricity price is a percentage within the cost
# we've charged at. this avoids charging at 1p, to then discharge at 1.1p an hour later.
max_charge_price = data['slots'].values.max || 0
discharge_price_cap = max_charge_price * 1.2
discharge_pct = 100
discharge_pct = 0 if soc < 50 && octopus.price <= discharge_price_cap

LOGGER.debug "max_charge_price = #{max_charge_price}p; discharge_price_cap = #{discharge_price_cap}p"

if lc.discharge_pct != discharge_pct
  r = (lc.discharge_pct = discharge_pct)
  exit 255 unless r == discharge_pct
end

exit 255 unless lc.charge(charge)
