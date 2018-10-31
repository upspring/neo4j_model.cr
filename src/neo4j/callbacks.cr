module Neo4j
  module Model
    macro included
      @@_before_save_callback : Proc({{@type.id}}, Bool) = ->(obj : {{@type.id}}) { true }
      @@_after_save_callback : Proc({{@type.id}}, Bool) = ->(obj : {{@type.id}}) { true }

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
