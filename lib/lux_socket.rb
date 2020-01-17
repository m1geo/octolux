# frozen_string_literal: true

require 'socket'

class LuxSocket
  SOL_TCP = 6
  TCP_KEEPIDLE = 4

  def initialize(host:, port:)
    @host = host
    @port = port
  end

  # Write a packet to the socket.
  def write(pkt)
    socket.write(pkt.to_bin)
  end

  # Read a packet from the socket.
  #
  # This will return an LXP::Packet or nil if an error occurs.
  #
  def read_packet
    # read 6 bytes frame header, which should be:
    # 161, 26, proto1, proto2, len1, len2
    return unless (input1 = read_bytes(6))

    # verify the header in input1 looks reasonable
    header = input1.unpack('C*')
    return unless header[0..1] == [161, 26]

    # work out how long the rest of the packet should be
    len = header[4] + (header[5] << 8)

    # read the remaining bytes as dictated by the length from the header
    return unless (input2 = read_bytes(len))

    input = input1 + input2
    # LOGGER.debug "PACKET IN: #{input.unpack('C*')}"

    LXP::Packet::Parser.parse(input)
  end

  # Read packets from our socket until we find a reply to the passed in pkt.
  #
  # Discards all other input, which is fine for now. We might want them in
  # future, can deal with that later.
  #
  def read_reply(pkt)
    loop do
      # Return nil if read_packet returns :err (short read or timeout)
      return unless (r = socket.read_packet)

      # Return the packet if it matches the register we're looking for
      return r if r.is_a?(pkt.class) && r.register == pkt.register
    end
  end

  private

  def socket
    @socket ||= Socket.tcp(@host, @port, connect_timeout: 5).tap do |s|
      s.setsockopt(Socket::SOL_SOCKET, Socket::SO_KEEPALIVE, true)
      s.setsockopt(SOL_TCP, TCP_KEEPIDLE, 50)
      s.setsockopt(SOL_TCP, Socket::TCP_KEEPINTVL, 10)
      s.setsockopt(SOL_TCP, Socket::TCP_KEEPCNT, 5)
    end
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
