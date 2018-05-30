require 'paperclip/thumbnail'
require 'gb_paperclip/paperclip/thumbnail'
require 'gb_paperclip/paperclip/attachment'
require 'gb_paperclip/paperclip/fake_geometry'
require 'gb_paperclip/paperclip/geometry_parser'
require 'gb_dispatch'

module Paperclip
  class PdfThumbnail < Paperclip::Thumbnail

    attr_accessor :style, :safe_copy

    def initialize(file, options = {}, attachment = nil)
      @file_geometry_parser          = options[:file_geometry_parser] || Geometry
      options[:file_geometry_parser] = FakeGeometry
      super
      @file = file

      if @attachment
        src        = @file
        @safe_copy = Tempfile.new([@basename, @current_format])
        @format    ||= :jpg
        FileUtils.cp src.path, @safe_copy.path, verbose: true
      end
    end

    def current_geometry
      unless @current_geometry
        @current_geometry = @file_geometry_parser.from_file(@safe_copy || @file)
        if @auto_orient && @current_geometry.respond_to?(:auto_orient)
          @current_geometry.auto_orient
        end
        @current_geometry.width  = 1 if @current_geometry.respond_to?(:width) && @current_geometry.width == 0
        @current_geometry.height = 1 if @current_geometry.respond_to?(:width) && @current_geometry.height == 0
      end
      @current_geometry
    end

    def make
      if @attachment
        queue = @style ? "paperclip_#{@style}" : :paperclip
        GBDispatch.dispatch_async_on_queue queue do
          source_path = "#{File.expand_path(@safe_copy.path)}"
          process_thumbnails source_path
        end
        nil
      else
        super
      end
    end

    def process_thumbnails(source_path)
      dst = Tempfile.new([@basename, ".#{@format}"])
      dst.binmode
      begin
        parameters = []
        parameters << source_file_options
        parameters << ['-background white', '-flatten']
        parameters << ':source'
        parameters << transformation_command
        parameters << convert_options
        parameters << ':dest'

        parameters  = parameters.flatten.compact.join(' ').strip.squeeze(' ')

        source_path +='[0]' unless animated?

        convert(parameters, :source => source_path, :dest => File.expand_path(dst.path))
      rescue Terrapin::ExitStatusError => e
        @attachment.failed_processing @style if @attachment && @style
        unlink_files @safe_copy, dst
        raise Paperclip::Error, "There was an error processing the thumbnail for #{@basename}" if @whiny
      rescue Terrapin::CommandNotFoundError
        @attachment.failed_processing @style if @attachment && @style
        unlink_files @safe_copy, dst
        raise Paperclip::Errors::CommandNotFoundError.new('Could not run the `convert` command. Please install ImageMagick.')
      rescue Exception => e
        @attachment.failed_processing @style if @attachment && @style
        unlink_files @safe_copy, dst
        raise e
      end
      begin
        while @attachment.is_saving?
          sleep 0.01
        end
        @attachment.change_queued_for_write do |queue|
          queue[@style] = Paperclip.io_adapters.for(dst) if dst
        end
        @attachment.with_save_lock do
          if @attachment.is_dirty?
            GBDispatch.dispatch_async_on_queue(:paperclip_upload) do
              @attachment.finished_processing @style
            end
          else
            GBDispatch.dispatch_async_on_queue(:paperclip_upload) do
              begin
                @attachment.flush_writes
                @attachment.finished_processing @style
              rescue Exception => e
                @attachment.failed_processing @style
                raise e
              end
            end
          end
        end
      rescue Exception => e
        @attachment.failed_processing @style if @attachment && @style
        unlink_files @safe_copy, dst
        raise e
      end

      unlink_files @safe_copy, dst
    end

    # Returns the command ImageMagick's +convert+ needs to transform the image
    # into the thumbnail.
    def transformation_command
      scale, crop = current_geometry.transformation_to(@target_geometry, crop?)
      trans       = []
      trans << '-coalesce' if animated?
      trans << '-auto-orient' if auto_orient
      trans << '-resize' << %["#{scale}"] unless scale.nil? || scale.empty?
      trans << '-crop' << %["#{crop}!"] << '+repage' if crop
      trans << '-layers "optimize"' if animated?
      trans
    end

    def unlink_files(*files)
      Array(files).each do |file|
        file.close unless file.closed?
        file.unlink if file.respond_to?(:unlink) && file.path.present? && File.exist?(file.path)
      end
    end
  end
end
