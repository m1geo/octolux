# frozen_string_literal: true

# octopus contains tariff price data
#   octopus.price is current cost in pence
#   octopus.prices is a hash of all known price data, keyed by time
LOGGER.info "Current Octopus Unit Price: #{octopus.price}p"

# $lc is LuxController. This talks directly to the inverter and can do things
# like enabling/disabling AC charge and setting charge power rates.
# LOGGER.info "Charge Power = #{lc.charge_pct}%"

# $ls is LuxStatus. This is gleaned from the optional server.rb since the
# data in it is only sent by the inverter every 2 minutes.
#   .data is a hash of data. this will be empty if we cannot fetch the status
# LOGGER.info "Battery SOC = #{ls.data['soc']}%" if ls.data['soc']

begin
  # if the current price is 5p or lower, enable AC charge
  charge = octopus.price <= 5

  # experimental GPIO support. turn a GPIO on when charge is true, off if false.
  # gpio.set('zappi', charge)

  unless lc.charge(charge)
    LOGGER.error 'Failed to update inverter status!'
    exit 255
  end
rescue StandardError => e
  LOGGER.error "Error: #{e}"
  exit 255
end
