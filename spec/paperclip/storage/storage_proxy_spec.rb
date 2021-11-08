require 'spec_helper'
require 'gb_paperclip/paperclip/storage/storage_proxy'

describe Paperclip::Storage::StorageProxy do
  before do
    rebuild_model styles: { thumbnail: '25x25#' }
    @dummy = Dummy.new

    @file         = File.open(fixture_file('5k.png'))
    @dummy.avatar = @file
    @options      = @dummy.avatar.instance_variable_get(:@options)
  end

  it 'properly initialize' do
    proxy = Paperclip::Storage::StorageProxy.new(@options, @dummy.avatar)
    expect(proxy).to be_a(Paperclip::Storage::Filesystem)
  end

  it 'should not initialize if store does not exists' do
    expect { Paperclip::Storage::StorageProxy.new(@options.merge(storage: :xyz), @dummy.avatar) }.to raise_error Paperclip::Errors::StorageMethodNotFound
  end

  it 'should proxy methods to parent' do
    stub_parent = double
    proxy       = Paperclip::Storage::StorageProxy.new(@options, stub_parent)
    expect(stub_parent).to receive(:foo).with(:bar)
    proxy.foo :bar
  end

  it 'should create copy of queued_for_write' do
    proxy = Paperclip::Storage::StorageProxy.new(@options, @dummy.avatar)

    file_adapter      = Paperclip.io_adapters.for(File.open(fixture_file('5k.png')))
    string_io_adapter = Paperclip.io_adapters.for(stringy_file)

    proxy.queued_for_write = {
        file:      file_adapter,
        string_io: string_io_adapter
    }

    expect(proxy.queued_for_write.keys).to include(:file, :string_io)
    proxy.queued_for_write.values.each do |adapter|
      expect(adapter).to be_a Paperclip::CopyAdapter
    end

    expect(proxy.queued_for_write[:file]).not_to eq file_adapter
    expect(proxy.queued_for_write[:file].fingerprint).to eq file_adapter.fingerprint
    expect(proxy.queued_for_write[:file].read).to eq file_adapter.read

    expect(proxy.queued_for_write[:string_io]).not_to eq string_io_adapter
    expect(proxy.queued_for_write[:string_io].fingerprint).to eq string_io_adapter.fingerprint
    expect(proxy.queued_for_write[:string_io].read).to eq string_io_adapter.read

    proxy.unlink_files [string_io_adapter, file_adapter]
    proxy.unlink_files proxy.queued_for_write.values
  end

  it 'should close files after flush write' do
    proxy = Paperclip::Storage::StorageProxy.new(@options, @dummy.avatar)

    file_adapter      = Paperclip.io_adapters.for(File.open(fixture_file('5k.png')))
    string_io_adapter = Paperclip.io_adapters.for(stringy_file)

    proxy.queued_for_write = {
        file:      file_adapter,
        string_io: string_io_adapter
    }

    proxy.after_flush_writes
    expect(proxy.queued_for_write[:file].closed?).to be_truthy
    expect(proxy.queued_for_write[:string_io].closed?).to be_truthy
    proxy.unlink_files [string_io_adapter, file_adapter]
  end
end