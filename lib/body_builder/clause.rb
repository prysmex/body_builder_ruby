module BodyBuilder
  class Clause

    attr_accessor :type, :field, :value, :options, :block
    attr_reader :parent
  
    def initialize(type, field=nil, value=nil, options={}, parent=nil, &block)
      @type = type
      @field = field
      @value = value
      @options = options
      @parent = parent
      @block = block
    end
  
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