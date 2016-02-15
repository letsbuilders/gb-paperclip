require 'rubygems'
require 'rspec'
require 'active_record'
require 'active_record/version'
require 'active_support'
require 'active_support/core_ext'
require 'mocha/api'
require 'bourne'
require 'ostruct'
require 'simplecov'

SimpleCov.start do
  add_filter '/spec/'
  add_group 'Library core', %w(lib\/[^\/]*\.rb lib\/gb_paperclip\/[^\/]*\.rb)
  add_group 'Paperclip extensions', 'lib\/gb_paperclip\/paperclip\/[^\/]*\.rb'
  add_group 'IO Adapters', 'lib/gb_paperclip/paperclip/io_adapters'
  add_group 'Storage', 'lib/gb_paperclip/paperclip/storage'
end

SimpleCov.minimum_coverage 90

ROOT = Pathname(File.expand_path(File.join(File.dirname(__FILE__), '..')))

puts "Testing against version #{ActiveRecord::VERSION::STRING}"

$LOAD_PATH << File.join(ROOT, 'lib')
$LOAD_PATH << File.join(ROOT, 'lib', 'gb_paperclip')
require File.join(ROOT, 'lib', 'gb_paperclip.rb')

FIXTURES_DIR              = File.join(File.dirname(__FILE__), "fixtures")
config                    = YAML::load(IO.read(File.dirname(__FILE__) + '/database.yml'))
ActiveRecord::Base.logger = Logger.new(File.dirname(__FILE__) + "/debug.log")
ActiveRecord::Base.establish_connection(config['test'])
Paperclip.options[:logger] = ActiveRecord::Base.logger

Dir[File.join(ROOT, 'spec', 'support', '**', '*.rb')].each { |f| require f }

Rails                               = FakeRails.new('test', Pathname.new(ROOT).join('tmp'))
ActiveSupport::Deprecation.silenced = true

RSpec.configure do |config|
  config.include Assertions
  config.include ModelReconstruction
  config.include TestData
  config.extend VersionHelper
  config.extend RailsHelpers::ClassMethods
  config.mock_framework = :mocha
  config.before(:all) do
    rebuild_model
  end
  config.after(:each) do
    ActiveRecord::Base.clear_reloadable_connections!
  end
  config.after(:all) do
    FileUtils.rm_r Pathname.new(ROOT).join('tmp')
  end
end
