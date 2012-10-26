$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)

#require 'rake'
require "bundler/gem_tasks"
require 'rspec/core/rake_task'
#require 'rdoc/task'
require "cpn/version"

#task :default => :install
task :default => :spec
task :test => :spec

desc "Run all specs"
RSpec::Core::RakeTask.new("spec") do |t|
  t.rspec_opts = ["-c"]
end

task :check_commited do
  status = %x{git status}
  fail("Can't release gem unless everything is committed") unless status =~ /nothing to commit \(working directory clean\)|nothing added to commit but untracked files present/
end

desc "Clean all, delete all files that are not in git"
task :clean_all do
  system "git clean -df"
end

desc "Create the CPN gem"
task :build do
  system "gem build cpn.gemspec"
end

desc "Release gem to gemcutter"
task :release => [:check_commited, :build] do
  system "gem push cpn-#{CPN::VERSION}-java.gem"
end

#desc "Generate documentation for cpn.rb"
#RDoc::Task.new do |rdoc|
#  rdoc.rdoc_dir = 'doc/rdoc'
#  rdoc.title = "cpn.rb #{CPN::VERSION}"
#  rdoc.options << '--webcvs=http://github.com/amanzitel/cpn/tree/master/'
##  rdoc.options << '-f' << 'horo'
#  rdoc.options << '-c' << 'utf-8'
#  rdoc.options << '-m' << 'README.rdoc'
#  rdoc.rdoc_files.include('README.rdoc')
#  rdoc.rdoc_files.include('lib/**/*.rb')
#end

#require 'rake/testtask'
#Rake::TestTask.new(:test_generators) do |test|
#  test.libs << 'lib' << 'test'
#  test.pattern = 'test/**/*_test.rb'
#  test.verbose = true
#end

