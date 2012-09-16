# -*- encoding: utf-8 -*-
Kernel.load File.expand_path('../lib/rtags/version.rb', __FILE__)

Gem::Specification.new do |s|
	s.name = 'rtags'
	s.version = Rtags::VERSION
	s.platform = Gem::Platform::RUBY
	s.summary = "rtags is a Ruby replacement for ctags - allowing for name navigation in source code using vim, emacs and others"
	s.description = "This is the original commit of the rtags source code as written by Keiju ISHITSUKA as part of the irb project. Now irb has moved into the main Ruby source tree rtags has become an independent project" 

	s.files = [
	  'RELEASENOTES','TODO','README','LICENSE.txt'
	]
	# libraries
	s.files = s.files + Dir.glob(File.dirname(__FILE__) + "/../lib/*")

	# tests
#	s.files = s.files + Dir.glob(File.dirname(__FILE__) + "/../test/*")
#	s.files = s.files + Dir.glob(File.dirname(__FILE__) + "/../test/data/*")
#	s.files = s.files + Dir.glob(File.dirname(__FILE__) + "/../test/regression/*")
#	s.test_file = File.dirname(__FILE__) + '/../test/runner.rb'
	
	# binaries
	s.files = s.files + Dir.glob(File.dirname(__FILE__) + "/../bin/*")
	s.bindir = 'bin'
	s.executable = 'rtags'
	
	s.required_ruby_version = '>= 1.8.1'
	s.autorequire = 'irb'
	# s.add_dependency( "irb", ">= 0.9" )
	s.author = "Pjotr Prins, Keiju Ishitsuka"
	s.email = "pjotr.public02@thebird.nl"
	s.rubyforge_project = "rtags"
	s.homepage = "http://rtags.rubyforge.org"
	s.has_rdoc = false
end
