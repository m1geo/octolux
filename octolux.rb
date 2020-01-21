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

config = IniFile.load('config.ini') || raise('$config.ini not found!')

$octopus = Octopus.new(key: config['octopus']['api_key'],
                       product_code: config['octopus']['product_code'],
                       tariff_code: config['octopus']['tariff_code'])
# if we have less than 6 hours of future $octopus tariff data, update it
$octopus.update if $octopus.stale?
unless $octopus.price
  LOGGER.fatal 'No current Octopus price, aborting'
  exit 255
end

$lc = LuxController.new(host: config['lxp']['host'],
                        port: config['lxp']['port'],
                        serial: config['lxp']['serial'],
                        datalog: config['lxp']['datalog'])

$ls = LuxStatus.new(host: config['server']['host'],
                    port: config['server']['port'])

File.readable?('rules.rb') ? load('rules.rb') : raise('rules.rb not found!')
