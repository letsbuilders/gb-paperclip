require 'spec_helper'


describe Paperclip::PdfThumbnail do
  context 'sync' do
    context 'An normal pdf' do
      before do
        @file = File.new(fixture_file('twopage.pdf'), 'rb')
      end

      after { @file.close }

      [%w(600x600> 464x600),
       %w(400x400> 309x400),
       %w(32x32< 612x792),
       [nil, '612x792']
      ].each do |args|
        context "being thumbnailed with a geometry of #{args[0]}" do
          before do
            @thumb = Paperclip::PdfThumbnail.new(@file, geometry: args[0])
          end

          it 'starts with dimensions of 612x792' do
            cmd = %Q[identify -format "%wx%h" "#{@file.path}[0]"]
            assert_equal '612x792', `#{cmd}`.chomp
          end

          it 'reports the correct target geometry' do
            assert_equal args[0].to_s, @thumb.target_geometry.to_s
          end

          context 'when made' do
            before do
              @thumb_result = @thumb.make
            end

            it 'is the size we expect it to be' do
              cmd = %Q[identify -format "%wx%h" "#{@thumb_result.path}"]
              assert_equal args[1], `#{cmd}`.chomp
            end
          end
        end
      end

      context 'being thumbnailed at 100x50 with cropping' do
        before do
          @thumb = Paperclip::PdfThumbnail.new(@file, geometry: '100x50#')
        end

        it "lets us know when a command isn't found versus a processing error" do
          old_path = ENV['PATH']
          begin
            Terrapin::CommandLine.path        = ''
            Paperclip.options[:command_path] = ''
            ENV['PATH']                      = ''
            assert_raises(Paperclip::Errors::CommandNotFoundError) do
              silence_stream(STDERR) do
                @thumb.make
              end
            end
          ensure
            ENV['PATH'] = old_path
          end
        end

        it 'reports its correct current and target geometries' do
          assert_equal '100x50#', @thumb.target_geometry.to_s
          assert_equal '612x792', @thumb.current_geometry.to_s
        end

        it 'reports its correct format' do
          assert_nil @thumb.format
        end

        it 'has whiny turned on by default' do
          assert @thumb.whiny
        end

        it 'has convert_options set to nil by default' do
          assert_equal nil, @thumb.convert_options
        end

        it 'has source_file_options set to nil by default' do
          assert_equal nil, @thumb.source_file_options
        end

        it 'sends the right command to convert when sent #make' do
          @thumb.expects(:convert).with do |*arg|
            arg[0] == ':source -auto-orient -resize "100x" -crop "100x50+0+39!" +repage :dest' &&
                arg[1][:source] == "#{File.expand_path(@thumb.file.path)}[0]"
          end
          @thumb.make
        end

        it 'creates the thumbnail when sent #make' do
          dst = @thumb.make
          assert_match /100x50/, `identify "#{dst.path}"`
        end
      end

      it 'crops a EXIF-rotated image properly' do
        file  = File.new(fixture_file('rotated.jpg'))
        thumb = Paperclip::PdfThumbnail.new(file, geometry: '50x50#')

        output_file = thumb.make

        command = Terrapin::CommandLine.new('identify', '-format %wx%h :file')
        assert_equal '50x50', command.run(file: output_file.path).strip
      end

      context 'being thumbnailed with source file options set' do
        before do
          @thumb = Paperclip::PdfThumbnail.new(@file,
                                               geometry:            '100x50#',
                                               source_file_options: '-strip')
        end

        it 'has source_file_options value set' do
          assert_equal ['-strip'], @thumb.source_file_options
        end

        it 'sends the right command to convert when sent #make' do
          @thumb.expects(:convert).with do |*arg|
            arg[0] == '-strip :source -auto-orient -resize "100x" -crop "100x50+0+39!" +repage :dest' &&
                arg[1][:source] == "#{File.expand_path(@thumb.file.path)}[0]"
          end
          @thumb.make
        end

        it 'creates the thumbnail when sent #make' do
          dst = @thumb.make
          assert_match /100x50/, `identify "#{dst.path}"`
        end

        context 'redefined to have bad source_file_options setting' do
          before do
            @thumb = Paperclip::PdfThumbnail.new(@file,
                                                 geometry:            '100x50#',
                                                 source_file_options: '-this-aint-no-option')
          end

          it 'errors when trying to create the thumbnail' do
            assert_raises(Paperclip::Error) do
              silence_stream(STDERR) do
                @thumb.make
              end
            end
          end
        end
      end

      context 'being thumbnailed with convert options set' do
        before do
          @thumb = Paperclip::PdfThumbnail.new(@file,
                                               geometry:        '100x50#',
                                               convert_options: '-strip -depth 8')
        end

        it 'has convert_options value set' do
          assert_equal %w"-strip -depth 8", @thumb.convert_options
        end

        it 'sends the right command to convert when sent #make' do
          @thumb.expects(:convert).with do |*arg|
            arg[0] == ':source -auto-orient -resize "100x" -crop "100x50+0+39!" +repage -strip -depth 8 :dest' &&
                arg[1][:source] == "#{File.expand_path(@thumb.file.path)}[0]"
          end
          @thumb.make
        end

        it 'creates the thumbnail when sent #make' do
          dst = @thumb.make
          assert_match /100x50/, `identify "#{dst.path}"`
        end

        context 'redefined to have bad convert_options setting' do
          before do
            @thumb = Paperclip::PdfThumbnail.new(@file,
                                                 geometry:        '100x50#',
                                                 convert_options: '-this-aint-no-option')
          end

          it 'errors when trying to create the thumbnail' do
            assert_raises(Paperclip::Error) do
              silence_stream(STDERR) do
                @thumb.make
              end
            end
          end

          it "lets us know when a command isn't found versus a processing error" do
            old_path = ENV['PATH']
            begin
              Terrapin::CommandLine.path        = ''
              Paperclip.options[:command_path] = ''
              ENV['PATH']                      = ''
              assert_raises(Paperclip::Errors::CommandNotFoundError) do
                silence_stream(STDERR) do
                  @thumb.make
                end
              end
            ensure
              ENV['PATH'] = old_path
            end
          end
        end
      end

      context 'being thumbnailed with a blank geometry string' do
        before do
          @thumb = Paperclip::PdfThumbnail.new(@file,
                                               geometry:        '',
                                               convert_options: "-gravity center -crop \"300x300+0-0\"")
        end

        it 'does not get resized by default' do
          assert !@thumb.transformation_command.include?('-resize')
        end
      end

      context 'being thumbnailed with default animated option (true)' do
        it 'calls identify to check for animated images when sent #make' do
          thumb = Paperclip::PdfThumbnail.new(@file, geometry: '100x50#')
          thumb.expects(:identify).at_least_once.with do |*arg|
            arg[0] == '-format %m :file' &&
                arg[1][:file] == "#{File.expand_path(thumb.file.path)}[0]"
          end
          thumb.make
        end
      end

      context 'passing a custom file geometry parser' do
        after do
          Object.send(:remove_const, :GeoParser) if Object.const_defined?(:GeoParser)
        end

        it 'produces the appropriate transformation_command' do
          GeoParser = Class.new do
            def self.from_file(file)
              new
            end

            def transformation_to(target, should_crop)
              %w(SCALE CROP)
            end
          end

          thumb = Paperclip::PdfThumbnail.new(@file, geometry: '50x50', file_geometry_parser: ::GeoParser)

          transformation_command = thumb.transformation_command

          assert transformation_command.include?('-crop'),
                 %{expected #{transformation_command.inspect} to include '-crop'}
          assert transformation_command.include?('"CROP!"'),
                 %{expected #{transformation_command.inspect} to include '"CROP"'}
          assert transformation_command.include?('-resize'),
                 %{expected #{transformation_command.inspect} to include '-resize'}
          assert transformation_command.include?('"SCALE"'),
                 %{expected #{transformation_command.inspect} to include '"SCALE"'}
        end
      end

      context 'passing a custom geometry string parser' do
        after do
          Object.send(:remove_const, :GeoParser) if Object.const_defined?(:GeoParser)
        end

        it 'produces the appropriate transformation_command' do
          GeoParser = Class.new do
            def self.parse(s)
              new
            end

            def to_s
              '151x167'
            end
          end

          thumb = Paperclip::PdfThumbnail.new(@file, geometry: '50x50', string_geometry_parser: ::GeoParser)

          transformation_command = thumb.transformation_command

          assert transformation_command.include?('"151x167"'),
                 %{expected #{transformation_command.inspect} to include '151x167'}
        end
      end
    end
  end

  context 'async' do
    context 'An normal pdf' do
      before do
        @file = File.new(fixture_file('twopage.pdf'), 'rb')
        rebuild_model storage: :fake
        @dummy      = Dummy.new
        @attachment = @dummy.avatar
        wait_for_make
      end

      after { @file.close }

      [%w(600x600> 464x600),
       %w(400x400> 309x400),
       %w(32x32< 612x792),
       [nil, '612x792']
      ].each do |args|
        context "being thumbnailed with a geometry of #{args[0]}" do
          before do
            @thumb = Paperclip::PdfThumbnail.new(@file, { geometry: args[0], style: :test }, @attachment)
          end

          it 'starts with dimensions of 612x792' do
            cmd = %Q[identify -format "%wx%h" "#{@file.path}[0]"]
            assert_equal '612x792', `#{cmd}`.chomp
          end

          it 'reports the correct target geometry' do
            assert_equal args[0].to_s, @thumb.target_geometry.to_s
          end

          context 'when made' do
            before do
              stub_attachment
              @thumb.make
              wait_for_make
              wait_for_save
              @thumb_result = @attachment.saved[:test]
            end

            after do
              @thumb_result.close
            end

            it 'is the size we expect it to be' do
              cmd = %Q[identify -format "%wx%h" "#{@thumb_result.path}"]
              assert_equal args[1], `#{cmd}`.chomp
            end
          end
        end
      end

      context 'being thumbnailed at 100x50 with cropping' do
        before do
          @thumb = Paperclip::PdfThumbnail.new(@file, { geometry: '100x50#', style: :test }, @attachment)
        end

        it "lets us know when a command isn't found versus a processing error" do
          old_path = ENV['PATH']
          begin
            Terrapin::CommandLine.path        = ''
            Paperclip.options[:command_path] = ''
            ENV['PATH']                      = ''
            silence_stream(STDERR) do
              @thumb.make
            end
            wait_for_make
            wait_for_save
            expect(@attachment.instance.processing).to be_falsey
            expect(@attachment.instance.processed_styles ||= []).not_to include(:test, 'test')
          ensure
            ENV['PATH'] = old_path
          end
        end

        it 'reports its correct current and target geometries' do
          assert_equal '100x50#', @thumb.target_geometry.to_s
          assert_equal '612x792', @thumb.current_geometry.to_s
        end

        it 'reports its correct format' do
          expect(@thumb.format).to eq :jpg
        end

        it 'has whiny turned on by default' do
          assert @thumb.whiny
        end

        it 'has convert_options set to nil by default' do
          assert_equal nil, @thumb.convert_options
        end

        it 'has source_file_options set to nil by default' do
          assert_equal nil, @thumb.source_file_options
        end

        it 'sends the right command to convert when sent #make' do
          @thumb.expects(:convert).with do |*arg|
            arg[0] == '-background white -flatten :source -auto-orient -resize "100x" -crop "100x50+0+39!" +repage :dest' &&
                arg[1][:source] == "#{File.expand_path(@thumb.safe_copy.path)}[0]"
          end
          @thumb.make
          wait_for_make
        end

        it 'creates the thumbnail when sent #make' do
          stub_attachment
          @thumb.make
          wait_for_make
          wait_for_save
          dst = @attachment.saved[:test]
          assert_match /100x50/, `identify "#{dst.path}"`
          dst.close
        end
      end

      it 'crops a EXIF-rotated image properly' do
        @attachment.instance_eval 'def after_flush_writes; end'
        file  = File.new(fixture_file('cadimage.pdf'))
        thumb = Paperclip::PdfThumbnail.new(file, { geometry: '50x50#', style: :test }, @attachment)

        thumb.make
        wait_for_make
        wait_for_save
        output_file = @attachment.saved[:test]

        command = Terrapin::CommandLine.new('identify', '-format %wx%h :file')
        expect(command.run(file: output_file.path).strip).to eq '50x50'
        output_file.close
      end

      context 'being thumbnailed with source file options set' do
        before do
          @thumb = Paperclip::PdfThumbnail.new(@file, {
              geometry:            '100x50#',
              source_file_options: '-strip',
              style:               :test },
                                               @attachment)
        end

        it 'has source_file_options value set' do
          assert_equal ['-strip'], @thumb.source_file_options
        end

        it 'sends the right command to convert when sent #make' do
          @thumb.expects(:convert).with do |*arg|
            arg[0] == '-strip -background white -flatten :source -auto-orient -resize "100x" -crop "100x50+0+39!" +repage :dest' &&
                arg[1][:source] == "#{File.expand_path(@thumb.safe_copy.path)}[0]"
          end
          @thumb.make
          wait_for_make
        end

        it 'creates the thumbnail when sent #make' do
          stub_attachment
          @thumb.make
          wait_for_make
          wait_for_save
          dst = @attachment.saved[:test]
          assert_match /100x50/, `identify "#{dst.path}"`
          dst.close
        end

        context 'redefined to have bad source_file_options setting' do
          before do
            @thumb = Paperclip::PdfThumbnail.new(@file,
                                                 { geometry:            '100x50#',
                                                   source_file_options: '-this-aint-no-option',
                                                   style:               :test },
                                                 @attachment)
          end

          it 'errors when trying to create the thumbnail' do
            silence_stream(STDERR) do
              @thumb.make
            end
            wait_for_make
            expect(@dummy.processing).to be_falsey
            expect(@dummy.processed_styles ||= []).not_to include(:test, 'test')
          end
        end
      end

      context 'being thumbnailed with convert options set' do
        before do
          @thumb = Paperclip::PdfThumbnail.new(@file,
                                               { geometry:        '100x50#',
                                                 convert_options: '-strip -depth 8',
                                                 style:           :test }, @attachment)
        end

        it 'has convert_options value set' do
          assert_equal %w"-strip -depth 8", @thumb.convert_options
        end

        it 'sends the right command to convert when sent #make' do
          @thumb.expects(:convert).with do |*arg|
            arg[0] == '-background white -flatten :source -auto-orient -resize "100x" -crop "100x50+0+39!" +repage -strip -depth 8 :dest' &&
                arg[1][:source] == "#{File.expand_path(@thumb.safe_copy.path)}[0]"
          end
          @thumb.make
          wait_for_make
        end

        it 'creates the thumbnail when sent #make' do
          stub_attachment
          @thumb.make
          wait_for_make
          wait_for_save
          dst = @attachment.saved[:test]
          assert_match /100x50/, `identify "#{dst.path}"`
          dst.close
        end

        context 'redefined to have bad convert_options setting' do
          before do
            @thumb = Paperclip::PdfThumbnail.new(@file,
                                                 { geometry:        '100x50#',
                                                   convert_options: '-this-aint-no-option', style: :test }, @attachment)
          end

          it 'errors when trying to create the thumbnail' do
            silence_stream(STDERR) do
              @thumb.make
            end
            wait_for_make
            wait_for_save
            expect(@dummy.processing).to be_falsey
            expect(@dummy.processed_styles ||= []).not_to include(:test, 'test')
          end
        end
      end

      context 'being thumbnailed with a blank geometry string' do
        before do
          @thumb = Paperclip::PdfThumbnail.new(@file,
                                               { geometry:        '',
                                                 convert_options: "-gravity center -crop \"300x300+0-0\"",
                                                 style:           :test }, @attachment)
        end

        it 'does not get resized by default' do
          assert !@thumb.transformation_command.include?('-resize')
        end
      end

      context 'passing a custom file geometry parser' do
        after do
          Object.send(:remove_const, :GeoParser) if Object.const_defined?(:GeoParser)
        end

        it 'produces the appropriate transformation_command' do
          GeoParser = Class.new do
            def self.from_file(file)
              new
            end

            def transformation_to(target, should_crop)
              %w(SCALE CROP)
            end
          end

          thumb = Paperclip::PdfThumbnail.new(@file, {
              geometry:             '50x50',
              file_geometry_parser: ::GeoParser,
              style:                :test
          },
                                              @attachment
          )

          transformation_command = thumb.transformation_command

          assert transformation_command.include?('-crop'),
                 %{expected #{transformation_command.inspect} to include '-crop'}
          assert transformation_command.include?('"CROP!"'),
                 %{expected #{transformation_command.inspect} to include '"CROP"'}
          assert transformation_command.include?('-resize'),
                 %{expected #{transformation_command.inspect} to include '-resize'}
          assert transformation_command.include?('"SCALE"'),
                 %{expected #{transformation_command.inspect} to include '"SCALE"'}
        end
      end

      context 'passing a custom geometry string parser' do
        after do
          Object.send(:remove_const, :GeoParser) if Object.const_defined?(:GeoParser)
        end

        it 'produces the appropriate transformation_command' do
          GeoParser = Class.new do
            def self.parse(s)
              new
            end

            def to_s
              '151x167'
            end
          end

          thumb = Paperclip::PdfThumbnail.new(@file, { geometry: '50x50', string_geometry_parser: ::GeoParser, style: :test }, @attachment)

          transformation_command = thumb.transformation_command

          assert transformation_command.include?('"151x167"'),
                 %{expected #{transformation_command.inspect} to include '151x167'}
        end
      end
    end

    context 'Attachment processing info' do
      before(:each) do
        @file = File.new(fixture_file('twopage.pdf'), 'rb')
        rebuild_model storage: :fake
        @dummy      = Dummy.new
        @attachment = @dummy.avatar
        @thumb      = Paperclip::PdfThumbnail.new(@file, { geometry: '100x50#', style: :test }, @attachment)
        wait_for_make
      end

      after(:each) { @file.close }

      it 'should call finished processing style if successes' do
        @attachment.expects(:finished_processing).with(:test)
        @thumb.make
        wait_for_make
        wait_for_save
      end

      it 'should call finished processing style if successes and is_dirty' do
        @attachment.expects(:finished_processing).with(:test)
        @attachment.stubs(:is_dirty?).returns(true)
        @thumb.make
        wait_for_make
      end

      context 'should call failed processing style if' do
        it 'image magick have wrong params' do
          @attachment.expects(:failed_processing).with(:test)
          @thumb.stubs(:convert).with(anything, anything).raises(Terrapin::ExitStatusError.new '')
          expect { @thumb.make }.not_to raise_error
          wait_for_make
        end

        it 'image magick error' do
          @thumb.current_geometry
          @attachment.expects(:failed_processing).with(:test)
          old_path = ENV['PATH']
          begin
            Terrapin::CommandLine.path        = ''
            Paperclip.options[:command_path] = ''
            ENV['PATH']                      = ''
            expect do
              silence_stream(STDERR) do
                @thumb.make
              end
            end.not_to raise_error Paperclip::Errors::CommandNotFoundError
            wait_for_make
          ensure
            ENV['PATH'] = old_path
          end
        end

        it 'convert throws any error' do
          @attachment.expects(:failed_processing).with(:test)
          @thumb.stubs(:convert).with(anything, anything).raises('test error')
          expect { @thumb.make }.not_to raise_error
          wait_for_make
        end

        it 'save throws any error' do
          @attachment.expects(:failed_processing).with(:test)
          @attachment.stubs(:flush_writes).with(anything).raises('test error')
          expect { @thumb.make }.not_to raise_error
          wait_for_make
          wait_for_save
        end

        it 'attachment throw error' do
          @attachment.expects(:failed_processing).with(:test)
          @attachment.stubs(:is_saving?).raises('test error')
          @thumb.make
          wait_for_make
        end
      end
    end

    context 'should save attachment' do
      before(:each) do
        @file = File.new(fixture_file('twopage.pdf'), 'rb')
        rebuild_model storage: :fake
        @dummy        = Dummy.new
        @dummy.avatar = @file
        @attachment   = @dummy.avatar
        @thumb        = Paperclip::PdfThumbnail.new(@file, { geometry: '100x50#', style: :test }, @attachment)
      end

      after(:each) do
        @file.close
      end

      it 'should wait if files being saved right now' do
        @attachment.instance_variable_set :@is_saving, true
        @attachment.instance_variable_set :@dirty, false
        @thumb.make
        sleep(0.5)
        expect(@attachment.saved[:test]).to be_nil
        @attachment.instance_variable_set :@is_saving, false
        wait_for_make
        wait_for_save
        expect(@attachment.saved[:test]).to be_truthy
      end

      it 'should not make deadlock if is dirty' do
        @dummy.save!
        @attachment.processing :test
        @attachment.instance_variable_set :@dirty, true
        @thumb.make
        sleep(0.5)
        expect(@attachment.saved[:test]).to be_nil
        @attachment.instance_variable_set :@is_saving, false
        wait_for_make
        wait_for_save
        expect(@dummy.processed_styles).to include :test
      end

      it 'should save files if attachment is not dirty' do
        @attachment.instance_variable_set :@dirty, false
        @thumb.make
        wait_for_make
        wait_for_save
        expect(@attachment.saved[:test]).to be_truthy
      end
    end
  end

  def stub_attachment
    @attachment.instance_eval 'def after_flush_writes; end'
  end

  def wait_for_make
    GBDispatch.dispatch_sync_on_queue :paperclip_test do
      puts 'waiting for make'
    end
  end

  def wait_for_save
    GBDispatch.dispatch_sync_on_queue :paperclip_upload do
      puts 'waiting for save'
    end
  end
end