require 'gb_paperclip/paperclip/thumbnail'
require 'gb_paperclip/paperclip/attachment'
require 'gb_paperclip/paperclip/fake_geometry'

module Paperclip
  class PdfThumbnail < Paperclip::Thumbnail
    include ::NewRelic::Agent::Instrumentation::ControllerInstrumentation

    attr_accessor :style

    def initialize(file, options = {}, attachment = nil)
      NewRelic::Agent.manual_start unless NewRelic::Agent.agent
      options[:file_geometry_parser] = FakeGeometry
      super
      @file                          = file

      @style = options[:style]

      if @attachment
        src        = @file
        @safe_copy = Tempfile.new([@basename, @format ? ".#{@format}" : ''])
        FileUtils.cp src.path, @safe_copy.path, verbose: true
      end
    end

    def current_geometry
      unless @current_geometry
        @current_geometry = Geometry.from_file(@safe_copy)
        if @auto_orient && @current_geometry.respond_to?(:auto_orient)
          @current_geometry.auto_orient
        end
        @current_geometry.width  = 1 if @current_geometry.width == 0
        @current_geometry.height = 1 if @current_geometry.height == 0
      end
      @current_geometry
    end

    def make
      if @attachment
        CentralDispatch.dispatch_async do
          source_path = "#{File.expand_path(@safe_copy.path)}#{'[0]' unless animated?}"
          process_thumbnails source_path
        end
        nil
      else
        super
      end
    end

    def process_thumbnails(source_path)
      dst = Tempfile.new([@basename, @format ? ".#{@format}" : ''])
      dst.binmode
      begin
        parameters = []
        parameters << source_file_options
        parameters << ['-background white', '-flatten']
        parameters << ":source"
        parameters << transformation_command
        parameters << convert_options
        parameters << ":dest"

        parameters = parameters.flatten.compact.join(" ").strip.squeeze(" ")

        success = convert(parameters, :source => source_path, :dest => File.expand_path(dst.path))
      rescue Cocaine::ExitStatusError => e
        @attachment.failed_processing @style if @attachment && @style
        raise Paperclip::Error, "There was an error processing the thumbnail for #{@basename}" if @whiny
      rescue Cocaine::CommandNotFoundError => e
        @attachment.failed_processing @style if @attachment && @style
        raise Paperclip::Errors::CommandNotFoundError.new("Could not run the `convert` command. Please install ImageMagick.")
      end
      while @attachment.is_saving?
        sleep 0.01
      end
      @attachment.queued_for_write[@style] = Paperclip.io_adapters.for(dst) if dst
      @attachment.flush_writes unless @attachment.is_dirty?
      @attachment.finished_processing @style
      begin
        @safe_copy.close
      rescue Exception => e
        Opbeat.capture_exception(e)
      end
      begin
        @safe_copy.unlink
      rescue Exception => e
        Opbeat.capture_exception(e)
      end
      begin
        dst.close if dst.respond_to? :close
      rescue
        nil
      end
    rescue Exception => e
      Opbeat.capture_exception(e)
      @attachment.failed_processing @style if @attachment && @style
      raise e
    end

    # Returns the command ImageMagick's +convert+ needs to transform the image
    # into the thumbnail.
    def transformation_command
      scale, crop = current_geometry.transformation_to(@target_geometry, crop?)
      trans       = []
      trans << "-coalesce" if animated?
      trans << "-auto-orient" if auto_orient
      trans << "-resize" << %["#{scale}"] unless scale.nil? || scale.empty?
      trans << "-crop" << %["#{crop}"] << "+repage" if crop
      trans << '-layers "optimize"' if animated?
      trans
    end

    add_transaction_tracer :current_geometry
    add_transaction_tracer :process_thumbnails
  end
end
