module Moped
  module LogFormat
    class ShellFormat
      class Query
        include Moped::LogFormat::ShellFormat::Shellable

        CommandToModifiers = {
          min: '$min',
          max: '$max',
          sort: '$orderby',
          hint: '$hint',
          snapshot: '$snapshot',
          maxTimeMS: '$maxTimeMS',
          explain: '$explain'
        }

        MethodsToCommand = {
          batch_size: 'batchSize',
          limit: 'limit',
          skip: 'skip',
        }

        FlagsToOptions = {
          tailable: 'tailable',
          slave_ok: 'slaveOk',
          no_cursor_timeout: 'noTimeout',
          await_data: 'awaitData',
          exhaust: 'exhaust'
        }

        def sequence
          [
            :db, :collection, :find, :sort, :hint,
            :min, :max, :limit, :skip,
            :specials,
            :batch_size,
            :maxTimeMS,
            :flags,
            :snapshot,
            :explain
          ]
        end

        def to_shell_find
          selector = event.selector.dup

          query = selector.delete("$query") { Hash.new }
          selector.keep_if {|k, v| not k.to_s.start_with? '$' }
          selector.merge! query

          arguments = []
          arguments << dump_json(selector)
          arguments << dump_json(event.fields) if not event.fields.blank?

          return shell :find, arguments
        end

        def to_shell_limit
          limit = event.limit

          return nil if limit.nil? or limit == 0

          shell :limit, limit
        end

        def to_shell_skip
          skip = event.skip
          return nil if skip.nil? or skip == 0

          shell :skip, skip
        end

        def to_shell_flags
          # TODO: FlagsToOptions
          return nil
        end

        def to_shell_specials
          unknown_modifiers = event.selector.dup.keep_if do |modifier, value|
            modifier = modifier.to_s
            modifier.start_with?("$") and ('$query' != modifier)  and (not CommandToModifiers.has_value?(modifier))
          end

          unknown_modifiers.inject [] do |acc, (modifier, params)|
            acc << shell(:_addSpecial, dump_json({modifier => params}))
            acc
          end
        end

        def extact_command(command)
          if command_name = MethodsToCommand[command]
            result = event.send(command)

            if not result.blank?
              return shell command_name, dump_json(result)
            else
              return nil
            end
          end

          if modifier_name = CommandToModifiers[command]
            result = event.selector[modifier_name]

            if not result.blank?
              return shell command, dump_json(result)
            else
              return nil
            end
          end

          raise ArgumentError, "can't convert '#{command}' to mongodb shell command for #{self.class}"
        end
      end
    end
  end
end