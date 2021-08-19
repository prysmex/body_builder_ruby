module BodyBuilder
  #
  # This class is used by BodyBuilder::Builder class to create a query.
  # It represents a unit of an elasticsearch 'clause' inside a query
  #
  class Clause

    attr_accessor :type, :field, :value, :options, :block
    attr_reader :parent
  
    # Initialization method
    #
    # @param [String] type examples: (terms, match, match_all, etc...) 
    # @param [String] field name of the field
    # @param [String, Integer, Array<String, Integer>] value to be used by query o filter
    # @param [Hash] options used to support params in clause
    # @param [Builder] parent <description>
    def initialize(type, field=nil, value=nil, options={}, parent=nil, &block)
      @type = type
      @field = field
      @value = value
      @options = options
      @parent = parent
      @block = block
    end
  
    # Builds the elasticsearch query clause
    #
    # @return [Hash] elasticsearch query clause
    def build
      hash = if @value
          {"#{@field}".to_sym => @value}
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
        child_builder = @block.call(builder)
        child_hash = builder.build
        if type.to_sym != :bool
          if child_hash.any?{|k,v| [:must, :must_not, :filter, :should].include?(k.to_sym) }
            child_hash = {query: {bool: child_hash}}
          else
            child_hash = {query: child_hash}
          end
        end
        child_hash = child_hash[:bool] if child_hash.key?(:bool)
        hash.merge!(child_hash)
      end
    
      return {"#{@type}".to_sym => hash}
    end
  
  end
end