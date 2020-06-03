#! /usr/bin/env ruby
# frozen_string_literal: true

require_relative 'boot'

# change directory to where octolux.rb lives; this lets us run from anywhere.
Dir.chdir(__dir__)

require 'rack'

# connect to MQTT if configured
Thread.new { MQ.run } if CONFIG['mqtt']['uri']

# start a background thread which will listen for inverter packets
# in itself, this is wrapped in another thread to try and address
# reports of MQ stopping being updated. Unable to reproduce atm so
# this is a bodge.
Thread.new do
  loop do
    t = Thread.new do
      begin
        LuxListener.run
      rescue StandardError => e
        LOGGER.error "LuxListener Thread: #{e}"
        LOGGER.debug e.backtrace.join("\n")
        LOGGER.info 'Restarting LuxListener Thread in 5 seconds'
      end
    end
    t.join
    sleep 5
  end
end

Rack::Server.start(Host: CONFIG['server']['listen_host'] || CONFIG['server']['host'],
                   Port: CONFIG['server']['port'],
                   app: App.freeze.app)
