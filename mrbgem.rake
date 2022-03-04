MRuby::Gem::Specification.new('smart-ratelimit') do |spec|
  spec.license = 'MIT'
  spec.authors = 'pyama86'
  spec.add_dependency 'mruby-time'
  spec.add_dependency 'mruby-secure-random', github: 'monochromegane/mruby-secure-random', branch: 'master'
  spec.add_dependency 'mruby-exec',  github: 'haconiwa/mruby-exec', branch: 'master'
  spec.add_dependency 'mruby-redis', github: 'matsumotory/mruby-redis', branch: 'master'
  spec.add_dependency 'mruby-onig-regexp'
  spec.add_dependency 'mruby-array-ext'
  spec.add_test_dependency 'mruby-print'
end
