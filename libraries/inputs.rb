class Chef
  class Recipe

    def empty?(object)
      # Fuck ruby, leave the parenthesis or it does crap.
      empty = ([Hash, Array, String].include?(object.class) and object.empty?)
      if empty or !object
        return true
      else
        return false
      end
    end

    # Make sure an object has a value.
    def assert(object, message)
      if empty?(object)
        throw message
      end
    end

    # Access an attribute and make sure it is defined.
    def check_input(object, path)
      path.each do |key|
        object = object[key]
        assert(object, "Required parameter `#{path.join('.')}` (#{object})")
      end
      return object
    end

    def check_optional_input(object, path, default)
      path.each do |key|
        object = object[key]
        if empty?(object)
          return default
        end
      end
      return object
    end

  end
end
