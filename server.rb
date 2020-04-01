#! /usr/bin/env ruby
# frozen_string_literal: true

require_relative 'boot'

# change directory to where octolux.rb lives; this lets us run from anywhere.
Dir.chdir(__dir__)

require 'rack'

# connect to MQTT if configured
Thread.new { MQ.run } if CONFIG['mqtt']['uri']

# start a background thread which will listen for inverter packets
Thread.new { LuxListener.run }

Rack::Server.start(Host: CONFIG['server']['listen_host'] || CONFIG['server']['host'],
                   Port: CONFIG['server']['port'],
                   app: App.freeze.app)
