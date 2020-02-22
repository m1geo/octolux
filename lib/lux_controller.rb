# frozen_string_literal: true

require 'lxp/packet'

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
    set_register(LXP::Packet::Registers::CHARGE_POWER_PERCENT_CMD, pct)
  end

  # Get current discharge power %
  def discharge_pct
    read_register(LXP::Packet::Registers::DISCHG_POWER_PERCENT_CMD)
  end

  # Set current discharge power %
  def discharge_pct=(pct)
    set_register(LXP::Packet::Registers::DISCHG_POWER_PERCENT_CMD, pct)
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
      LOGGER.debug "update_register(#{register}) => no action required"
      return true
    end

    new_val = enable ? old_val | bit : old_val & ~bit
    ret_val = set_register(register, new_val)

    new_val == ret_val
  end

  def read_register(register)
    LOGGER.debug "read_register(#{register})"
    pkt = packet(type: LXP::Packet::ReadHold, register: register)
    socket.write(pkt)
    unless (r = socket.read_reply(pkt))
      LOGGER.fatal 'invalid/no reply from inverter'
      raise SocketError
    end

    LOGGER.debug "read_register(#{register}) => #{r.value}"

    r.value
  end

  def set_register(register, val)
    LOGGER.debug "set_register(#{register}, #{val})"

    pkt = packet(type: LXP::Packet::WriteSingle, register: register)
    pkt.value = val

    socket.write(pkt)
    unless (r = socket.read_reply(pkt))
      LOGGER.fatal 'invalid/no reply from inverter'
      raise SocketError
    end

    LOGGER.debug "set_register(#{register}) => #{r.value}"

    r.value
  end

  def socket
    @socket ||= LuxSocket.new(host: @host, port: @port)
  end

  def packet(type:, register:)
    type.new.tap do |pkt|
      pkt.register = register
      pkt.datalog_serial = @datalog
      pkt.inverter_serial = @serial
    end
  end
end
