require 'body_builder/version'
require 'body_builder/clause'
require 'active_support/core_ext/hash/deep_merge'
require 'active_support/core_ext/hash/keys'

module BodyBuilder
  class Builder
  
    attr_reader :filters, :queries, :raw_options, :sort_fields, :parent
    attr_accessor :base_query, :size, :from
  
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
  
    def build
      base_query = self.base_query.deep_transform_keys!{|k| k.to_sym}
      query = Marshal.load(Marshal.dump(base_query))

      base_query_is_bool = base_query[:query]&.key?(:bool)
      
      # Process queries and filters
      filters_and_queries = {filters: @filters, queries: @queries}
      
      hash = filters_and_queries.inject({}) do |acum, (type, object)|
        
        to_merge = if !base_query_is_bool && (type == :queries && !self.has_filters? && only_one_and_clause?(type))
          object[:and].first.build
        else

          is_simple_filter = type == :filters && 
            (
              only_one_and_clause?(type) ||
              (object[:or].empty? && !self.has_queries? && !object.any?{|k, v| v.any?{|c| c.block }})
            )
          
          mapping = if is_simple_filter
            { and: :filter, not: :must_not }
          else
            { and: :must, or: :should, not: :must_not }
          end

          # build bool clause
          object.inject({}) do |obj, (key, clauses)|
            next obj if clauses.empty?
  
            hash = if clauses.size == 1# && !base_query_is_bool
              clauses.first.build
            else
              clauses.map(&:build)
            end

            path = if parent
              [mapping[key]]
            elsif is_simple_filter || type == :queries
              [:bool, mapping[key]]
            else
              [:bool, :filter, :bool, mapping[key]]
            end

            obj = obj.deep_merge(
              path.reverse.inject(hash){|acum, key| {"#{key}".to_sym => acum } }
            )
            
          end
        end
    
        acum.deep_merge(to_merge)
      end

      raw_options.each do |option|
        query[option[:key]] = option[:value]
      end

      # RETURN if nested (skip sort, size, from )
      return hash if parent

      query.deep_merge!({query: hash}) unless hash.empty?

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

    def only_one_and_clause?(type)
      object = type == :filters ? self.filters : self.queries
      object[:and].length == 1 && object[:or].empty? && object[:not].empty?
    end

  end

end
