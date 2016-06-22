require 'paperclip/thumbnail'
module Paperclip
  class Thumbnail
    module SaveExtension
      def initialize(file, options = {}, attachment = nil)
        super
        @style = options[:style]
      end

      def make
        src = @file
        dst = Tempfile.new([@basename, @format ? ".#{@format}" : ''])
        dst.binmode

        begin
          parameters = []
          parameters << source_file_options
          parameters << ":source"
          parameters << transformation_command
          parameters << convert_options
          parameters << ":dest"

          parameters = parameters.flatten.compact.join(" ").strip.squeeze(" ")

          success = convert(parameters, :source => "#{File.expand_path(src.path)}#{'[0]' unless animated?}", :dest => File.expand_path(dst.path))
          @attachment.finished_processing @style if @attachment && @style
        rescue Cocaine::ExitStatusError => e
          @attachment.failed_processing @style if @attachment && @style
          raise Paperclip::Error, "There was an error processing the thumbnail for #{@basename}" if @whiny
        rescue Cocaine::CommandNotFoundError => e
          @attachment.failed_processing @style if @attachment && @style
          raise Paperclip::Errors::CommandNotFoundError.new("Could not run the `convert` command. Please install ImageMagick.")
        end
        dst
      end
    end

    prepend SaveExtension
  end
end