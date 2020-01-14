# frozen_string_literal: true

require 'socket'

class LuxController
  SocketError = Class.new(StandardError)

  def initialize(host:, port:, serial:, datalog:)
    @host = host
    @port = port
    # these can be numeric, but we want them as strings to put into data packets
    @serial = serial.to_s
    @datalog = datalog.to_s
  end

  def charge(enable)
    LOGGER.debug "charge(#{enable})"
    update_register(21, LXP::Packet::RegisterBits::AC_CHARGE_ENABLE, enable)
  end

  def discharge(enable)
    LOGGER.debug "discharge(#{enable})"
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

  # Untested - get current discharge power %
  def discharge_pct
    read_register(LXP::Packet::Registers::DISCHG_POWER_PERCENT_CMD)
  end

  # Untested - set current discharge power %
  def discharge_pct=(pct)
    set_register(LXP::Packet::Registers::DISCHG_POWER_PERCENT_CMD, pct) == pct
  end

  private

  # Update a given register (21 for AC CHARGE/DISCHARGE) with the given bit
  # (AC_CHARGE_ENABLE or FORCED_DISCHARGE_ENABLE) setting it on or off.
  #
  # Returns true if the bit was already as requested, or updated.
  #
  def update_register(register, bit, enable)
    LOGGER.debug "update_register(#{register}, #{bit}, #{enable})"

    old_val = read_register(register)
    enabled = (old_val & bit) == bit
    if enable == enabled
      LOGGER.debug 'register already has correct value, nothing to do'
      return true
    end

    new_val = enable ? old_val | bit : old_val & ~bit
    ret_val = set_register(register, new_val)

    new_val == ret_val
  end

  def read_register(register)
    LOGGER.debug "read_register(#{register})"
    pkt = packet(type: LXP::Packet::ReadHold, register: register)
    socket.write(pkt.to_bin)
    unless (r = read_reply(pkt))
      LOGGER.fatal 'invalid/no reply from inverter'
      raise SocketError
    end

    LOGGER.debug "read_register #{register} result = #{r.value}"
    r.value
  end

  def set_register(register, val)
    LOGGER.debug "set_register(#{register} #{val})"

    pkt = packet(type: LXP::Packet::WriteSingle, register: register)
    pkt.value = val

    socket.write(pkt.to_bin)
    unless (r = read_reply(pkt))
      LOGGER.fatal 'invalid/no reply from inverter'
      raise SocketError
    end

    r.value
  end

  def socket
    @socket ||= Socket.tcp(@host, @port, connect_timeout: 5)
  rescue Errno::ETIMEDOUT
    LOGGER.fatal 'Timed out connecting to inverter'
    raise SocketError
  rescue Errno::EHOSTUNREACH
    LOGGER.fatal 'Inverter not reachable (can you ping it?)'
    raise SocketError
  rescue Errno::EHOSTDOWN
    LOGGER.fatal 'Inverter appears to be off the network (can you ping it?)'
    raise SocketError
  end

  def packet(type:, register:)
    type.new.tap do |pkt|
      pkt.register = register
      pkt.datalog_serial = @datalog
      pkt.inverter_serial = @serial
    end
  end

  # Read packets from our socket until we find a reply to the passed in pkt.
  #
  # Discards all other input, which is fine for now. We might want them in
  # future, can deal with that later.
  #
  def read_reply(pkt)
    loop do
      # Return nil if read_packet returns nil (short read or timeout)
      return unless (r = read_packet)

      # Return the packet if it matches the register we're looking for
      return r if r.is_a?(pkt.class) && r.register == pkt.register
    end
  end

  def read_packet
    # read 6 bytes frame header, which should be:
    # 161, 26, proto1, proto2, len1, len2
    return unless (input1 = read_bytes(6))

    # verify the header in input1 looks reasonable
    header = input1.unpack('C*')
    return unless header[0, 1] == [161, 26]

    # work out how long the rest of the packet should be
    len = header[4] + (header[5] << 8)

    # read the remaining bytes as dictated by the length from the header
    return unless (input2 = read_bytes(len))

    input = input1 + input2
    # LOGGER.debug "PACKET IN: #{input.unpack('C*')}"
    LXP::Packet::Parser.parse(input)
  end

  # Read len bytes from our socket.
  #
  # Returns those bytes, or nil if we timeout before reading enough bytes.
  #
  def read_bytes(len)
    r = String.new

    loop do
      # Read bytes with a 5 second timeout.
      # If no bytes are read before the timeout, return nil.
      rlen = len - r.size
      return unless (input = read(rlen, 5))

      r << input

      return r if r.size == len
    end
  end

  # Read up to len bytes with a timeout.
  def read(len, timeout)
    socket.read_nonblock(len)
  rescue IO::WaitReadable
    retry if IO.select([socket], nil, nil, timeout)
  end
end
