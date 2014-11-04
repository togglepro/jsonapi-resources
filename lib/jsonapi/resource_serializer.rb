module JSONAPI
  class ResourceSerializer
    include ActionController::UrlFor
    include Rails.application.routes.url_helpers

    # Converts a single resource, or an array of resources to a hash, conforming to the JSONAPI
    # structure. Options include:
    # include:
    #     Purpose: determines which objects will be side loaded with the source objects in a
    #              linked section
    #     Example: ['comments','author','comments.tags','author.posts']
    # fields:
    #     Purpose: determines which fields are serialized for a resource type. This encompasses
    #              both attributes and association ids in the links section for a resource. Fields
    #              are global for a resource type.
    #     Example: { people: [:id, :email, :comments], posts: [:id, :title, :author],
    #                comments: [:id, :body, :post]}
    # toplevel_links_style:
    #     Purpose: sets the style of top level links. Valid values are :none, :href_only, :full
    # resource_links_style:
    #     Purpose: sets the style of resource level links. Valid values are :ids, :collection_objects
    # base_url:
    #     Purpose: the base url for href generation
    # namespace:
    #     Purpose: the namespace for href generation

    def serialize_to_hash(source, options = {})
      is_resource_collection = source.respond_to?(:to_ary)
      return {} if source.nil? || (is_resource_collection && source.size == 0)

      @fields =  options.fetch(:fields, {})
      include = options.fetch(:include, [])
      @base_url = options.fetch(:base_url, '')
      @namespace = options.fetch(:namespace, '')

      @key_formatter = options.fetch(:key_formatter, JSONAPI.configuration.key_formatter)
      @toplevel_links_style = options.fetch(:toplevel_links_style,
                                            JSONAPI.configuration.toplevel_links_style)
      @resource_links_style = options.fetch(:resource_links_style,
                                            JSONAPI.configuration.resource_links_style)

      @linked_objects = {}
      @links = {}

      requested_associations = {}
      parse_includes(include, requested_associations)

      if is_resource_collection
        @primary_class_name = source[0].class._type
      else
        @primary_class_name = source.class._type
      end

      process_primary(source, requested_associations)

      primary_class_name = @primary_class_name.to_sym

      linked_hash = {}
      primary_objects = []
      @linked_objects.each do |class_name, objects|
        class_name = class_name.to_sym

        linked_objects = []
        objects.each_value do |object|
          if object[:primary]
            primary_objects.push(object[:object_hash])
          else
            linked_objects.push(object[:object_hash])
          end
        end
        linked_hash[format_key(class_name)] = linked_objects unless linked_objects.empty?
      end

      primary_hash = {}

      if @links.size > 0
        primary_hash.merge!({links: @links})
      end

      if is_resource_collection
        primary_hash.merge!({format_key(primary_class_name) => primary_objects})
      else
        primary_hash.merge!({format_key(primary_class_name) => primary_objects[0]})
      end

      if linked_hash.size > 0
        primary_hash.merge({linked: linked_hash})
      else
        primary_hash
      end
    end

    private
    def add_top_level_links(resource_type)
      return if @toplevel_links_style == :none
      resource = Resource.resource_for(resource_type)
      resource._associations.each_value do |association|
        href = association.href_template(resource_type, namespace: @namespace, base_url: @base_url)
        @links["#{resource._type}.#{association.name}"] = case @toplevel_links_style
          when :full
            {
              href: href,
              type: association.type.to_s
            }
          when :href
            href
          else
            # :nocov:
            raise ArgumentError.new(@toplevel_links_style)
          # :nocov:
        end
      end
    end

    # Convert an array of associated objects to include along with the primary document in the form of
    # ['comments','author','comments.tags','author.posts'] into a structure that tells what we need to
    # include from each association.
    def parse_includes(includes, requested_associations)
      includes.each do |include|
        include = include.to_s.underscore

        pos = include.index('.')
        if pos
          association_name = include[0, pos].to_sym
          requested_associations[association_name] ||= {}
          requested_associations[association_name].store(:include_children, true)
          requested_associations[association_name][:include_related] ||= {}
          parse_includes([include[pos+1, include.length]],
                         requested_associations[association_name][:include_related])
        else
          association_name = include.to_sym
          requested_associations[association_name] ||= {}
          requested_associations[association_name].store(:include, true)
        end
      end if includes.is_a?(Array)
    end

    # Process the primary source object(s). This will then serialize associated object recursively
    # based on the requested includes. Fields are controlled fields option for each resource type,
    # such as fields: { people: [:id, :email, :comments], posts: [:id, :title, :author],
    #   comments: [:id, :body, :post]}
    # The fields options controls both fields and included links references.
    def process_primary(source, requested_associations)
      if source.respond_to?(:to_ary)
        source.each do |resource|
          id = resource.id
          if already_serialized?(@primary_class_name, id)
            set_primary(@primary_class_name, id)
          end
          add_primary_object(@primary_class_name, id, object_hash(resource, requested_associations))
        end
      else
        resource = source
        id = resource.id
        add_primary_object(@primary_class_name, id, object_hash(source, requested_associations))
      end
    end

    # Returns a serialized hash for the source model
    def object_hash(source, requested_associations)
      obj_hash = attribute_hash(source)
      links = links_hash(source, requested_associations)
      obj_hash.merge!({links: links}) unless links.empty?
      return obj_hash
    end

    def requested_fields(model)
      @fields[model] if @fields
    end

    def attribute_hash(source)
      requested = requested_fields(source.class._type)
      fields = source.fetchable_fields & source.class._attributes.keys.to_a
      unless requested.nil?
        fields = requested & fields
      end

      fields.each_with_object({}) do |name, hash|
        hash[format_key(name)] = format_value(source.send(name),
                                              source.class._attribute_options(name)[:format],
                                              source)
      end
    end

    def collection_hash(source, association)
      foreign_key = association.foreign_key

      ids = source.send(foreign_key)
      return nil if ids.nil?

      case @resource_links_style
        when :collection_objects
          href = association.href(ids, namespace: @namespace, base_url: @base_url)
          {
            ids: ids,
            href: href,
            type: association.type.to_s
          }
        when :ids
          ids
        else
          # :nocov:
          raise ArgumentError.new(@resource_links_style)
        # :nocov:
      end
    end

    # Returns a hash of links for the requested associations for a resource, filtered by the
    # resource class's fetchable method
    def links_hash(source, requested_associations)
      associations = source.class._associations
      requested = requested_fields(source.class._type)
      fields = associations.keys
      unless requested.nil?
        fields = requested & fields
      end

      field_set = Set.new(fields)

      included_associations = source.fetchable_fields & associations.keys
      associations.each_with_object({}) do |(name, association), hash|
        if included_associations.include? name
          if field_set.include?(name)
            hash[format_key(name)] = collection_hash(source, association)
          end

          ia = requested_associations.is_a?(Hash) ? requested_associations[name] : nil

          include_linked_object = ia && ia[:include]
          include_linked_children = ia && ia[:include_children]

          type = association.type

          # If the object has been serialized once it will be in the related objects list,
          # but it's possible all children won't have been captured. So we must still go
          # through the associations.
          if include_linked_object || include_linked_children
            if association.is_a?(JSONAPI::Association::HasOne)
              resource = source.send(name)
              if resource
                id = resource.id
                associations_only = already_serialized?(type, id)
                if include_linked_object && !associations_only
                  add_linked_object(type, id, object_hash(resource, ia[:include_related]))
                elsif include_linked_children || associations_only
                  links_hash(resource, ia[:include_related])
                end
              end
            elsif association.is_a?(JSONAPI::Association::HasMany)
              resources = source.send(name)
              resources.each do |resource|
                id = resource.id
                associations_only = already_serialized?(type, id)
                if include_linked_object && !associations_only
                  add_linked_object(type, id, object_hash(resource, ia[:include_related]))
                elsif include_linked_children || associations_only
                  links_hash(resource, ia[:include_related])
                end
              end
            end
          end
        end
      end
    end

    def already_serialized?(type, id)
      type = format_key(type)
      return @linked_objects.key?(type) && @linked_objects[type].key?(id)
    end

    # Sets that an object should be included in the primary document of the response.
    def set_primary(type, id)
      type = format_key(type)
      @linked_objects[type][id][:primary] = true
    end

    def store_object(type, id, primary, obj)
      formatted_type = format_key(type)
      unless already_serialized?(formatted_type, id)
        unless @linked_objects.key?(formatted_type)
          @linked_objects[formatted_type] = {}
          add_top_level_links(type)
        end
        @linked_objects[formatted_type].store(id, {primary: primary, object_hash: obj})
      end
    end

    def add_primary_object(type, id, object_hash)
      formatted_type = format_key(type)

      if already_serialized?(formatted_type, id)
        set_primary(formatted_type, id)
      else
        store_object(type, id, true, object_hash)
      end
    end

    # Collects the hashes for linked objects processed by the serializer
    def add_linked_object(type, id, object_hash)
      store_object(type, id, false, object_hash)
    end

    def format_key(key)
      @key_formatter.format(key)
    end

    def format_value(value, format, source)
      value_formatter = JSONAPI::ValueFormatter.value_formatter_for(format)
      value_formatter.format(value, source)
    end
  end
end
