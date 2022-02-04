MRUBY_CONFIG=File.expand_path(ENV["MRUBY_CONFIG"] || "build_config.rb")
file :mruby do
  sh "git clone git://github.com/mruby/mruby.git"
end

desc "test"
task :test => :mruby do
  sh "misc/redis.sh"
  sh "cd mruby && MRUBY_CONFIG=#{MRUBY_CONFIG} rake -m test:build && rake test:run"
end

task :clean do
  sh "cd mruby && rake deep_clean"
end

task :docker do
  sh "docker build -f  dockerfiles/develop -t dev ."
  sh "docker run --rm -v `pwd`:/opt/dev -w /opt/dev  -it dev /bin/bash"
end

task :default => :test
