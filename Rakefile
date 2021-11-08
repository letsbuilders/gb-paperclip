begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:spec)

  task :default => :spec
rescue LoadError
  nil
end

task :build => :spec do
  sh 'gem build ./gb-paperclip.gemspec'
end

task :release do
  require './lib/gb_paperclip/version'
  sh "gem push gb_paperclip-#{GBPaperclip::VERSION}.gem --host https://t.gb4.co/gems"
end