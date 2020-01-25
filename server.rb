#! /usr/bin/env ruby
# frozen_string_literal: true

Thread.abort_on_exception = true

require 'bundler/setup'
require 'logger'
require 'rack'

require 'inifile'
require 'zeitwerk'

LOGGER = Logger.new(STDOUT)

loader = Zeitwerk::Loader.new
loader.push_dir('lib')
loader.setup

CONFIG = IniFile.load('config.ini')

# start a background thread which will listen for inverter packets
Thread.new { LuxListener.run }

Rack::Server.start(Host: 'localhost', Port: 4346, app: HttpServer.freeze.app)
