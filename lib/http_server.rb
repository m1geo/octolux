# frozen_string_literal: true

require 'roda'

class HttpServer < Roda
  plugin :json

  route do |r|
    # get SOC?
    # enable/disable AC charge?

    r.get do
      DATA
    end
  end
end
