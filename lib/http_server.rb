# frozen_string_literal: true

require 'roda'

class HttpServer < Roda
  plugin :json

  route do |r|
    r.on 'api' do
      r.get 'inputs' do
        LuxListener.inputs
      end
    end
  end
end
