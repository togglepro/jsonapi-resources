require 'jsonapi/formatter'

module JSONAPI
  class Configuration
    attr_reader :json_key_format,
                :key_formatter,
                :base_url,
                :url_template_style,
                :resource_links_style

    def initialize
      #:underscored_key, :camelized_key, :dasherized_key, or custom
      self.json_key_format = :underscored_key

      #:none | :href_only | :full
      self.url_template_style = :none

      self.base_url = ''

      #:ids | :collection_objects
      self.resource_links_style = :ids
    end

    def json_key_format=(format)
      @json_key_format = format
      @key_formatter = JSONAPI::Formatter.formatter_for(format)
    end

    def url_template_style=(url_template_style)
      raise ArgumentError.new(url_template_style) unless [:none, :href, :full].include?(url_template_style)
      @url_template_style = url_template_style
    end

    def base_url=(base_url)
      @base_url = base_url
    end

    def resource_links_style=(resource_links_style)
      raise ArgumentError.new(resource_links_style) unless [:ids, :collection_objects].include?(resource_links_style)
      @resource_links_style = resource_links_style
    end
  end

  class << self
    attr_accessor :configuration
  end

  @configuration ||= Configuration.new

  def self.configure
    yield(@configuration)
  end
end