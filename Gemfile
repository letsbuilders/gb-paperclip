source 'http://rubygems.org'
ruby '2.2.2'

# Declare your gem's dependencies in push.gemspec.
# Bundler will treat runtime dependencies like base dependencies, and
# development dependencies will be added by default to the :development group.
gemspec


gem 'paperclip'
gem 'gb_dispatch'

group :development do
  gem 'guard'
end

group :test do
  #gem 'activerecord', :require => 'active_record'
  gem 'sqlite3'
  gem 'rspec', '>3.0'
  gem 'simplecov', :require => false
end
