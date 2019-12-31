# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ruby_job/version'

Gem::Specification.new do |spec|
  spec.name          = 'ruby_job'
  spec.version       = RubyJob::VERSION
  spec.authors       = ['Marco Imperatore']
  spec.email         = ['mimperatore@gmail.com']

  spec.summary       = <<~ENDOFSTRING
    RubyJob is a framework for running jobs.
  ENDOFSTRING
  spec.description = <<~ENDOFSTRING
    RubyJob is a framework for running jobs.
  ENDOFSTRING
  spec.homepage      = 'https://mimperatore.github.io/ruby_job/'
  spec.license       = 'LGPL-3.0'

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 2.1'
  spec.add_development_dependency 'byebug', '~> 11.0'
  spec.add_development_dependency 'codecov', '~> 0.1'
  spec.add_development_dependency 'guard', '~> 2.16'
  spec.add_development_dependency 'guard-rspec', '~> 4.7'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.9'
  spec.add_development_dependency 'rubocop', '~> 0.78'
  spec.add_development_dependency 'timecop', '~> 0.9'
  spec.add_dependency 'pqueue', '~> 2.1'
end
