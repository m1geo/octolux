#! /usr/bin/env ruby
# frozen_string_literal: true

require_relative '../boot'

require 'mqtt/sub_handler'

sub = MQTT::SubHandler.new(CONFIG['mqtt']['uri'])
mutex = Mutex.new
cv = ConditionVariable.new

result_topic = 'octolux/result/ac_charge'
cmd_topic = 'octolux/cmd/ac_charge'
cmd_message = true

sub.subscribe_to result_topic do |data|
  LOGGER.info "received MQ #{result_topic}: #{data.inspect}"
  mutex.synchronize { cv.signal }
end

LOGGER.info "sending MQ #{cmd_topic} => #{cmd_message}"
sub.publish_to(cmd_topic, cmd_message)

LOGGER.info 'waiting up to 5s for MQ reply...'
mutex.synchronize { cv.wait(mutex, 5) }

LOGGER.info 'done!'
