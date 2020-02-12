# frozen_string_literal: true

require 'pathname'
require 'net/http'
require 'uri'
require 'json'
require 'time'

# Solcast data integration.
#
#   #forecasts returns everything we have as a Hash. Keys are period_end, values are avg kW
#              for the half-hour leading up to that period_end.
#
#   #day filters #forecasts to the given Date.
#
# Since the figures are kW for 30 minutes, add them up and divide by 2 to get kWh for
# the given period:
#
#   .day(Date.today + 1).values.sum / 2
#   # => expected kWh for tomorrow
#
class Solcast
  def initialize(api_key:, resource_id:)
    @api_key = api_key
    @resource_id = resource_id
  end

  # We only get 10 API requests per day on the free Solcast tier,
  # so be careful about when we update it.
  def stale?
    forecasts.empty? || (Time.now - data_file.mtime) > 14_400
  end

  def update
    response = http.request(request)

    if response.is_a?(Net::HTTPOK)
      body = response.body
      # test that we have sane looking JSON before we save it
      @data = JSON.parse(body)

      data_file.write(body)
    else
      LOGGER.fatal "Error updating Solcast: #{response}"
    end
  end

  def forecasts
    Array(data&.fetch('forecasts', nil)).map do |t|
      [Time.parse(t['period_end']), t['pv_estimate']]
    end.compact.sort.to_h
  end

  def forecasts10
    Array(data&.fetch('forecasts', nil)).map do |t|
      [Time.parse(t['period_end']), t['pv_estimate10']]
    end.compact.sort.to_h
  end

  def forecasts90
    Array(data&.fetch('forecasts', nil)).map do |t|
      [Time.parse(t['period_end']), t['pv_estimate90']]
    end.compact.sort.to_h
  end

  #   Solcast.new.day(Date.today + 1).values.sum / 2
  def day(date)
    forecasts.select { |k, _| k.to_date == date }
  end

  def day10(date)
    forecasts10.select { |k, _| k.to_date == date }
  end

  def day90(date)
    forecasts90.select { |k, _| k.to_date == date }
  end

  private

  def data
    @data ||= JSON.parse(data_file.read)
  rescue Errno::ENOENT, JSON::ParserError
    nil
  end

  def data_file
    @data_file ||= Pathname.new('solcast_data.json')
  end

  def url
    @url ||= URI.parse("https://api.solcast.com.au/rooftop_sites/#{@resource_id}/forecasts.json")
  end

  def http
    @http ||= Net::HTTP.new(url.host, url.port).tap do |http|
      http.use_ssl = true
    end
  end

  def request
    @request ||= Net::HTTP::Get.new(url.request_uri).tap do |request|
      request.basic_auth @api_key, nil
    end
  end
end
