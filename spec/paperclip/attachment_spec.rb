require 'spec_helper'
require 'gb_paperclip/paperclip/attachment'

describe Paperclip::Attachment do

  before(:each) do
    @file = File.new(fixture_file('5k.png'), 'rb')
    @file.binmode
    rebuild_model storage: :fake
    @dummy        = Dummy.create!
    @dummy.avatar = @file
    @attachment   = @dummy.avatar
  end

  context 'saving with lock' do
    it 'should put save lock while saving' do
      async_flag                          = false
      @attachment.queued_for_write[:test] = Paperclip.io_adapters.for(@file)
      GBDispatch.dispatch_async(:test) do
        @attachment.with_save_lock do
          sleep(0.3)
          async_flag = true
        end
      end
      GBDispatch.dispatch_sync :save do
        @attachment.save
      end
      expect(async_flag).to eq true
      wait_for :test
    end

    it 'should use status lock' do
      async_flag                          = false
      @attachment.queued_for_write[:test] = Paperclip.io_adapters.for(@file)
      GBDispatch.dispatch_async(:test) do
        @attachment.send(:status_lock).lock
        sleep(0.3)
        async_flag = true
        @attachment.send(:status_lock).unlock
      end
      GBDispatch.dispatch_sync :save do
        @attachment.save
      end
      expect(async_flag).to eq true
    end
  end

  it 'unlink files should handle nil values' do
    file = File.new(fixture_file('5k.png'), 'rb')
    expect { @attachment.unlink_files([file, nil]) }.not_to raise_error
    expect(file.closed?).to be_truthy
  end

  context 'processing info' do
    context 'processing' do
      it 'should add style name to processor tracker' do
        @attachment.processing(:test_style)
        expect(@attachment.instance_variable_get :@processor_tracker).to include :test_style
      end

      it 'should add style name to processor tracker when style passed' do
        @attachment.processing(Paperclip::Style.new(:test_style, '143x143#', @attachment))
        expect(@attachment.instance_variable_get :@processor_tracker).to include :test_style
      end

      it 'should set processed styles as empty array on instance' do
        @attachment.processing(:test_style)
        expect(@dummy.processed_styles).to be_a Array
      end

      context 'set processing as true' do
        it 'for new model' do
          dummy        = Dummy.new
          dummy.avatar = @file
          dummy.avatar.processing(:test_style)
          expect(dummy.processing).to eq true
          expect(dummy.new_record?).to be_truthy
        end

        it 'for dirty model' do
          @attachment.send :dirty!
          @attachment.processing(:test_style)
          expect(@dummy.processing).to eq true
          expect(@dummy.changes.keys).to include 'processing'
        end

        it 'for saved model' do
          @dummy.save!
          expect(@attachment.dirty?).to be_falsey
          @attachment.processing(:test_style)
          expect(@dummy.processing).to eq true
          expect(@dummy.changes.keys).not_to include 'processing'
        end

        it 'should save if saving on different thread' do
          class SleepyDummy < Dummy
            self.table_name = 'dummies'
            after_save :take_nap

            def take_nap
              sleep(0.5)
            end
          end
          dummy = nil
          GBDispatch.dispatch_sync(:save) do
            dummy        = SleepyDummy.new
            dummy.avatar = @file
          end
          GBDispatch.dispatch_async(:save) do
            dummy.save!
          end
          GBDispatch.dispatch_sync(:process) do
            sleep(0.1)
            expect { dummy.avatar.processing(:test_style) }.not_to raise_error
          end
          wait_for :save
          expect(dummy.avatar.saved[:original]).not_to be_nil
          expect(dummy.changes.keys.any?).to be_falsey
          expect(dummy.reload.processing).to eq true
        end
      end
    end
  end

  def wait_for(queue)
    GBDispatch.dispatch_sync_on_queue queue do
      puts "waiting for #{queue}"
    end
  end
end