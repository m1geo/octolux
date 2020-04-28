# frozen_string_literal: true

require 'roda'

class App < Roda
  plugin :json

  route do |r|
    r.on 'api' do
      r.get 'inputs' do
        LuxListener.inputs
      end

      r.get 'registers' do
        LuxListener.registers
      end
    end
  end
end
