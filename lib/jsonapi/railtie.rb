require 'rails'

module JSONAPI
  class Railtie < Rails::Railtie

    initializer 'initialize_jsonapi_resources' do
      Mime::Type.register 'application/vnd.api+json', :jsonapi
    end
  end
end
