# frozen_string_literal: true
# USE THIS FILE CAUTIOUSLY - IT IS NOT WELL TESTED!!
# TODO: 
# Bias charge size based on Solcast - present but untested and disabled.
# Add summer/winter toggle as Solcast seems unreliable in winter. Only use it in summer.
# Re-add in Agile-biased discharge - useful for larger batteries.

now = Time.at(1800 * (Time.now.to_i / 1800))
#LOGGER.info "Current working time = #{now}"

# Solcast data collection based on https://github.com/abwbuchanan/octolux/
# Determine if we want today or tomorrows forecast
if (now.hour < 20)
        forecastdate = Date.today
else
        forecastdate = Date.today+1
end
solgen_raw = solcast.day(forecastdate).values.sum / 2
solgen = solgen_raw / CONFIG['solcast']['site_calibration_factor'].to_f

# Load baseload and convert from W to kWh/30mins
base = (CONFIG['solcast']['base_load'])
basehh = base.to_f / 2000

# Calculate excess solar by subtracting baseload.
solexc_h_raw = solcast.day(forecastdate).transform_values { |v| [v - basehh, 0].max }
solexc_raw = solexc_h_raw.values.sum / 2
solexc = solexc_raw / CONFIG['solcast']['site_calibration_factor'].to_f

# Print everything to log for auditing:
LOGGER.info "Entered base load = #{base}w"
LOGGER.info "Solar date = #{forecastdate}"
LOGGER.info "Solar kWh available = #{solgen.round(2)} kWh (raw: #{solgen_raw.round(2)} kWh)"
LOGGER.info "Excess solar kWh available = #{solexc.round(2)} kWh (raw: #{solexc_raw.round(2)} kWh)"

# Grab current SOC and Required SOC
required_soc = CONFIG['rules']['required_soc']
if (soc = ls.inputs['soc'])
  LOGGER.info "Battery SoC: #{soc}% (Desired SoC: #{required_soc}%)"
else
  LOGGER.warn "Can't get SOC % from server.rb, assuming 10%"
  soc = 10
end

# Load battery size and calculate charge size required
battery_count = CONFIG['lxp']['batteries'].to_i
charge_rate = [3, battery_count].min # No rate increase after 3 batteries
system_size = 2.4 * battery_count # kWh per battery
LOGGER.info "Batteries present: #{battery_count} (#{system_size} kWh storage capacity)"
#charge_size = (system_size * ((required_soc.to_f - soc.to_f) / 100.0)) #- solexc # # #Bias' charge size based on solcast. Still to test.
charge_size = (system_size * ((required_soc.to_f - soc.to_f + 5) / 100.0)) - (solexc * 0.2) # GSHACK
charge_size = 0 if charge_size.negative?
hours_required = charge_size / charge_rate.to_f
slots_required = (hours_required * 2).ceil # half-hourly Agile periods
LOGGER.info "AC charge of #{charge_size.round(2)} kWh (~#{hours_required.round(1)}h) needed in addition to solar"

# Use Solcast to set max charge price.
# If lots of solar, we only want to charge when import is cheap
if ((solexc * 0.3) > charge_size.to_f)
  max_charge_price = CONFIG['rules']['max_charge_high_solar'].to_i
  LOGGER.info "Excess solar calculated:"
else
  max_charge_price = CONFIG['rules']['max_charge'].to_i
  LOGGER.info "Low solar generation:"
end
LOGGER.info "  AC charge price set to #{max_charge_price}p/kWh maximum"

# Agile pricing
all_imp_slots_sorted = octopus_imp.prices.sort_by { |_k, v| v }
all_exp_slots_sorted = octopus_exp.prices.sort_by { |_k, v| v }
abs_cheapest_imp = all_imp_slots_sorted[0][1]
abs_dearest_imp  = all_imp_slots_sorted[-1][1]
abs_cheapest_exp = all_exp_slots_sorted[0][1]
abs_dearest_exp  = all_exp_slots_sorted[-1][1]

LOGGER.info "Current Price: #{octopus_imp.price.round(3)}p/kWh (import) #{octopus_exp.price.round(3)}p/kWh (export)"
LOGGER.info "Import Price Extremes: #{abs_cheapest_imp.round(3)}p/kWh (min) -> #{abs_dearest_imp.round(3)}p/kWh (max)"
LOGGER.info "Export Price Extremes: #{abs_cheapest_exp.round(3)}p/kWh (min) -> #{abs_dearest_exp.round(3)}p/kWh (max)"

f = Pathname.new('slot_data_m1geo.json')
data = f.readable? ? JSON.parse(f.read) : {}

# Find dearest slots
most_expensive_imp = all_imp_slots_sorted.clone # clone, don't butcher original
most_expensive_imp = most_expensive_imp.reverse!
most_expensive_imp = most_expensive_imp.shift(8).to_h
LOGGER.info "Most Expensive Import Slots:"
most_expensive_imp.sort.each { |time, price| LOGGER.info "  Dearest: #{time} @ #{price}p/kWh" }

# At present; don't care when we charge, just use the cheapest slots
# In future;  detect dearest slots, then find cheapest ones within a few hours before and hold charge!
charge_slots = all_imp_slots_sorted.clone # clone, don't butcher original
charge_slots = charge_slots.shift(slots_required).to_h
charge_slots = charge_slots.delete_if { |_time, price| price > max_charge_price }.to_h
if charge_slots.length > 0
  LOGGER.info "Charging Slots:"
  charge_slots.sort.each { |time, price| LOGGER.info "  Charging: #{time} @ #{price}p/kWh" }
else
  LOGGER.info "No charging slots required/available."
end

# merge in any slots with a price cheaper than cheap_charge from config
cheap_charge = CONFIG['rules']['cheap_charge'].to_f
cheap_slots = octopus_imp.prices.select { |_time, price| price <= cheap_charge }
if cheap_slots.length > 0
  LOGGER.info "Cheap Bonus Slots (<=#{cheap_charge}p/kWh):"
  cheap_slots.sort.each { |time, price| LOGGER.info "  Cheap Charge: #{time} @ #{price}p/kWh" }
  charge_slots.merge!(cheap_slots)
else
  LOGGER.info "No cheap (<=#{cheap_charge}p/kWh) slots."
end

# Find best selling slots
max_sell_slots = CONFIG['rules']['max_sell_slots'].to_i
most_expensive_exp = all_exp_slots_sorted.clone # clone, don't butcher original
most_expensive_exp = most_expensive_exp.reverse!
most_expensive_exp = most_expensive_exp.shift(max_sell_slots).to_h
LOGGER.info "Most Expensive Export Slots:"
most_expensive_exp.sort.each { |time, price| LOGGER.info "  Dearest: #{time} @ #{price}p/kWh" }

# Dump the charge data out.
data = { 'updated_at' => Time.now, 'charge_slots' => charge_slots, 'cheapest_import' => cheap_slots, 'dearest_import' => most_expensive_imp, 'dearest_export' => most_expensive_exp }
f.write(JSON.generate(data))

# this is just used for informational logging. Need to convert back to Time if loaded from JSON.
#t = (charge_slots.keys + discharge_slots.keys).map { |n| n.is_a?(Time) ? n : Time.parse(n) }
#idle = octopus_imp.prices.reject { |k, _v| t.include?(k) }
#idle.sort.each { |time, price| LOGGER.info "Idle: #{time} @ #{price}p" }

# Simplified discharge routine
# Allow for higher discharge price prior to 3pm to conserve charge for peak period
# A lower discharge price after peak will let rest of battery discharge
if ( now.hour < 15 )
  min_discharge_price = CONFIG['rules']['pre_discharge']
  LOGGER.info "Prepeak, min discharge price set to #{min_discharge_price}p"
else
  min_discharge_price = CONFIG['rules']['post_discharge']
  LOGGER.info "Postpeak, min discharge price set to #{min_discharge_price}p"
end

#emergency_soc = CONFIG['rules']['emergency_soc'] || 50
# if a peak period is approaching and SOC is low, start emergency charge
#if soc < emergency_soc.to_i && octopus_imp.prices.values.take(5).max > 15 && octopus_imp.price < max_charge_price && now.hour > 12
#  LOGGER.warn 'Peak approaching, emergency charging'
#  ac_charge = true
#end

# enable ac_charge if any of the keys match the current half-hour period
ac_charge = charge_slots.any? { |time, _price| time == now }

# enable force export if any keys match the current half-hour period
#min_sell_profit = CONFIG['rules']['min_sell_profit'].to_f
#force_dis1  = most_expensive_exp.any? { |time, _price| time == now }
#force_dis2 = (abs_dearest_exp - abs_cheapest_imp) > min_sell_profit
#force_dis = (force_dis1 && force_dis2)
force_dis = false

# enable discharge if current price is above specificed price
discharge = ( octopus_imp.price.to_f >= min_discharge_price.to_f )

# go hard or go home on the discharge; legacy has it all or nothing
discharge_pct = discharge ? 100 : 0

LOGGER.info "Inverter Status:"
LOGGER.info "  ac_charge:           #{ac_charge ? "Yes" : "No"}"
LOGGER.info "  max_charge_price:    #{max_charge_price.round(2)} p/kWh"
LOGGER.info "  discharge:           #{discharge ? "Yes (#{discharge_pct} %)" : "No"}"
LOGGER.info "  force_discharge:     #{force_dis ? "Yes ((#{abs_dearest_exp.round(2)} - #{abs_cheapest_imp.round(2)} = #{(abs_dearest_exp - abs_cheapest_imp).round(2)}) > #{min_sell_profit} p/kWh) " : "No"}"
LOGGER.info "  min_discharge_price: #{min_discharge_price.round(2)} p/kWh"

r = (lc.discharge_pct = discharge_pct)
exit 255 unless r == discharge_pct
exit 255 unless lc.discharge(force_dis)
exit 255 unless lc.charge(ac_charge)
