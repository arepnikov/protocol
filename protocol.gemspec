# -*- encoding: utf-8 -*-
Gem::Specification.new do |s|
  s.name = 'evt-protocol'
  s.version = '2.0.0.0'
  s.summary = ''
  s.description = ' '

  s.authors = ['The Eventide Project']
  s.email = 'opensource@eventide-project.org'
  s.homepage = 'https://github.com/eventide-project/protocol'
  s.licenses = ['MIT']

  s.require_paths = ['lib']
  s.files = Dir.glob('{lib}/**/*')
  s.platform = Gem::Platform::RUBY
  s.required_ruby_version = '>= 2.7.0'

  s.add_development_dependency 'test_bench'
end
