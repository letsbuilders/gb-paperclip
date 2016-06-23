module TestData
  def attachment(options={})
    Paperclip::Attachment.new(:avatar, FakeModel.new, options)
  end

  def stringy_file
    StringIO.new('.\n')
  end

  def fixture_file(filename)
    File.join(File.dirname(__FILE__), 'fixtures', filename)
  end

  def open_file_count
    ObjectSpace.each_object(File).reject { |f| f.closed? }.count
  rescue IOError
    retry
  end

  def open_files
    ObjectSpace.each_object(File).reject { |f| f.closed? }
  rescue IOError
    retry
  end
end

module FileDebugInfo
  def initialize(*args)
    super
    @opened_at = Time.now
    @opener    = caller_locations(1, 20).join("\n")
  end

  def opener
    @opener
  end

  def open_for
    @opened_at ||= Time.now
    Time.now - @opened_at
  end

  def log_leak(timeout, logger, force=false)
    return if self.closed?
    if force || !@logged
      @logged = true
      if self.open_for > timeout
        logger.error "Open file: #{self.path} for #{self.open_for}s"
        logger.info "File open by:\n#{self.opener}" if opener
      end
    end
  end
end

class File
  prepend FileDebugInfo
end
