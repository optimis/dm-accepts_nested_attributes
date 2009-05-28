module DataMapper
  module NestedAttributes
    
    ##
    # This exception will only be thrown from
    # the accepts_nested_attributes_for method
    # if the passed options don't make sense
    class InvalidOptions < ArgumentError; end
    
    module Model
    
      ##
      # Makes the named association accept nested attributes.
      #
      # @param [Symbol|String] association_name
      #   The name of the association that should accept nested attributes
      # @param [Hash] options (optional)
      #   List of resources to initialize the Collection with
      #
      # @return nil
      def accepts_nested_attributes_for(association_name, options = {})
        
        # ----------------------------------------------------------------------------------
        #                      try to fail as early as possible
        # ----------------------------------------------------------------------------------
      
        # raise ArgumentError if association_name identifies no valid relationship
        relationship = relationship(association_name)

        # raise InvalidOptions if the given options don't make sense
        assert_valid_options_for_nested_attributes(options)
        
        # by default, nested attributes can't be destroyed
        options = { :allow_destroy => false }.update(options)
        
        
        # ----------------------------------------------------------------------------------
        #                       should be safe to go from here
        # ----------------------------------------------------------------------------------
        
        options_for_nested_attributes[association_name] = options
        
        include ::DataMapper::NestedAttributes::Resource
        
        add_save_behavior
        
        add_transactional_save_behavior # TODO if repository.adapter.supports_transactions?

        add_error_collection_behavior if DataMapper.const_defined?('Validate')
        
        type = relationship(association_name).max > 1 ? :collection : :one_to_one

        class_eval %{
        
          def #{association_name}_attributes
            @#{association_name}_attributes
          end
        
          def #{association_name}_attributes=(attributes)
            attributes = sanitize_nested_attributes(attributes)
            @#{association_name}_attributes = attributes
            assign_nested_attributes_for_#{type}_association(
              :#{association_name}, attributes, #{options[:allow_destroy]}
            )
          end

        }, __FILE__, __LINE__ + 1
      
      end
      
      
      # This allows to *fail fast* when trying to access a relationship that's not defined
      # Also, it hides the implementation detail how relationships are stored internally 
      def relationship(name, repository_name = default_repository_name)
        unless relationship = relationships(repository_name)[name]
          raise(ArgumentError, "No relationship #{name.inspect} for #{self.name} in #{repository_name}")
        end
        relationship
      end
      
      # options given to the accepts_nested_attributes method
      # guaranteed to be valid if they made it this far.
      def options_for_nested_attributes
        @options_for_nested_attributes ||= {}
      end
    
      # returns a Symbol, a String, or an object that responds_to :call
      # if there is an association called association_name
      # returns nil otherwise
      def reject_new_nested_attributes_guard_for(association_name)
        if options_for_nested_attributes[association_name]
          options_for_nested_attributes[association_name][:reject_if]
        end
      end


      private

      def add_save_behavior
        require Pathname(__FILE__).dirname.expand_path + 'save'
        include ::DataMapper::NestedAttributes::Save
      end

      def add_transactional_save_behavior
        require Pathname(__FILE__).dirname.expand_path + 'transactional_save'
        include ::DataMapper::NestedAttributes::TransactionalSave
      end

      def add_error_collection_behavior
        require Pathname(__FILE__).dirname.expand_path + 'error_collecting'
        include ::DataMapper::NestedAttributes::ValidationErrorCollecting
      end
      
      
      def assert_valid_options_for_nested_attributes(options)
        
        assert_kind_of 'options', options, Hash

        valid_options = [ :allow_destroy, :reject_if ]

        unless options.all? { |k,v| valid_options.include?(k) }
          raise InvalidOptions, 'options must be one of :allow_destroy or :reject_if'
        end

        guard = options[:reject_if]
        if guard.is_a?(Symbol) || guard.is_a?(String)
          msg = ":reject_if => #{guard.inspect}, but there is no instance method #{guard.inspect} in #{self.name}"
          raise InvalidOptions, msg unless instance_methods.include?(options[:reject_if].to_s)
        else
          msg = ":reject_if must be a Symbol|String or respond_to?(:call) "
          raise InvalidOptions, msg unless guard.nil? || guard.respond_to?(:call)
        end
        
      end
  
    end
    
  end
end