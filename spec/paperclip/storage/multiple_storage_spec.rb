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
  end
end