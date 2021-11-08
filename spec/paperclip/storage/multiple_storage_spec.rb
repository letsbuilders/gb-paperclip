require 'spec_helper'

describe Paperclip::Storage::MultipleStorage do

  context 'Creating store proxies' do
    before do
      rebuild_model storage: :multiple_storage,
                    stores:  {
                        main:        {
                            storage: :fake,
                            foo:     :main,
                        },
                        backups:     [
                                         { storage: :fake, foo: :backup1 },
                                         { storage: :fake, foo: :backup2, path:
                                                    ':class/:hash_:style_foo.:extension', bar: :bar },
                                     ],
                        additional:  [
                                         { storage: :fake, foo: :additional1, path: ':id_:style.:extension' },
                                         { storage: :fake, foo: :additional2, path: ':style_id.:extension' },
                                     ],

                    },
                    backup_form: :sync,
                    path: ':extension/:id/:style.:extension',
                    hash_secret: '5613genies',
                    bar: :test


      @dummy  = Dummy.new
      @avatar = @dummy.avatar
    end

    it 'should setup main store' do
      expect(@dummy.avatar.main_store).to be_a Paperclip::Storage::StorageProxy
      expect(@dummy.avatar.main_store).to be_a Paperclip::Storage::Fake
      expect(@dummy.avatar.main_store.options_foo).to eq :main
    end

    it 'should setup backup stores' do
      expect(@dummy.avatar.backup_stores.length).to eq 2
      @dummy.avatar.backup_stores.each do |store|
        expect(store).to be_a Paperclip::Storage::StorageProxy
        expect(store).to be_a Paperclip::Storage::Fake
      end
      expect(@dummy.avatar.backup_stores.map(&:options_foo)).to include :backup1, :backup2
    end

    it 'should setup additional stores' do
      expect(@dummy.avatar.additional_stores.length).to eq 2
      @dummy.avatar.additional_stores.each do |store|
        expect(store).to be_a Paperclip::Storage::StorageProxy
        expect(store).to be_a Paperclip::Storage::Fake
      end
      expect(@dummy.avatar.additional_stores.map(&:options_foo)).to include :additional1, :additional2
    end

    it 'should propagate general settings to other stores' do
      expect(@dummy.avatar.main_store.options_bar).to eq :test
      expect(@dummy.avatar.backup_stores.map(&:options_bar)).to include :test, :bar
      expect(@dummy.avatar.additional_stores.map(&:options_bar)).to eq [:test, :test]
    end

    it 'should use always parent path settings' do
      file          = File.open(fixture_file('5k.png'))
      @dummy.avatar = file

      expect(@dummy.avatar.path(:original)).to eq 'png//original.png'
      expect(@dummy.avatar.main_store.path(:original)).to eq 'png//original.png'
      @dummy.avatar.backup_stores.each do |store|
        expect(store.path(:original)).to eq 'png//original.png'
      end
      @dummy.avatar.additional_stores.each do |store|
        expect(store.path(:original)).to eq 'png//original.png'
      end
      file.close
    end
  end

  context 'paperclip store methods' do
    before do
      rebuild_model storage:     :multiple_storage,
                    stores:      {
                        main:       {
                            storage: :fake,
                            foo:     :main,
                        },
                        backups:    [
                                        { storage: :fake },
                                        { storage: :fake },
                                    ],
                        additional: [
                                        { storage: :fake },
                                        { storage: :fake },
                                    ],

                    },
                    backup_form: :async,
                    path:        ':id/:style.:extension',
                    styles:      {
                        thumb: '80x80>'
                    }
    end

    context 'exists?' do
      it 'should delegate call to main store' do
        dummy = Dummy.new
        expect(dummy.avatar.main_store).to receive(:exists?).with(:original)
        dummy.avatar.backup_stores.each do |store|
          expect(store).not_to receive(:exists?)
        end
        dummy.avatar.additional_stores.each do |store|
          expect(store).not_to receive(:exists?)
        end
        dummy.avatar.exists? :original
      end
    end

    context 'flush_writes' do
      before(:each) do
        @dummy        = Dummy.create!
        @file         = File.open(fixture_file('5k.png'))
        @dummy.avatar = @file
        @avatar       = @dummy.avatar
      end

      after(:each) do
        @file.close
      end

      it 'should call it for each thread' do
        dummy  = Dummy.new
        stores = [dummy.avatar.main_store, dummy.avatar.backup_stores, dummy.avatar.additional_stores].flatten
        stores.each do |store|
          expect(store).to receive(:flush_writes)
        end
        dummy.avatar.flush_writes
      end

      it 'is rewinded after flush_writes' do
        @dummy.avatar.instance_eval 'def after_flush_writes; end'

        files = @dummy.avatar.queued_for_write.values
        @dummy.save
        expect(files.none?(&:eof?)).to be_truthy
      end

      it 'is removed after after_flush_writes' do
        paths = @dummy.avatar.queued_for_write.values.map(&:path)
        @dummy.save
        expect(paths.none? { |path| File.exist?(path) }).to be_truthy
      end

      it 'should write on proper threads' do
        @dummy.save
        expect(@avatar.main_store.save_thread).to eq Thread.current
        @avatar.backup_stores.each { |store| expect(store.save_thread).not_to eq Thread.current }
        @avatar.additional_stores.each { |store| expect(store.save_thread).not_to eq Thread.current }
      end

      it 'should be able to run backup save synchronously' do
        @avatar.instance_variable_set :@backup_sync, true
        @dummy.save
        expect(@avatar.main_store.save_thread).to eq Thread.current
        @avatar.backup_stores.each { |store| expect(store.save_thread).to eq Thread.current }
        @avatar.additional_stores.each { |store| expect(store.save_thread).not_to eq Thread.current }
      end

      context 'asynchronous backup' do
        it 'should handle save errors' do
          allow(@avatar.backup_stores.last).to receive(:flush_writes).and_raise(ArgumentError.new 'backup failed!')
          expect { @avatar.flush_writes }.to raise_error ArgumentError, 'backup failed!'
        end
      end

      context 'queued_for_write' do
        it 'should call lock when copying queues for write' do
          expect(@avatar).to receive(:with_lock)
          @avatar.flush_writes
        end

        it 'should lock queue for write for time of copying' do
          count    = 0
          run_loop = true
          Thread.new do
            while run_loop
              count            += 1
              previous_adapter = nil
              @avatar.change_queued_for_write do |queue|
                previous_adapter = queue[:loop]
                queue[:loop]     = Paperclip.io_adapters.for("#{count}\n")
              end
              previous_adapter.close if previous_adapter
              sleep 0.0001
            end
            Thread.exit
          end
          expect { @avatar.flush_writes }.not_to raise_error
          run_loop = false
        end

        it 'should copy original file for queue for write for backups' do
          @avatar.send :set_write_queue_for_stores
          expect(@avatar.main_store.queued_for_write.keys.sort).to eq [:original, :thumb]
          @avatar.additional_stores.each do |store|
            expect(store.queued_for_write.keys.sort).to eq [:original, :thumb]
          end
          @avatar.backup_stores.each do |store|
            expect(store.queued_for_write.keys).not_to include :thumb
            expect(store.queued_for_write.keys).to eq [:original]
          end
        end

        it 'should close all files' do
          before_open_files_count = open_file_count
          @avatar.flush_writes
          sleep(0.1)
          expect(open_file_count).to be <= before_open_files_count
        end

        it 'should close all files if saving fails (sync failure)' do
          @avatar.backup_stores.each { |store| store.raise_error = TestException }
          before_open_files_count = open_file_count
          expect { @avatar.flush_writes }.to raise_error TestException
          sleep(0.1)
          expect(open_file_count).to be <= before_open_files_count
        end

        it 'should close all files if saving fails (async backup failure)' do
          @avatar.instance_variable_set :@backup_sync, false
          @avatar.backup_stores.each { |store| store.raise_error = TestException }
          before_open_files_count = open_file_count
          expect { @avatar.flush_writes }.to raise_error TestException
          sleep(0.3)
          expect(open_file_count).to be <= before_open_files_count
        end

        it 'should close all files if saving fails (async failure)' do
          @avatar.additional_stores.each { |store| store.raise_error = TestException }
          before_open_files_count = open_file_count
          expect { @avatar.flush_writes }.not_to raise_error
          sleep(0.3)
          expect(open_file_count).to be <= before_open_files_count
        end
      end
    end

    context 'method missing' do
      before(:each) do
        @dummy  = Dummy.create!
        @avatar = @dummy.avatar
      end

      it 'should try to call main store if it respond to method' do
        expect(@avatar.main_store).to receive(:options_foo)
        @avatar.options_foo
      end
    end

    context 'flush_deletes' do
      before(:each) do
        @dummy  = Dummy.create!
        @avatar = @dummy.avatar
      end

      it 'should clean queued for delete after run' do
        @avatar.instance_variable_set :@queued_for_delete, [:foo, :bar]
        @avatar.flush_deletes
        queue = @avatar.instance_variable_get :@queued_for_delete
        expect(queue).to be_empty
      end

      it 'should invoke flush_deletes on all stores but not backup' do
        stores = [@avatar.main_store, @avatar.additional_stores].flatten
        stores.each do |store|
          store.sleep_time = 0
          expect(store).to receive(:flush_deletes)
        end
        @avatar.backup_stores.each do |store|
          expect(store).not_to receive(:flush_deletes)
        end
        @avatar.flush_deletes
        sleep(0.03)
      end

      it 'should invoke delete on proper threads' do
        @avatar.flush_deletes
        expect(@avatar.main_store.delete_thread).to eq Thread.current
        @avatar.additional_stores.each do |store|
          expect(store.delete_thread).not_to eq Thread.current
        end
      end

      it 'should use copy of queued_for_delete' do
        stores = [@avatar.main_store, @avatar.additional_stores].flatten
        stores.each do |store|
          store.instance_eval 'def flush_deletes; end'
        end
        @avatar.instance_variable_set :@queued_for_delete, [:foo, :bar]
        queue = @avatar.instance_variable_get :@queued_for_delete
        @avatar.flush_deletes
        stores.each do |store|
          expect(store.queued_for_delete).to eq queue #have the same content
          expect(store.queued_for_delete).not_to equal queue #be different instance
        end
      end
    end

    context 'copy_to_local_file' do
      before(:each) do
        @dummy  = Dummy.create!
        @avatar = @dummy.avatar
      end

      it 'should try to copy using main store' do
        allow(@avatar.main_store).to receive(:copy_to_local_file).and_return(:foo)
        [@avatar.additional_stores, @avatar.backup_stores].flatten.each do |store|
          expect(store).not_to receive(:copy_to_local_file)
        end
        @avatar.copy_to_local_file(:original, 'test.png')
      end

      it 'if copying for main store it should back to additional stores - first passing' do
        allow(@avatar.main_store).to receive(:copy_to_local_file).and_return(false)
        allow(@avatar.additional_stores.first).to receive(:copy_to_local_file).and_return(true)
        expect(@avatar.additional_stores.last).not_to receive(:copy_to_local_file)
        @avatar.backup_stores.each do |store|
          expect(store).not_to receive(:copy_to_local_file)
        end
        @avatar.copy_to_local_file(:original, 'test.png')
      end

      it 'if copying for main store it should back to additional stores - last passing' do
        allow(@avatar.main_store).to receive(:copy_to_local_file).and_return(false)
        allow(@avatar.additional_stores.first).to receive(:copy_to_local_file).and_raise('test error')
expect(@avatar.additional_stores.last).to receive(:copy_to_local_file).and_return(true)
        @avatar.backup_stores.each do |store|
          expect(store).not_to receive(:copy_to_local_file)
        end
        @avatar.copy_to_local_file(:original, 'test.png')
      end

      it 'if copying for main store it should back to additional stores then to backup' do
        allow(@avatar.main_store).to receive(:copy_to_local_file).and_return(false)
        allow(@avatar.additional_stores.first).to receive(:copy_to_local_file).and_raise('test error')
expect(@avatar.additional_stores.last).to receive(:copy_to_local_file).and_return(false)
expect(@avatar.backup_stores.first).to receive(:copy_to_local_file).and_return(true)
        expect(@avatar.backup_stores.last).not_to receive(:copy_to_local_file)
        @avatar.copy_to_local_file(:original, 'test.png')
      end

      it 'if copying for main store it should back to additional stores then to backup - first fails' do
        allow(@avatar.main_store).to receive(:copy_to_local_file).and_return(false)
        allow(@avatar.additional_stores.first).to receive(:copy_to_local_file).and_raise('test error')
expect(@avatar.additional_stores.last).to receive(:copy_to_local_file).and_return(false)
expect(@avatar.backup_stores.first).to receive(:copy_to_local_file).and_return(false)
        expect(@avatar.backup_stores.last).to receive(:copy_to_local_file)
        @avatar.copy_to_local_file(:original, 'test.png')
      end

      it 'if copying for main store it should back to additional stores then to backup - first crashes' do
        allow(@avatar.main_store).to receive(:copy_to_local_file).and_return(false)
        allow(@avatar.additional_stores.first).to receive(:copy_to_local_file).and_raise('test error')
expect(@avatar.additional_stores.last).to receive(:copy_to_local_file).and_return(false)
        expect(@avatar.backup_stores.first).to receive(:copy_to_local_file).and_raise('test error')
        expect(@avatar.backup_stores.last).to receive(:copy_to_local_file)
        @avatar.copy_to_local_file(:original, 'test.png')
      end

      it 'should return false if all stores fails' do
        allow(@avatar.main_store).to receive(:copy_to_local_file).and_return(false)
        allow(@avatar.additional_stores.first).to receive(:copy_to_local_file).and_raise('test error')
expect(@avatar.additional_stores.last).to receive(:copy_to_local_file).and_return(false)
        expect(@avatar.backup_stores.first).to receive(:copy_to_local_file).and_raise('test error')
expect(@avatar.backup_stores.last).to receive(:copy_to_local_file).and_return(nil)
        expect(@avatar.copy_to_local_file(:original, 'test.png')).to eq false
      end
    end
  end
end