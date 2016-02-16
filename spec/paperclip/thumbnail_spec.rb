require 'spec_helper'

describe Paperclip::Thumbnail do

  context 'Attachment processing info' do
    before(:each) do
      @file       = File.new(fixture_file('7m.mov'), 'rb')
      @attachment = stub
      @thumb      = Paperclip::Thumbnail.new(@file, { geometry: '100x100', style: :test }, @attachment)
    end

    after(:each) { @file.close }

    it 'should call finished processing style if successes' do
      @attachment.expects(:finished_processing).with(:test)
      @thumb.make
    end
  end
end