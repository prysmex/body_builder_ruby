require 'body_builder/version'
require 'body_builder/clause'
require 'active_support/core_ext/hash/deep_merge'
require 'active_support/core_ext/hash/keys'

module BodyBuilder
  class Builder
  
    attr_reader :filters, :queries, :raw_options, :sort_fields, :parent
    attr_accessor :base_query, :size, :from, :query_minimum_should_match, :filter_minimum_should_match
  
    # @param base_query [Hash] starting query definition
    # @param parent [Clause] parent clause when nested
    def initialize(base_query: {}, parent: nil)
      @base_query = base_query
      @parent = parent
      reset!
    end
  
    def filter(*args, &block)
      _add_clause(true, :and, *args, &block)
    end
    alias_method :and_filter, :filter
  
    def or_filter(*args, &block)
      _add_clause(true, :or, *args, &block)
    end
  
    def not_filter(*args, &block)
      _add_clause(true, :not, *args, &block)
    end
  
    def query(*args, &block)
      _add_clause(false, :and, *args, &block)
    end
    alias_method :and_query, :query
  
    def or_query(*args, &block)
      _add_clause(false, :or, *args, &block)
    end
  
    def not_query(*args, &block)
      _add_clause(false, :not, *args, &block)
    end

    def raw_option(key, value)
      @raw_options << {key: key, value: value}
      self
    end

    def sort_field(field, direction = 'asc')
      field = field.to_sym
      sort = sort_fields.find{|obj| obj.key?(field) }
      if sort
        sort[field] = direction
      else
        @sort_fields << {"#{field}".to_sym => direction}
      end
      self
    end

    def set_size(size)
      @size = size
      self
    end

    def set_from(from)
      @from = from
      self
    end

    def set_query_minimum_should_match(min, override: false)
      self.query_minimum_should_match = min
      self
    end

    def set_filter_minimum_should_match(min)
      self.filter_minimum_should_match = min
      self
    end

    # return [Boolean] true if any filter clause is present
    def has_filters?(key=nil)
      [:and, :or, :not].any? do |k|
        next if key && k != key
        !@filters[k].empty?
      end
    end
  
    # return [Boolean] true if any query clause is present
    def has_queries?(key=nil)
      [:and, :or, :not].any? do |k|
        next if key && k != key
        !@queries[k].empty?
      end
    end
  
    def build
      query = Marshal.load(Marshal.dump(self.base_query)) #dup
      query.deep_transform_keys!{|k| k.to_sym}
      base_query_is_bool = query[:query]&.key?(:bool)

      if query.key?(:query) && !base_query_is_bool
        raise StandardError.new('cannot build query when base query root is not bool clause')
      end
      
      # Process queries and filters
      if !base_query_is_bool && !self.has_filters? && only_one_and_clause?(:queries)
        query[:query] = self.queries[:and].first.build
      else
        {filters: @filters, queries: @queries}.each do |type, object|
          
          is_simple_filter = type == :filters && 
            (
              only_one_and_clause?(type) ||
              (object[:or].empty? && !self.has_queries? && !object.any?{|k, v| v.any?{|c| c.block }})
            )
  
          # build bool clause
          object.each do |key, clauses|
            next if clauses.empty?
  
            hash = clauses.map(&:build)
            hash = hash.first if clauses.size == 1 # && !base_query_is_bool
            
            scope = if parent
              #query
              query[:query] ||= {}
            elsif is_simple_filter || type == :queries
              #query.bool
              query[:query] ||= {}
              query[:query][:bool] ||= {}
            else
              #query.bool.filter.bool
              query[:query] ||= {}
              query[:query][:bool] ||= {}
              filter = query[:query][:bool][:filter] ||= {}
              if filter.is_a? Array
                h = {bool: {}}
                filter.push(h)
                h[:bool]
              else
                query[:query][:bool][:filter][:bool] ||= {}
              end
            end

            mapping = if is_simple_filter
              { and: :filter, not: :must_not }
            else
              { and: :must, or: :should, not: :must_not }
            end

            mapped_key = mapping[key]

            # add or merge to
            if scope.key?(mapped_key)
              value = scope[mapped_key]
              value = [value] unless value.is_a? Array
              if hash.is_a?(Array)
                value.concat(hash)
              else
                value.push(hash)
              end
            else
              scope[mapped_key] = hash
            end

            if mapped_key == :should && scope[:should].is_a?(Array)
              if type == :queries
                scope[:minimum_should_match] = self.query_minimum_should_match unless self.query_minimum_should_match.nil?
              else
                scope[:minimum_should_match] = self.filter_minimum_should_match unless self.filter_minimum_should_match.nil?
              end
            end

          end

        end
      end

      raw_options.each do |option|
        query[option[:key]] = option[:value]
      end

      # RETURN if nested (skip sort, size, from )
      return query.key?(:query) ? query[:query] : query if parent

      query[:sort] = sort_fields unless sort_fields.empty?
      query[:size] = @size unless @size.nil?
      query[:from] = @from unless @from.nil?
  
      query
    end
  
    private
  
    # @param type [String] Query type.
    # @param field [String, Hash] Field to query or complete query clause.
    # @param value [String, Hash] Query term or inner clause.
    # @param options [Hash] (optional) Additional options for the query clause.
    def _add_clause(is_filter, key, type, field=nil, value=nil, options={}, &block)
      obj = is_filter ? self.filters : self.queries
      obj[key] << Clause.new(type, field, value, options, self, &block)
      self
    end

    # Calls all resetters
    def reset!
      reset_queries!
      reset_filters!
      reset_raw_options!
      reset_sort_fields!
      from = nil
      size = nil
    end

    # Empties queries
    def reset_queries!
      @queries = {
        and: [],
        or: [],
        not: []
      }
    end

    # Empties filters
    def reset_filters!
      @filters = {
        and: [],
        or: [],
        not: []
      }
    end

    # Empties raw_options
    def reset_raw_options!
      @raw_options = []
    end

    # Empties sort fields
    def reset_sort_fields!
      @sort_fields = []
    end

    def only_one_and_clause?(type)
      object = type == :filters ? self.filters : self.queries
      object[:and].length == 1 && object[:or].empty? && object[:not].empty?
    end

  end

end
