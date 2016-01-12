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

  s.add_dependency 'paperclip', '>=4.2.0'
  s.add_dependency 'gb_dispatch', '~> 0.0.1'
  #s.metadata['allowed_push_host'] = 'http://gems.bobisdead.com/'
end
