# frozen_string_literal: true

# This starts in a thread and watches for incoming traffic from the inverter.
#
# It kind of abuses LuxController to get #read_packet, maybe the network methods
# could be split out from LuxController to be more accessible.
#
class LuxListener
  def run
    loop do
      next unless (pkt = lux_controller.read_packet)

      # ReadInput* updates global state for HttpServer to return
      DATA.merge!(pkt.to_h) if pkt.is_a?(LXP::Packet::ReadInput)
    end
  end

  private

  def lux_controller
    @lux_controller ||= LuxController.new(host: CONFIG['lxp']['host'],
                                          port: CONFIG['lxp']['port'],
                                          serial: CONFIG['lxp']['serial'],
                                          datalog: CONFIG['lxp']['datalog'])
  end
end
