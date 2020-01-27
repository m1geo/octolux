# frozen_string_literal: true

begin
  # may not be installed if not on a Pi!
  require 'rpi_gpio'
rescue LoadError
  nil
end

class GPIO
  def initialize(gpios:)
    @gpios = gpios

    # do nothing if RPi is not available
    return unless defined?(RPi)

    RPi::GPIO.set_numbering(:board)

    # initialise each GPIOs as output
    gpios.each_value { |pin| setup(pin) }
  end

  def setup(pin)
    RPi::GPIO.setup(pin, as: :output)
  end

  def on(pin)
    RPi::GPIO.set_high(lookup_pin(pin))
  end

  def off(pin)
    RPi::GPIO.set_low(lookup_pin(pin))
  end

  def set(pin, value)
    value ? on(pin) : off(pin)
  end

  private

  def lookup_pin(pin)
    pin = gpios[pin] if pin.is_a?(String)
    raise 'unknown GPIO' unless pin

    pin
  end
end
