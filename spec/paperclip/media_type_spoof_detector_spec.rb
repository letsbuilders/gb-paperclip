require 'spec_helper'
require 'gb_paperclip/media_type_spoof_detector'

describe Paperclip::MediaTypeSpoofDetector do

  it 'should detect spoofing if content media type mismatch' do
    detector = Paperclip::MediaTypeSpoofDetector.new(File.new(fixture_file('5k.png'), 'rb'), '5k.pdf', 'application/pdf')
    expect(detector.spoofed?).to be_truthy
    detector = Paperclip::MediaTypeSpoofDetector.new(File.new(fixture_file('text.txt'), 'rb'), '5k.pdf', 'text/plain')
    expect(detector.spoofed?).to be_truthy
  end

  it 'should detect spoofing if content media type is the same' do
    detector = Paperclip::MediaTypeSpoofDetector.new(File.new(fixture_file('5k.png'), 'rb'), '5k.jpg', 'image/jpeg')
    expect(detector.spoofed?).to be_falsey
  end
end