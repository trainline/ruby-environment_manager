# encoding: utf-8

Gem::Specification.new do |gem|
  gem.name                  = 'environment-manager'
  gem.authors               = [ "Marc Cluet" ]
  gem.email                 = 'marc.cluet@thetrainline.com'
  gem.homepage              = 'https://github.com/trainline/ruby-environment_manager'
  gem.summary               = 'Ruby client for Environment Manager'
  gem.description           = %q{ Ruby client that supports all API endpoints for Environment Manager }
  gem.license               = 'Apache-2.0'
  gem.version               = '0.2.1'
  gem.required_ruby_version = '>= 1.9.2'
  gem.files                 = Dir['{lib}/**/*']
  gem.require_paths         = %w[ lib ]
  gem.extra_rdoc_files      = ['LICENSE.txt', 'README.md']
  gem.add_dependency 'rest-client', '~> 2.0', '>= 2.0.0'
end
