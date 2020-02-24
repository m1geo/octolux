#! /usr/bin/env ruby
# frozen_string_literal: true

require_relative '../boot'

lc = LuxController.new(host: CONFIG['lxp']['host'],
                       port: CONFIG['lxp']['port'],
                       serial: CONFIG['lxp']['serial'],
                       datalog: CONFIG['lxp']['datalog'])

lc.charge(false)
