#! /usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'

require 'inifile'
require 'lxp/packet'
require 'zeitwerk'

loader = Zeitwerk::Loader.new
loader.push_dir('lib')
loader.setup

config = IniFile.load('config.ini')

octopus = Octopus.new(key: config['octopus']['api_key'],
                      product_code: config['octopus']['product_code'],
                      tariff_code: config['octopus']['tariff_code'])
octopus.update if octopus.stale?
p octopus.price

exit

# TODO: if we have less than 6 hours of future Octopus tariff data, update it

# TODO: set charge or discharge according to current price

lux = LuxController.new(host: config['lxp']['host'],
                        port: config['lxp']['port'],
                        serial: config['lxp']['serial'].to_s,
                        datalog: config['lxp']['datalog'].to_s)

p lux.charge(true)
