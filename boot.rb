# frozen_string_literal: true

Thread.abort_on_exception = true

# change directory to where octolux.rb lives; this lets us run from anywhere.
Dir.chdir(__dir__)

require 'bundler/setup'
require 'logger'

require 'inifile'
require 'zeitwerk'

LOGGER = Logger.new(STDOUT)

LOADER = Zeitwerk::Loader.new
LOADER.push_dir('lib')
LOADER.setup

CONFIG = IniFile.load('config.ini') || raise('config.ini not found!')
