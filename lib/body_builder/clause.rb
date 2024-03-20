# frozen_string_literal: true

module BodyBuilder
  #
  # This class is used by BodyBuilder::Builder class to create a query.
  # It represents a unit of an elasticsearch 'clause' inside a query
  #
  class Clause

    MATCH_KEYS = %i[must must_not filter should].freeze

    attr_accessor :type, :is_filter, :field, :value, :options, :block
    attr_reader :parent

    # Initialization method
    #
    # @param [String] type examples: (terms, match, match_all, etc...)
    # @param [Boolean] is_filter
    # @param [String] field name of the field
    # @param [String, Integer, Array<String, Integer>] value to be used by query o filter
    # @param [Builder] parent <description>
    # @param [Hash] options used to support params in clause
    def initialize(type, is_filter, field = nil, value = nil, parent = nil, options = {}, &block)
      @type = type
      @is_filter = is_filter
      @field = field
      @value = value
      @parent = parent
      @options = options
      @block = block
    end

    # Builds the elasticsearch query clause
    #
    # @return [Hash] elasticsearch query clause
    def build
      hash = if !@value.nil?
          {"#{@field}": @value}
        elsif @field.is_a? Hash
          @field
        elsif @field
          {field: @field}
        else
          {}
        end

      hash.merge!(@options || {})

      if @block.is_a? Proc
        builder = BodyBuilder::Builder.new(parent: self)
        child_hash = @block.call(builder).build
        if type.to_sym != :bool
          child_hash = if child_hash.any? { |k, _v| MATCH_KEYS.include?(k.to_sym) }
            {query: {bool: child_hash}}
          else
            {query: child_hash}
                       end
        end
        child_hash = child_hash[:bool] if child_hash.key?(:bool)
        hash.merge!(child_hash)
      end

      {"#{@type}": hash}
    end

  end
end