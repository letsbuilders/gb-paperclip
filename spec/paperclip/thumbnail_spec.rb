require 'spec_helper'

describe Paperclip::Thumbnail do

  context 'Attachment processing info' do
    before(:each) do
      @file       = File.new(fixture_file('5k.png'), 'rb')
      @attachment = double
      @thumb      = Paperclip::Thumbnail.new(@file, { geometry: '100x100', style: :test }, @attachment)
    end

    after(:each) { @file.close }

    it 'should call finished processing style if successes' do
      expect(@attachment).to receive(:finished_processing).with(:test)
      @thumb.make
    end

    it 'should call failed processing style if not whiny and not not successful' do
      @thumb.instance_variable_set :@whiny, false
      expect(@attachment).to receive(:failed_processing).with(:test)
      allow(@thumb).to receive(:convert).with(anything, anything).and_raise(Terrapin::ExitStatusError.new '')
      expect { @thumb.make }.not_to raise_error
    end
  end
end