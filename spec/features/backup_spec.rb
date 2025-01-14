require "features/helper"

RSpec.describe "backup", type: :aruba, docker: true do
  include_context "account fixture"
  include_context "message-fixtures"

  let(:backup_folders) { [{name: folder}] }
  let(:folder) { "my-stuff" }
  let(:messages_as_mbox) do
    message_as_mbox_entry(msg1) + message_as_mbox_entry(msg2)
  end

  let!(:pre) do
    server_delete_folder folder
  end
  let!(:setup) do
    server_create_folder folder
    send_email folder, msg1
    send_email folder, msg2
    create_config(accounts: [account.to_h])

    run_command_and_stop("imap-backup backup")
  end

  after do
    server_delete_folder folder
    disconnect_imap
  end

  it "downloads messages" do
    expect(mbox_content(folder)).to eq(messages_as_mbox)
  end

  describe "IMAP metadata" do
    let(:imap_metadata) { imap_parsed(folder) }
    let(:folder_uids) { server_uids(folder) }

    it "saves IMAP metadata in a JSON file" do
      expect { imap_metadata }.to_not raise_error
    end

    it "saves a file version" do
      expect(imap_metadata[:version].to_s).to match(/^[0-9.]$/)
    end

    it "records IMAP ids" do
      uids = imap_metadata[:messages].map { |m| m[:uid] }

      expect(uids).to eq(folder_uids)
    end

    it "records message offsets in the mbox file" do
      offsets = imap_metadata[:messages].map { |m| m[:offset] }
      expected = [0, message_as_mbox_entry(msg1).length]

      expect(offsets).to eq(expected)
    end

    it "records message lengths in the mbox file" do
      lengths = imap_metadata[:messages].map { |m| m[:length] }
      expected = [message_as_mbox_entry(msg1).length, message_as_mbox_entry(msg2).length]

      expect(lengths).to eq(expected)
    end

    it "records uid_validity" do
      expect(imap_metadata[:uid_validity]).to eq(server_uid_validity(folder))
    end

    context "when uid_validity does not match" do
      let(:new_name) { "NEWNAME" }
      let(:original_folder_uid_validity) { server_uid_validity(folder) }
      let(:connection) { Imap::Backup::Account::Connection.new(account) }
      let!(:pre) do
        super()
        server_delete_folder new_name
        server_create_folder folder
        send_email folder, msg3
        original_folder_uid_validity
        connection.run_backup
        connection.disconnect
        server_rename_folder folder, new_name
      end
      let(:renamed_folder) { "#{folder}-#{original_folder_uid_validity}" }

      after do
        server_delete_folder new_name
      end

      it "renames the old backup" do
        expect(mbox_content(renamed_folder)).to eq(message_as_mbox_entry(msg3))
      end

      it "renames the old metadata file" do
        expect(imap_parsed(renamed_folder)).to be_a Hash
      end

      it "downloads messages" do
        expect(mbox_content(folder)).to eq(messages_as_mbox)
      end

      it "creates a metadata file" do
        expect(imap_parsed(folder)).to be_a Hash
      end

      context "when a renamed local backup exists" do
        let!(:pre) do
          super()
          create_directory local_backup_path
          valid_imap_data = {version: 3, uid_validity: 1, messages: []}
          File.write(imap_path(renamed_folder), valid_imap_data.to_json)
          File.write(mbox_path(renamed_folder), "existing mbox")
        end

        it "renames the renamed backup to a uniquely name" do
          renamed = "#{folder}-#{original_folder_uid_validity}-1"
          expect(mbox_content(renamed)).to eq(message_as_mbox_entry(msg3))
        end
      end
    end
  end
end
