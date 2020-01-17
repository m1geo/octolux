# frozen_string_literal: true

require 'lxp/packet'

# This starts in a thread and watches for incoming traffic from the inverter.
#
class LuxListener
  def run
    loop do
      begin
        listen
      rescue StandardError => e
        LOGGER.error "Socket Error: #{e}"
        LOGGER.info 'Reconnecting in 5 seconds'
        sleep 5
      end
    end
  end

  def listen
    socket = LuxSocket.new(host: CONFIG['lxp']['host'],
                           port: CONFIG['lxp']['port'])

    loop do
      next unless (pkt = socket.read_packet)

      # ReadInput* updates global state for HttpServer to return
      DATA.merge!(pkt.to_h) if pkt.is_a?(LXP::Packet::ReadInput)
    end
  end
end
