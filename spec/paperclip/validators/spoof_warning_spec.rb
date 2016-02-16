require 'spec_helper'

describe Paperclip::Validators::AttachmentSpoofWarningValidator do
  before(:all) do
    rebuild_model(validate_media_type: false)
    class SpoofDummy < Dummy
      attr_accessor :avatar_spoof_warning, :avatar_spoof_content_type
      validates_spoof_warning :avatar
    end
  end

  before (:each) do
    @dummy = SpoofDummy.new
  end

  def build_validator(options = {})
    @validator = Paperclip::Validators::AttachmentSpoofWarningValidator.new(options.merge(
        attributes: :avatar
    ))
  end

  it "isn't on the attachment without being explicitly added" do
    expect(Dummy.validators_on(:avatar).any? { |validator| validator.kind == :attachment_spoof_warning }).to be_falsey
  end

  it 'is on the attachment when explicitly added' do
    expect(SpoofDummy.validators_on(:avatar).any? { |validator| validator.kind == :attachment_spoof_warning }).to be_truthy
  end

  it 'add info about spoofed media type' do
    build_validator
    file = File.new(fixture_file('5k.png'), 'rb')
    @dummy.avatar.assign(file)

    detector = mock('detector', :content_type_mismatch? => true, :spoofed_content_type => 'image/png')
    Paperclip::MediaTypeSpoofDetector.stubs(:using).returns(detector)
    @validator.validate(@dummy)

    expect(@dummy.avatar_spoof_warning).to eq true
    expect(@dummy.avatar_spoof_content_type).to eq 'image/png'
  end

  it 'runs when attachment is dirty' do
    build_validator
    file = File.new(fixture_file('5k.png'), 'rb')
    @dummy.avatar.assign(file)

    Paperclip::MediaTypeSpoofDetector.expects(:using).returns(stub(:content_type_mismatch? => false))
    @dummy.valid?
  end
end