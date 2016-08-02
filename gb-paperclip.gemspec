$:.push File.expand_path('../lib', __FILE__)

# Maintain your gem's version:
require 'gb_paperclip/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = 'gb_paperclip'
  s.version     = GBPaperclip::VERSION
  s.authors     = ['Kacper Kawecki']
  s.email       = ['kacper@geniebelt.com']
  s.homepage    = 'http://tools.bobisdead.com'
  s.summary     = 'Genie Belt Paperclip extensions'
  s.description = 'Extensions for paperclip'

  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.files         = `git ls-files lib`.split("\n") + ['README.md']
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ['lib']

  s.add_dependency 'paperclip', '>=5.0.0'
  s.add_dependency 'gb_dispatch', '>= 0.0.6'
  #s.metadata['allowed_push_host'] = 'http://gems.bobisdead.com/'
  s.add_development_dependency('activerecord', '>= 3.0.0')
  s.add_development_dependency('shoulda')
  s.add_development_dependency('rspec', '>=3.0.0')
  s.add_development_dependency('appraisal')
  s.add_development_dependency('mocha')
  s.add_development_dependency('aws-sdk', '>= 2.0.0')
  s.add_development_dependency('aws-sdk-v1')
  s.add_development_dependency('bourne')
  s.add_development_dependency('nokogiri')
  # Ruby version < 1.9.3 can't install capybara > 2.0.3.
  s.add_development_dependency('bundler')
  s.add_development_dependency('fog', '~> 1.0')
  s.add_development_dependency('launchy')
  s.add_development_dependency('rake')
  s.add_development_dependency('fakeweb')
  s.add_development_dependency('railties')
  #s.add_development_dependency('actionmailer', '>= 3.0.0')
  s.add_development_dependency('generator_spec')
  s.add_development_dependency('timecop')
  s.add_development_dependency('rubyzip')
end
