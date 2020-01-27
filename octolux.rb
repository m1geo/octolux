#! /usr/bin/env ruby
# frozen_string_literal: true

require_relative 'boot'

octopus = Octopus.new(key: CONFIG['octopus']['api_key'],
                      product_code: CONFIG['octopus']['product_code'],
                      tariff_code: CONFIG['octopus']['tariff_code'])
# if we have less than 6 hours of future $octopus tariff data, update it
octopus.update if octopus.stale?
unless octopus.price
  LOGGER.fatal 'No current Octopus price, aborting'
  exit 255
end

lc = LuxController.new(host: CONFIG['lxp']['host'],
                       port: CONFIG['lxp']['port'],
                       serial: CONFIG['lxp']['serial'],
                       datalog: CONFIG['lxp']['datalog'])

ls = LuxStatus.new(host: CONFIG['server']['host'],
                   port: CONFIG['server']['port'])

raise('rules.rb not found!') unless File.readable?('rules.rb')

# transitioning to local vars rather than globals to make web rules easier
$octopus = octopus
$lc = lc
$ls = ls

instance_eval(File.read('rules.rb'), 'rules.rb')
