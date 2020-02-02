# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

# LuxStatus is a simple wrapper to connect to server.rb at the specified
# host/port, and expose the JSON data it returns.
#
# #data returns an empty hash for any error. It will cache the response so
# if you want to fetch fresh data you currently need to make a new LuxStatus
# object.
#
#   LuxStatus.new(host: 'localhost', port: 4346).inputs
#   # => {"status"=>32, "v_bat"=>50.0, "soc"=>34, ... }
#
# I re-used port 4346 but note this is localhost (server.rb), NOT the inverter.
#
class LuxStatus
  def initialize(host:, port:)
    @host = host
    @port = port
  end

  def inputs
    @data ||= JSON.parse(response('/api/inputs')&.body)
  rescue TypeError
    # when #response returns nil (no implicit conversion of nil into String)
    {}
  rescue JSON::ParserError
    # bad JSON response from server
    {}
  end

  private

  def response(path)
    http = Net::HTTP.new(@host, @port)
    http.request(Net::HTTP::Get.new(path))
  rescue StandardError
    nil
  end
end
