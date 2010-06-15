require 'rubygems'
require 'rake/gempackagetask'
require 'lib/resat'

GEM      = 'resat'
GEM_VER  = Resat::VERSION
AUTHOR   = 'Raphael Simon'
EMAIL    = 'raphael@rightscale.com'
HOMEPAGE = 'http://github.com/raphael/resat'
SUMMARY  = 'Web scripting for the masses'

spec = Gem::Specification.new do |s| 
  s.name             = GEM
  s.version          = GEM_VER
  s.author           = AUTHOR
  s.email            = EMAIL
  s.platform         = Gem::Platform::RUBY
  s.summary          = SUMMARY
  s.description      = SUMMARY
  s.homepage         = HOMEPAGE
  s.files            = %w(LICENSE README.rdoc Rakefile) + FileList["{bin,lib,schemas,examples}/**/*"].to_a
  s.executables      = ['resat']
  s.extra_rdoc_files = ["README.rdoc", "LICENSE"]
  s.add_dependency("kwalify", ">= 0.7.1")
end

Rake::GemPackageTask.new(spec) do |pkg|
  pkg.gem_spec = spec
end

task :install => [:package] do
  sh %{sudo gem install pkg/#{GEM}-#{GEM_VER}}
end

