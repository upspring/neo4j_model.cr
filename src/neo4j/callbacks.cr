module Neo4j
  module Model
    macro included
      @@_before_validation_callback : Proc({{@type.id}}, Bool) = ->(obj : {{@type.id}}) { true }
      @@_after_validation_callback : Proc({{@type.id}}, Bool) = ->(obj : {{@type.id}}) { true }
      @@_before_save_callback : Proc({{@type.id}}, Bool) = ->(obj : {{@type.id}}) { true }
      @@_after_save_callback : Proc({{@type.id}}, Bool) = ->(obj : {{@type.id}}) { true }

      macro before_validation(*method_syms)
        @@_before_validation_callback = ->(obj : {{@type.id}}) {
          \{% for meth in method_syms %}
            return false unless obj.\{{meth.id}}
          \{% end %}
          true
        }
      end

      macro before_validation(&block)
        @@_before_validation_callback = block
      end

      macro after_validation(*method_syms)
        @@_after_validation_callback = ->(obj : {{@type.id}}) {
          \{% for meth in method_syms %}
            return false unless obj.\{{meth.id}}
          \{% end %}
          true
        }
      end

      macro after_validation(&block)
        @@_after_validation_callback = block
      end

      macro before_save(*method_syms)
        @@_before_save_callback = ->(obj : {{@type.id}}) {
          \{% for meth in method_syms %}
            return false unless obj.\{{meth.id}}
          \{% end %}
          true
        }
      end

      macro before_save(&block)
        @@_before_save_callback = block
      end

      macro after_save(*method_syms)
        @@_after_save_callback = ->(obj : {{@type.id}}) {
          \{% for meth in method_syms %}
            return false unless obj.\{{meth.id}}
          \{% end %}
          true
        }
      end

      macro after_save(&block)
        @@_after_save_callback = block
      end
    end
  end
end
