#! /usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'logger'

require 'inifile'
require 'zeitwerk'

LOGGER = Logger.new(STDOUT)

loader = Zeitwerk::Loader.new
loader.push_dir('lib')
loader.setup

config = IniFile.load('config.ini')

octopus = Octopus.new(key: config['octopus']['api_key'],
                      product_code: config['octopus']['product_code'],
                      tariff_code: config['octopus']['tariff_code'])

# if we have less than 6 hours of future Octopus tariff data, update it
octopus.update if octopus.stale?

lux = LuxController.new(host: config['lxp']['host'],
                        port: config['lxp']['port'],
                        serial: config['lxp']['serial'],
                        datalog: config['lxp']['datalog'])

# LOGGER.info "Charge Power % = #{lux.charge_pct}"

LOGGER.info "Current Octopus Unit Price: #{octopus.price}p"

begin
  # if the current price is 5p or lower, enable AC charge
  if octopus.price <= 5
    lux.charge(true)
  else
    lux.charge(false)
  end
rescue LuxController::SocketError
  nil
end
