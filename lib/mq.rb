# frozen_string_literal: true

require 'mqtt/sub_handler'

class MQ
  class << self
    def run
      sub.subscribe_to 'octolux/cmd/ac_charge' do |data|
        LOGGER.info "MQ cmd/ac_charge => #{data}"
        r = lux_controller.charge(bool(data))
        lux_controller.close
        sub.publish_to('octolux/result/ac_charge', r ? 'OK' : 'FAIL')
      end

      sub.subscribe_to 'octolux/cmd/forced_discharge' do |data|
        LOGGER.info "MQ cmd/forced_discharge => #{data}"
        r = lux_controller.discharge(bool(data))
        lux_controller.close
        sub.publish_to('octolux/result/forced_discharge', r ? 'OK' : 'FAIL')
      end

      sub.subscribe_to 'octolux/cmd/charge_pct' do |data|
        LOGGER.info "MQ cmd/charge_pct => #{data}"
        r = (lux_controller.charge_pct = data.to_i)
        lux_controller.close
        sub.publish_to('octolux/result/charge_pct',
                       r == data.to_i ? 'OK' : 'FAIL')
      end

      sub.subscribe_to 'octolux/cmd/discharge_pct' do |data|
        LOGGER.info "MQ cmd/discharge_pct => #{data}"
        r = (lux_controller.discharge_pct = data.to_i)
        lux_controller.close
        sub.publish_to('octolux/result/discharge_pct',
                       r == data.to_i ? 'OK' : 'FAIL')
      end

      Thread.stop # sleep forever
    end

    def publish(topic, message)
      sub.publish_to(topic, message)
    end

    private

    def sub
      @sub ||= MQTT::SubHandler.new(CONFIG['mqtt']['uri'])
    end

    def lux_controller
      # FIXME: duplicated in octolux.rb, could move to boot.rb?
      @lux_controller ||= LuxController.new(host: CONFIG['lxp']['host'],
                                            port: CONFIG['lxp']['port'],
                                            serial: CONFIG['lxp']['serial'],
                                            datalog: CONFIG['lxp']['datalog'])
    end

    def bool(input)
      case input
      when true, 1, /\A(?:1|t(?:rue)?|y(?:es)?|on)\z/i then true
      else false
      end
    end
  end
end
