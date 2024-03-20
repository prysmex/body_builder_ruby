# frozen_string_literal: true

require 'body_builder/version'
require 'body_builder/clause'
require 'active_support/core_ext/hash/deep_merge'
require 'active_support/core_ext/hash/keys'

module BodyBuilder
  #
  # Used to create elasticsearch queries with a simple and predictible API.
  # It is possible to create almost every possible elasticsearch query with
  # this class.
  #
  # For examples, see the specs
  #
  class Builder

    attr_reader :filters, :queries, :raw_options, :sort_fields, :parent
    attr_accessor :base_query, :size, :from, :query_minimum_should_match, :filter_minimum_should_match

    # Initialize the builder instance
    #
    # @param [Hash] base_query starting query definition
    # @param [Clause] parent the parent clause when nested
    def initialize(base_query: {}, parent: nil)
      @base_query = base_query
      @parent = parent
      reset!
    end

    # Adds a *and* *filter* clause. For examples, see the specs
    #
    # @return [Builder] self
    def filter(*args, &block)
      _add_clause(true, :and, *args, &block)
    end
    alias and_filter filter

    # Adds a *or* *filter* clause. For examples, see the specs
    #
    # @return [Builder] self
    def or_filter(*args, &block)
      _add_clause(true, :or, *args, &block)
    end

    # Adds a *not* *filter* clause. For examples, see the specs
    #
    # @return [Builder] self
    def not_filter(*args, &block)
      _add_clause(true, :not, *args, &block)
    end

    # Adds a *and* *query* clause. For examples, see the specs
    #
    # @return [Builder] self
    def query(*args, &block)
      _add_clause(false, :and, *args, &block)
    end
    alias and_query query

    # Adds a *or* *query* clause. For examples, see the specs
    #
    # @return [Builder] self
    def or_query(*args, &block)
      _add_clause(false, :or, *args, &block)
    end

    # Adds a *not* *query* clause. For examples, see the specs
    #
    # @return [Builder] self
    def not_query(*args, &block)
      _add_clause(false, :not, *args, &block)
    end

    # Allows to add custom root level key to the built query
    #
    # @param [String, Symbol] key name of the key to set value to
    # @param [String, Symbol, Hash, Array] value the value to set
    # @return [Builder] self
    def raw_option(key, value)
      @raw_options << {key: key, value: value}
      self
    end

    # Sets the field to sort by
    #
    # @param [String, Symbol] field name of the field
    # @param [String] direction ('asc' or 'desc')
    # @return [Builder] self
    def sort_field(field, direction = 'asc')
      unless %w[desc asc].include?(direction.to_s.downcase)
        raise ArgumentError.new("direction must be 'asc' or 'desc', got '#{direction}'")
      end

      field = field.to_sym
      sort = sort_fields.find { |obj| obj.key?(field) }
      if sort
        sort[field] = direction
      else
        @sort_fields << {"#{field}": direction}
      end
      self
    end

    # Sets the size key of the query
    #
    # @param [Integer] size
    # @return [Builder] self
    def set_size(size)
      @size = size
      self
    end

    # Sets the from key of the query
    #
    # @param [Integer] from
    # @return [Builder] self
    def set_from(from)
      @from = from
      self
    end

    # Sets elasticsearch's *minimum_should_match* value on a *query* context
    #
    # @param [Integer] value
    # @return [Builder] self
    def set_query_minimum_should_match(value)
      self.query_minimum_should_match = value
      self
    end

    # Sets elasticsearch's *minimum_should_match* value on a *filter* context
    #
    # @param [Integer] value
    # @return [Builder] self
    def set_filter_minimum_should_match(value)
      self.filter_minimum_should_match = value
      self
    end

    # Checks if builder has any *filter* clauses. If a key
    # is passed as an argument, it ignores all other keys.
    #
    # @param [Symbol] key (:and, :or, :not)
    # @return [Boolean] true if any filter clause is present
    def filters?(key = nil)
      @filters.any? do |k, v|
        next if key && k != key

        !v.empty?
      end
    end

    # Checks if builder has any *query* clauses. If a key
    # is passed as an argument, it ignores all other keys.
    #
    # @param [Symbol] key (:and, :or, :not)
    # @return [Boolean] true if any query clause is present
    def queries?(key = nil)
      @queries.any? do |k, v|
        next if key && k != key

        !v.empty?
      end
    end

    # Builds the elasticsearch query
    #
    # @return [Hash] built elasticsearch query
    def build
      # TODO: should this validation be recursive and optional?
      raise StandardError.new('cannot query when parent is filter') if parent&.is_filter && queries?

      query = Marshal.load(Marshal.dump(base_query)) # dup
      query.deep_transform_keys!(&:to_sym)
      base_query_is_bool = query[:query]&.key?(:bool)

      if query.key?(:query) && !base_query_is_bool
        raise StandardError.new('cannot build query when base query root is not bool clause')
      end

      is_simple_filter =
        only_one_and_clause?(:filters) ||
        (
          filters[:or].empty? &&
          !queries? &&
          !filters.any? { |_key, clauses| clauses.any?(&:block) }
        )

      # Process queries and filters
      if !parent && !base_query_is_bool && !filters? && only_one_and_clause?(:queries)
        query[:query] = queries[:and].first.build
      else
        {filters: @filters, queries: @queries}.each do |type, object|
          current_is_simple_filter = is_simple_filter && type == :filters
          # build bool clause
          object.each do |key, clauses|
            next if clauses.empty?

            built_clauses = clauses.map(&:build)
            built_clauses = built_clauses.first if clauses.size == 1 # && !base_query_is_bool

            scope = if parent&.is_filter
              # query
              query[:query] ||= {}
            elsif current_is_simple_filter || type == :queries
              # query.bool
              query[:query] ||= {}
              query[:query][:bool] ||= {}
            else
              # query.bool.filter.bool
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

            mapping = if current_is_simple_filter
              {
                and: :filter,
                or: nil,
                not: :must_not
              }
            else
              {
                and: :must,
                or: :should,
                not: :must_not
              }
            end

            mapped_key = mapping[key]

            # add or merge to
            if scope.key?(mapped_key)
              value = scope[mapped_key]
              value = [value] unless value.is_a? Array
              if built_clauses.is_a?(Array)
                value.concat(built_clauses)
              else
                value.push(built_clauses)
              end
            else
              scope[mapped_key] = built_clauses
            end

            # add minimum_should_match for query or filter if more than 1 clause
            if mapped_key == :should && scope[:should].is_a?(Array)
              if type == :queries
                scope[:minimum_should_match] = query_minimum_should_match unless query_minimum_should_match.nil?
              else
                scope[:minimum_should_match] = filter_minimum_should_match unless filter_minimum_should_match.nil?
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

    # Calls all reset methods and sets from and size to nil
    #
    # @return [void]
    def reset!
      reset_queries!
      reset_filters!
      reset_raw_options!
      reset_sort_fields!
      self.from = nil
      self.size = nil
    end

    # Empties all *query* caluses from the builder
    #
    # @return [Hash] queries hash
    def reset_queries!
      @queries = {
        and: [],
        or: [],
        not: []
      }
    end

    # Empties all *filter* clauses from the builder
    #
    # @return [Hash] filters hash
    def reset_filters!
      @filters = {
        and: [],
        or: [],
        not: []
      }
    end

    # Empties raw_options
    #
    # @return [void]
    def reset_raw_options!
      @raw_options = []
    end

    # Empties sort fields
    #
    # @return [void]
    def reset_sort_fields!
      @sort_fields = []
    end

    private

    # Adds a clause to the builder
    #
    # @param [Boolean] is_filter true when *filter* context
    # @param [Symbol] key one of (:and, :or, :not)
    # @param [String] type Query type
    # @param [String, Hash] field Field to query or complete query clause
    # @param [String, Hash] value Query term or inner clause
    # @param [Hash] options (optional)
    # @param &block (optional)
    # @return [Builder] builder with added clause
    def _add_clause(is_filter, key, type, field = nil, value = nil, options = {}, &block)
      obj = is_filter ? filters : queries
      obj[key] << Clause.new(type, is_filter, field, value, self, options, &block)
      self
    end

    # Returns true if only 1 clause exists and its key is :and
    #
    # @param [Symbol] type (:filters or :queries)
    # @return [Boolean]
    def only_one_and_clause?(type)
      object = type == :filters ? filters : queries
      object[:and].length == 1 && object[:or].empty? && object[:not].empty?
    end

  end

end
