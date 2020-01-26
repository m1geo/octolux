#! /usr/bin/env ruby
# frozen_string_literal: true

require_relative 'boot'

# change directory to where octolux.rb lives; this lets us run from anywhere.
Dir.chdir(__dir__)

require 'rack'

# start a background thread which will listen for inverter packets
Thread.new { LuxListener.run }

Rack::Server.start(Host: 'localhost', Port: 4346, app: App.freeze.app)
