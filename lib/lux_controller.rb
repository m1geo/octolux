# frozen_string_literal: true

require 'socket'

class LuxController
  SocketReadError = Class.new(StandardError)

  def initialize(host:, port:, serial:, datalog:)
    @host = host
    @port = port
    @serial = serial
    @datalog = datalog
  end

  def charge(enable)
    update_register(21, LXP::Packet::RegisterBits::AC_CHARGE_ENABLE, enable)
  end

  def discharge(enable)
    update_register(
      21, LXP::Packet::RegisterBits::FORCED_DISCHARGE_ENABLE, enable
    )
  end

  # Untested - get current charge power %
  def charge_pct
    read_register(LXP::Packet::Registers::CHARGE_POWER_PERCENT_CMD)
  end

  # Untested - set current charge power %
  def charge_pct=(pct)
    set_register(LXP::Packet::Registers::CHARGE_POWER_PERCENT_CMD, pct) == pct
  end

  private

  # Update a given register (21 for AC CHARGE/DISCHARGE) with the given bit
  # (AC_CHARGE_ENABLE or FORCED_DISCHARGE_ENABLE) setting it on or off.
  #
  # Returns true if the bit was already as requested, or updated.
  #
  def update_register(register, bit, enable)
    old_val = read_register(register)
    enabled = (old_val & bit) == bit
    return true if enable == enabled

    new_val = enable ? old_val | bit : old_val & ~bit
    ret_val = set_register(register, new_val)

    new_val == ret_val
  end

  def read_register(register)
    pkt = packet(type: LXP::Packet::ReadHold, register: register)
    socket.write(pkt.to_bin)
    raise SocketReadError unless (r = read_reply(pkt))

    r.value
  end

  def set_register(register, val)
    pkt = packet(type: LXP::Packet::WriteSingle, register: register)
    pkt.value = val

    puts "set_register #{register} #{val} - ignoring"
    return val

    socket.write(pkt.to_bin)
    raise SocketReadError unless (r = read_reply(pkt))

    r.value
  end

  def socket
    @socket ||= TCPSocket.new(@host, @port)
  end

  def packet(type:, register:)
    type.new.tap do |pkt|
      pkt.register = register
      pkt.datalog_serial = @datalog
      pkt.inverter_serial = @serial
    end
  end

  def read_reply(pkt)
    loop do
      return unless IO.select([socket], nil, nil, 2)

      # read 6 bytes frame header, which should be:
      # 161, 26, proto1, proto2, len1, len2
      input1 = socket.recvfrom(6)[0]
      return unless input1.length == 6

      # now read the remaining bytes as dictated by the length
      header = input1.unpack('C*')
      len = header[4] + (header[5] << 8)

      input2 = socket.recvfrom(len)[0]
      return unless input2.length == len

      input = input1 + input2
      # puts "IN: #{input.unpack('C*')}"

      r = LXP::Packet::Parser.parse(input)
      return r if r.is_a?(pkt.class) && r.register == pkt.register
    end
  end
end
