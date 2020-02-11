# frozen_string_literal: true

require 'pathname'
require 'net/http'
require 'uri'
require 'json'
require 'time'

class Octopus
  def initialize(product_code:, tariff_code:)
    @product_code = product_code
    @tariff_code = tariff_code
  end

  # True if we have no data, or we're running out of tariff data;
  # defined as being within 7 hours of the last time.
  #
  # Given that Octopus return data until 11pm, this will start returning true
  # from around 4pm, which is when new prices are generally published.
  #
  def stale?
    prices.empty? || prices.keys.last - Time.now < 25_200
  end

  # Update local data with the most recent API data
  def update
    response = http.request(request)

    if response.is_a?(Net::HTTPOK)
      body = response.body
      # test that we have sane looking JSON before we save it
      @tariff_data = JSON.parse(body)

      tariff_data_file.write(body)
    else
      LOGGER.fatal "Error updating Octopus: #{response}"
    end
  end

  # Munge tariff data into a hash of ascending time (from) -> price (inc vat),
  # starting with the current time period
  #
  # Cope with nil from tariff_data, which can happen if there's no data.
  #
  def prices
    Array(tariff_data&.fetch('results', nil)).map do |t|
      # skip periods before the current time
      next unless Time.parse(t['valid_to']) >= Time.now

      [Time.parse(t['valid_from']), t['value_inc_vat']]
    end.compact.sort.to_h
  end

  # Current price
  def price
    now = Time.at(1800 * (Time.now.to_i / 1800))
    prices[now]
  end

  private

  def tariff_data
    @tariff_data ||= JSON.parse(tariff_data_file.read)
  rescue Errno::ENOENT, JSON::ParserError
    nil
  end

  def tariff_data_file
    Pathname.new('tariff_data.json')
  end

  def url
    @url ||= begin
               time_from = Time.now.strftime('%Y-%m-%dT%H:00:00')
               URI.parse('https://api.octopus.energy' \
                         "/v1/products/#{@product_code}/electricity-tariffs" \
                         "/#{@tariff_code}/standard-unit-rates/" \
                         "?period_from=#{time_from}")
             end
  end

  def http
    @http ||= Net::HTTP.new(url.host, url.port).tap do |http|
      http.use_ssl = true
    end
  end

  def request
    @request ||= Net::HTTP::Get.new(url.request_uri)
  end
end
