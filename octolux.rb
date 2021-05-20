#! /usr/bin/env ruby
# frozen_string_literal: true

require 'time'
require_relative 'boot'

solcast = Solcast.new(api_key: CONFIG['solcast']['api_key'],
                      resource_id: CONFIG['solcast']['resource_id'])

solcast_slate = solcast.stale(CONFIG['solcast']['max_forecast_age'])
solcast_valid_updating_window = Time.now.hour < 22 # true if update allowed - time as per machine time
solcast_updated = (solcast_slate and solcast_valid_updating_window)
#LOGGER.debug "Solcast valid window = #{solcast_valid_updating_window}"
#LOGGER.debug "Solcast stale data   = #{solcast_slate}"
solcast.update if solcast_updated
LOGGER.info "Solcast data updated = #{solcast_updated}"

## IMPORT OCTOPUS
octopus_imp = Octopus.new(product_code: CONFIG['octopus']['import_product_code'],
                      tariff_code: CONFIG['octopus']['import_tariff_code'],
                      tariff_type: "import")
# if we have less than 6 hours of future $octopus tariff data, update it
octopus_imp.update if octopus_imp.stale?
unless octopus_imp.price
  LOGGER.fatal 'No current Octopus price, aborting'
  exit 255
end

## EXPORT OCTOPUS
octopus_exp = Octopus.new(product_code: CONFIG['octopus']['export_product_code'],
                      tariff_code: CONFIG['octopus']['export_tariff_code'],
                      tariff_type: "export")
# if we have less than 6 hours of future $octopus tariff data, update it
octopus_exp.update if octopus_exp.stale?
unless octopus_exp.price
  LOGGER.fatal 'No current Octopus price, aborting'
  exit 255
end

# rubocop:disable Lint/UselessAssignment

# FIXME: duplicated in mq.rb, could move to boot.rb?
lc = LuxController.new(host: CONFIG['lxp']['host'],
                       port: CONFIG['lxp']['port'],
                       serial: CONFIG['lxp']['serial'],
                       datalog: CONFIG['lxp']['datalog'])

ls = LuxStatus.new(host: CONFIG['server']['connect_host'] || CONFIG['server']['host'],
                   port: CONFIG['server']['port'])

# rubocop:enable Lint/UselessAssignment

raise('rules.rb not found!') unless File.readable?('rules.rb')

instance_eval(File.read('rules.rb'), 'rules.rb')
