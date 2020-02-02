#! /usr/bin/env ruby
# frozen_string_literal: true

require_relative 'boot'

octopus = Octopus.new(product_code: CONFIG['octopus']['product_code'],
                      tariff_code: CONFIG['octopus']['tariff_code'])
# if we have less than 6 hours of future $octopus tariff data, update it
octopus.update if octopus.stale?
unless octopus.price
  LOGGER.fatal 'No current Octopus price, aborting'
  exit 255
end

lc = LuxController.new(host: CONFIG['lxp']['host'], # rubocop:disable Lint/UselessAssignment
                       port: CONFIG['lxp']['port'],
                       serial: CONFIG['lxp']['serial'],
                       datalog: CONFIG['lxp']['datalog'])

ls = LuxStatus.new(host: CONFIG['server']['host'], # rubocop:disable Lint/UselessAssignment
                   port: CONFIG['server']['port'])

# abstraction of RPi::GPIO
gpio = GPIO.new(gpios: CONFIG['gpios']) # rubocop:disable Lint/UselessAssignment

raise('rules.rb not found!') unless File.readable?('rules.rb')

instance_eval(File.read('rules.rb'), 'rules.rb')
