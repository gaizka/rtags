require 'rubygems'

spec = Gem::Specification.new do |s|
	s.name = 'rtags'
	s.version = "0.92"
	s.platform = Gem::Platform::RUBY
	s.summary = "rtags is a Ruby replacement for ctags - allowing for name navigation in source code using vim, emacs and others"
	s.description = "This is the original commit of the rtags source code as written by Keiju ISHITSUKA as part of the irb project. Now irb has moved into the main Ruby source tree rtags has become an independent project" 

	# update VERSION
	`echo #{s.version} > bin/VERSION`

	# libraries
	s.files = Dir.glob(File.dirname(__FILE__) + "/../lib/*")

	# tests
	s.files = s.files + Dir.glob(File.dirname(__FILE__) + "/../test/*")
	s.test_file = File.dirname(__FILE__) + '/../test/runner.rb'
	
	# binaries
	s.files = s.files + Dir.glob(File.dirname(__FILE__) + "/../bin/*")
	s.bindir = 'bin'
	s.executables << 'rtags'
	
	s.required_ruby_version = '>= 1.8.1'
	s.autorequire = 'irb'
	# s.add_dependency( "irb", ">= 0.9" )
	s.author = "Pjotr Prins, Keiju Ishitsuka"
	s.email = "pjotr.public02@thebird.nl"
	s.rubyforge_project = "rtags"
	s.homepage = "http://rtags.rubyforge.org"
	s.has_rdoc = false
end

if $0==__FILE__
	Gem.manage_gems
	Gem::Builder.new(spec).build
end
