# frozen_string_literal: true

require 'lxp/packet'

# This starts in a thread and watches for incoming traffic from the inverter.
#
class LuxListener
  class << self
    def run
      loop do
        listen(LuxSocket.new(host: CONFIG['lxp']['host'], port: CONFIG['lxp']['port']))
      rescue StandardError => e
        LOGGER.error "Socket Error: #{e}"
        LOGGER.info 'Reconnecting in 5 seconds'
        sleep 5
      end
    end

    # A Hash containing merged input data, as parsed by LXP::Packet::ReadInput
    def inputs
      @inputs ||= {}
    end

    # A Hash containing register information we've seen from LXP::Packet::ReadHold packets
    def registers
      @registers ||= {}
    end

    private

    def listen(socket)
      loop do
        next unless (pkt = socket.read_packet)

        inputs.merge!(pkt.to_h) if pkt.is_a?(LXP::Packet::ReadInput)
        registers[pkt.register] = pkt.value if pkt.is_a?(LXP::Packet::ReadHold)
      end
    end
  end
end
