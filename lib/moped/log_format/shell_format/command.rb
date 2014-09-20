module Moped
  module LogFormat
    class ShellFormat
      class Command
        include Moped::LogFormat::ShellFormat::Shellable

        Commands = %w{addUser auth changeUserPassword cloneCollection cloneDatabase commandHelp copyDatabase
                      createCollection currentOp dropDatabase eval fsyncLock fsyncUnlock getCollection getCollectionNames
                      getLastError getLastErrorObj getMongo getName getPrevError getProfilingLevel getProfilingStatus
                      getReplicationInfo getSiblingDB help hostInfo isMaster killOp listCommands loadServerScripts
                      logout printCollectionStats printReplicationInfo printShardingStatus printSlaveReplicationInfo
                      removeUser repairDatabase resetError runCommand serverBuildInfo serverCmdLineOpts serverStatus
                      setProfilingLevel shutdownServer stats upgradeCheck upgradeCheckAllDBs version}

        Aliases = Commands.inject({}) do |acc, cmd|
          if cmd.downcase != cmd
            name = cmd.downcase.to_sym
            acc[name] = cmd
          end

          acc
        end

        def sequence
          [
            :db, :command
          ]
        end

        def to_shell_command
          return shell(command_name, argument, rest)
        end

        private

        def name
          event.selector.keys.first
        end

        def command_name
          normalized_name = name.downcase.to_sym

          if Aliases.include? normalized_name
            command_name = Aliases[normalized_name]
          else
            name
          end
        end

        def argument
          if event.selector[name].blank?
            return nil
          else
            dump_json event.selector[name]
          end
        end

        def rest
          selector = event.selector.dup
          selector.delete name

          if selector.blank?
            return nil
          else
            dump_json selector
          end
        end
      end
    end
  end
end