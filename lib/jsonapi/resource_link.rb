require 'jsonapi/configuration'

module JSONAPI
  class ResourceLink
    attr :primary_resource, :association_name

    def initialize(primary_resource, association_name)
      @primary_resource = primary_resource
      @association_name = association_name
    end

    def association
      primary_resource._associations[association_name]
    end

    def type
      association.type.to_s.pluralize
    end

    def href(options = {})
      namespace = options.fetch(:namespace, '')
      base_url = options.fetch(:base_url, '')
      "#{base_url.blank? ? '' : base_url + '/'}#{namespace.blank? ? '' : namespace.underscore + '/'}#{association.type}/{#{primary_resource._type}.#{association_name.to_s}}"
    end
  end
end
