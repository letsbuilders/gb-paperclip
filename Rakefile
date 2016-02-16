begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:spec)

  task :default => :spec
rescue LoadError
end

task :build => :spec do
  sh 'gem build ./gb-paperclip.gemspec'
end

task :release do
  require './lib/gb_paperclip/version'
  sh "gem push gb_paperclip-#{GBPaperclip::VERSION}.gem --host http://tools.bobisdead.com/gems"
end