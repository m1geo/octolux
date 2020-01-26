# frozen_string_literal: true

class ZeitwerkReloader
  def initialize(app)
    @app = app
  end

  def call(env)
    LOADER.reload
    @app.call(env)
  end
end
