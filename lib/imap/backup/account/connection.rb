require 'net/imap'

module Imap
  module Backup
    module Account
      class Connection
        attr_reader :username, :local_path, :backup_folders

        def initialize(options)
          @username, @password = options[:username], options[:password]
          @local_path, @backup_folders = options[:local_path], options[:folders]
        end

        def folders
          root = root_for(username)
          imap.list(root, '*')
        end

        def status
          backup_folders.map do |folder|
            f = Imap::Backup::Account::Folder.new(self, folder[:name])
            s = Imap::Backup::Serializer::Directory.new(local_path, folder[:name])
            {:name => folder[:name], :local => s.uids, :remote => f.uids}
          end
        end

        def run_backup
          backup_folders.each do |folder|
            f = Imap::Backup::Account::Folder.new(self, folder[:name])
            s = Imap::Backup::Serializer::Mbox.new(local_path, folder[:name])
            d = Imap::Backup::Downloader.new(f, s)
            d.run
          end
        end

        def disconnect
          imap.disconnect
        end

        def imap
          return @imap unless @imap.nil?
          host = host_for(username)
          options = options_for(username)
          @imap = Net::IMAP.new(host, options)
          @imap.login(username, @password)
          @imap
        end

        private

        def host_for(username)
          case username
          when /@gmail\.com/
            'imap.gmail.com'
          when /@fastmail\.fm/
            'mail.messagingengine.com'
          end
        end

        def root_for(username)
          case username
          when /@gmail\.com/
            '/'
          when /@fastmail\.fm/
            'INBOX'
          end
        end

        def options_for(username)
          case username
          when /@gmail\.com/
            {:port => 993, :ssl => true}
          when /@fastmail\.fm/
            {:port => 993, :ssl => true}
          end
        end
      end
    end
  end
end
