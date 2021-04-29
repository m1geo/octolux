#! /usr/bin/env ruby
# frozen_string_literal: true

require 'time'
require_relative 'boot'

solcast = Solcast.new(api_key: CONFIG['solcast']['api_key'],
                      resource_id: CONFIG['solcast']['resource_id'])

solcast_slate = solcast.stale(CONFIG['solcast']['max_forecast_age'])
solcast_valid_updating_window = Time.now.hour < 22 # true if update allowed - time in UTC
solcast_updated = (solcast_slate and solcast_valid_updating_window)
LOGGER.debug "Solcast valid window = #{solcast_valid_updating_window}"
LOGGER.debug "Solcast stale data   = #{solcast_slate}"
solcast.update if solcast_updated
LOGGER.info "Solcast data updated = #{solcast_updated}"

octopus = Octopus.new(product_code: CONFIG['octopus']['product_code'],
                      tariff_code: CONFIG['octopus']['tariff_code'])
# if we have less than 6 hours of future $octopus tariff data, update it
octopus.update if octopus.stale?
unless octopus.price
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
