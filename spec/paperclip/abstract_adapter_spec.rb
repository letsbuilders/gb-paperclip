require 'spec_helper'

describe Paperclip::AbstractAdapter do
  class TestAdapter < Paperclip::AbstractAdapter
    include TestData

    def path
      fixture_file('5k.png')
    end

    def content_type
      Paperclip::ContentTypeDetector.new(path).detect
    end
  end

  it 'should create SHA512 fingerprint' do
    expect(TestAdapter.new.fingerprint).to eq '7c5c04113ad65f96275db43e5d482b23d2253a95d28f824a103da56e5b89f4af00a4532e6132c3bcac0b93bdcf488a19ceb535df1a6d22bae3aa35d59979d61c'
  end
end