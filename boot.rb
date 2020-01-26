# frozen_string_literal: true

Thread.abort_on_exception = true

# change directory to where octolux.rb lives; this lets us run from anywhere.
Dir.chdir(__dir__)

require 'bundler/setup'
require 'logger'

require 'inifile'
require 'zeitwerk'

LOGGER = Logger.new(STDOUT)

loader = Zeitwerk::Loader.new
loader.push_dir('lib')
loader.setup
