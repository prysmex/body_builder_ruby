require 'body_builder/version'
require 'body_builder/clause'
require 'active_support/core_ext/hash/deep_merge'

module BodyBuilder
  class Builder
    
    BOOL_MAP = {
      and: :must,
      or: :should,
      not: :must_not
    }
  
    # Utility that converts queries or filters object into a bool clause
    # NOTICE: if ONLY 1 clause exists and it is inside 'and' key, the returned
    # hash is NOT wrapped in a bool clause
    MAYBE_WRAP_IN_BOOL = lambda do |object|
  
      #return if condition met
      if (object[:and].length == 1 &&
          object[:or].empty? &&
          object[:not].empty?)
            return object[:and].first.build
      end
  
      # build bool clause
      BOOL_MAP.each_with_object({}) do |(old_k, new_k), obj|
        value = object[old_k]
        next if value.empty?
        obj[:bool] ||= {}
        if value.size == 1
          obj[:bool][new_k] = value.first.build
        else
          obj[:bool][new_k] = value.map(&:build)
        end
      end
    end
  
    attr_reader :base_query, :filters, :queries, :raw_options, :sort_fields, :parent
  
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

    def size(size)
      @size = size
      self
    end

    def from(from)
      @from = from
      self
    end
  
    def build
      query = Marshal.load(Marshal.dump(base_query))
      bool_filters = MAYBE_WRAP_IN_BOOL.call(@filters)
      bool_queries = MAYBE_WRAP_IN_BOOL.call(@queries)

      # RETURN plain object when child
      if parent
        return [bool_filters, bool_queries].inject({}) do |acum, o|
          acum.merge(o)
        end
      end
      
      # filters
      if !bool_filters.empty?
        query.deep_merge!({query: {bool: {filter: bool_filters}}})
      end
  
      # queries
      if !bool_queries.empty?
        query.deep_merge!({query: bool_queries})
      end

      raw_options.each do |option|
        query[option[:key]] = option[:value]
      end

      query[:sort] = sort_fields unless sort_fields.empty?
      query[:size] = @size unless @size.nil?
      query[:from] = @from unless @from.nil?
  
      # _.set(clonedBody, 'aggs', aggregations)if @aggregations
      # _.set(clonedBody, 'suggest', suggest)if @suggest
  
      query
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

  end

end
