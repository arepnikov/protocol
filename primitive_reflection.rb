class PrimitiveReflection
  Error = Class.new(RuntimeError)

  attr_reader :subject
  attr_reader :target
  alias :constant :target
  attr_reader :strict

  def initialize(subject, target, _strict=nil)
    @subject = subject
    @target = target
    @strict = _strict
  end

  ## TODO: what about **kwargs? Should we support it?
  ## TODO: same question about `&block`
  # def call(method_name, *args, currying: true, **kwargs, &block)
  def call(method_name, *args, currying: true)
    unless target.respond_to?(method_name)
      target_name = Reflect.constant(target).name
      raise Reflect::Error, "#{target_name} does not define method #{method_name}"
    end

    method = target.method(method_name)
    method_parameters = method_parameters(method)

    if currying && method_parameters.size.zero?
      raise Error, "currying is not possible for methods with arity zero"
    end

    # method_arity = method_arity(method_parameters)
    # method_req_arity = method_required_arity(method_parameters)

    if currying
      # method.curry(1 + args.size)
      method.(subject, *args)
    else
      method.(*args)
    end
  end

  def method_parameters(method)
    method_parameters = method.parameters
    return [] if method_parameters.empty?

    supported_parameter_types = %i(req opt rest).freeze
    method_parameters = method_parameters.group_by do |type, _name|
      supported_parameter_types.include?(type) ? :supported : :unsupported
    end

    if method_parameters[:unsupported]
      unsupported_parameters = method_parameters[:unsupported]
      raise Error, "method '#{method_name}' has unsupported parameters: #{unsupported_parameters}"
    end

    Array(method_parameters[:supported])
  end

  # def method_arity(method_parameters)
  #   have_infinite_arity = method_parameters.any? { |type, | type == :rest}

  #   if have_infinite_arity
  #     :infinite_arity
  #   else
  #     method_parameters.size
  #   end
  # end

  # def method_required_arity(method_parameters)
  #   method_parameters.count { |type, _name| type == :req }
  # end
end
