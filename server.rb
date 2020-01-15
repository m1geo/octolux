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

# Global reference to a datastructure that HttpServer can read
DATA = {} # rubocop:disable Style/MutableConstant

# start a background thread which will listen for inverter packets
LuxThread = Thread.new do
  LuxListener.new.run
end

Rack::Server.start(Host: 'localhost', Port: 4346, app: HttpServer.freeze.app)
