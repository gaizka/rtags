#!/usr/bin/env ruby
#
#		rtags is a Ruby replacement for ctags - allowing for name navigation in
#		source code using vim, emacs and others.
#
#		Install using the install.sh script.
#
#   LICENSE: RUBY LICENSE - see LICENSE.TXT
#
#		THIS IS THE ORIGINAL CHECK-IN BASED ON THE LATEST VERSION RECEIVED FROM:
#
#     Release Version: 0.91 - public release using irb 0.9
#     
#   rtags.rb - 
#   	Release Version: 0.9
#   	Revision: 1.13 
#   	Date: 2002/07/09 10:26:38 
#   	by Keiju ISHITSUKA(Nippon Rational Inc.)
#
# --
#
#   
#

RTAGS_VERSION='0.91 (July 2006)'

usage = <<USAGE

	rtags #{RTAGS_VERSION} (Ruby tags) by Keiju ISHITSUKA:
	
	A Ruby tool for using Ruby tags with vim or emacs
	http://rubyforge.org/projects/rtags/ - maintainer Pjotr Prins

	usage:

		rtags [--vi] filenames

	by default creates an emacs tags file. With the --vi switch
	a vim tags file is created instead.

USAGE

require "e2mmap"
require "tracer"

require "irb/ruby-lex"
require "irb/ruby-token"

$DEBUG = true
#$TOKEN_DEBUG = true

module RTAGS
  @RCS_ID='-$Id: rtags.rb,v 1.13 2002/07/09 10:26:38 keiju Exp keiju $-'

  class RTToken
    def initialize(readed, context, name, token)
      @readed = readed
      @context = context
      @name = name
      @token = token
    end
    attr :readed
    attr :context
    attr :name
    attr :token

    def line_no
      @token.line_no
    end

    def seek
      @token.seek
    end

    def to_s
      "#{def_name} #{abs_name} in #{token.inspect}"
    end
  end

  class RTModule < RTToken
    def abs_name
      (context || "") + "::" + name
    end
    
    def def_name
      "module"
    end
  end

  class RTClass < RTModule
    def abs_name
      (context || "") + "::" + name
    end

    def def_name
      "class"
    end
  end

  class RTSingleClass < RTClass
    def abs_name
      (context || "") + "<<" + name
    end

    def def_name
      "class"
    end
  end

  class RTMethod < RTToken
    def abs_name
      (context || "") + "#" + name
    end

    def def_name
      "def"
    end
  end
  class RTAlias < RTMethod
    def def_name
      "alias"
    end
  end
  class RTAttr < RTMethod
    def def_name
      "attr"
    end
  end

  class RTSingleMethod < RTToken
    def abs_name
      (context || "") + "." + name
    end

    def def_name
      "def"
    end
  end
  class RTSingleAlias < RTSingleMethod
    def def_name
      "alias"
    end
  end
  class RTSingleAttr < RTSingleMethod
    def def_name
      "attr"
    end
  end
  
  class Parser
    include RubyToken

    def initialize(file_name)
      @size = 0
      @input_file_name = file_name
      @scanner = RubyLex.new
      @scanner.exception_on_syntax_error = false
      # @scanner.skip_space = true
      # @scanner.readed_auto_clean_up = true
      #parse_statements
    end

    def scan(&block)
      File.open(@input_file_name) do
	|input|
	@tokens = []
	@unget_readed = []
	@readed = []
	@scanner.set_input(input)
	parse_statements(&block)
      end
    end

    def get_tk
      if @tokens.empty?
	tk = @scanner.token
	@readed.push @scanner.get_readed
	p tk if $TOKEN_DEBUG
	tk
      else
	@readed.push @unget_readed.shift
	tk = @tokens.shift
	p tk if $TOKEN_DEBUG
	tk
      end
    end

    def peek_tk
      unget_tk(tk = get_tk)
      tk
    end

    def unget_tk(tk)
      @tokens.unshift tk
      @unget_readed.unshift @readed.pop
    end

    def skip_tkspace(skip_nl = true)
      tokens = []
      while ((tk = get_tk).kind_of?(TkSPACE) ||
	     (skip_nl && tk.kind_of?(TkNL)))
	tokens.push tk
      end
      unget_tk(tk)
      tokens
    end

    def get_tkreaded
      readed = @readed.join("")
      @readed = []
      readed
    end

    NORMAL = "::"
    SINGLE = "<<"

    def parse_statements(context = nil, single = NORMAL, &block)
      nest = 1

      while tk = get_tk
	case tk
	when TkCLASS
	  parse_class(context, single, tk, &block)
	when TkMODULE
	  parse_module(context, single, tk, &block)
	when TkDEF
	  nest += 1
	  parse_method(context, single, tk, &block)
	when TkALIAS
	  parse_alias(context, single, tk, &block)
	when TkCASE,
	    TkDO,
	    TkFOR,
	    TkIF,
	    TkUNLESS,
	    TkUNTIL,
	    TkWHILE, 
	    TkBEGIN
	  nest += 1
	when TkIDENTIFIER
	  case tk.name
	  when "attr"
	    parse_attr(context, single, tk, &block)
	  when /^attr_(reader|writer|accessor)$/
	    parse_attr_accessor(context, single, tk, &block)
	  end
	when TkEND
	  return if (nest -= 1) == 0
	end
	begin
	  get_tkreaded
	  skip_tkspace(false)
	end while peek_tk == TkNL
      end
    end

    def parse_class(context, single, tk, &block)
      skip_tkspace
      case name_t = get_tk
      when TkCONSTANT
	name = name_t.name
	if single == SINGLE
	  yield RTSingleClass.new(get_tkreaded, context, name, tk)
	else
	  yield RTClass.new(get_tkreaded, context, name, tk)
	end
	parse_statements((context || "") + single + name, &block)

      when TkLSHFT
	skip_tkspace
	case name_t2 = get_tk
	when TkSELF
	  parse_statements(context, SINGLE, &block)
	when TkCONSTANT
#	  yield RTSingleClass.new(get_tkreaded, context, name_t2.name, tk)
	  parse_statements((context || "") + "::" + name_t2.name, 
			   SINGLE, 
			   &block)
	else
	  printf "Warn: I don't recognize this token(%s)", name_t2.inspect
#	  break
	end
      else
	printf "Warn: I don't recognize this token(%s)", name_t2.inspect
#	break
      end
    end

    def parse_module(context, single, tk, &block)
      skip_tkspace
      name = get_tk.name
      yield RTModule.new(get_tkreaded, context, name, tk)
      parse_statements((context||"") + single + name, &block)
    end

    def parse_method(context, single, tk, &block)
      skip_tkspace
      name_t = get_tk
      back_tk = skip_tkspace

      if (dot = get_tk).kind_of?(TkDOT)
	# tricky tech.
	@scanner.instance_eval{@lex_state = EXPR_FNAME}
	skip_tkspace
	name_t2 = get_tk
	case name_t
	when TkSELF
	  name = name_t2.name
	when TkId
	  if context and 
	      context =~ /^#{name_t.name}$/ || context =~ /::#{name_t.name}$/
	    name = name_t2.name
	  else
	    context = (context || "") + "::" + name_t.name
	    name = name_t2.name
	  end
	else
	  printf "Warn: I don't recognize this token(%s).", name_t2.inspect
	  break
	end
	yield RTSingleMethod.new(get_tkreaded, context, name, tk)

      else
	unget_tk dot
	back_tk.reverse_each do
	  |tk|
	  unget_tk tk
	end
	name = name_t.name
	if single == SINGLE
	  yield RTSingleMethod.new(get_tkreaded, context, name, tk)
	else
	  yield RTMethod.new(get_tkreaded, context, name, tk)
	end
      end
    end

    def parse_alias(context, single, tk, &block)
      skip_tkspace
      name = get_tk.name
      if context
	if single == SINGLE
	  yield RTSingleAlias.new(get_tkreaded, context, name, tk)
	else
	  yield RTAlias.new(get_tkreaded, context, name, tk)
	end
      else
	if single == SINGLE
	  yield RTSingleAlias.new(get_tkreaded, "main", name, tk)
	else
	  yield RTAlias.new(get_tkreaded, nil, name, tk)
	end
      end
    end

    def parse_attr(context, single, tk, &block)
      args = parse_symbol_arg(1)
      if args.size > 0
	name = args[0]
	if context
	  if single == SINGLE
	    yield RTSingleAttr.new(get_tkreaded, context, name, tk)
	  else
	    yield RTAttr.new(get_tkreaded, context, name, tk)
	  end
	else
	  if single == SINGLE
	    yield RTSingleAttr.new(get_tkreaded, "main", name, tk)
	  else
	    yield RTAttr.new(get_tkreaded, nil, name, tk)
	  end
	end
      else
	printf "Warn: I don't recognize a token next attr arg size == zero\n"
      end    
    end

    def parse_attr_accessor(context, single, tk, &block)
      args = parse_symbol_arg
      readed = get_tkreaded
      for name in args
	if context
	  if single == SINGLE
	    yield RTSingleAttr.new(readed, context, name, tk)
	  else
	    yield RTAttr.new(readed, context, name, tk)
	  end
	else
	  if single == SINGLE
	    yield RTSingleAttr.new(readed, "main", name, tk)
	  else
	    yield RTAttr.new(readed, nil, name, tk)
	  end
	end
      end    
    end

    def parse_symbol_arg(no = nil)
      args = []
      skip_tkspace
      case tk = get_tk
      when TkLPAREN
	loop do
	  skip_tkspace
	  if tk1 = parse_symbol_in_arg
	    args.push tk1
	    break if no and args.size >= no
	  end

	  skip_tkspace
	  case tk2 = get_tk
	  when TkRPAREN
	    break
	  when TkCOMMA
	  else
	    printf "Warn: I don't recognize a token in funargs(%s)\n", tk.inspect
	    break
	  end
	end
      else
	unget_tk tk
	if tk = parse_symbol_in_arg
	  args.push tk
	  return args if no and args.size >= no
	end

	loop do
	  skip_tkspace(false)
	  case tk1 = get_tk
	  when TkCOMMA
	  when TkNL
	    unget_tk tk1
	    break
	  else
	    printf "Warn: I don't recognize a token in funargs(%s)\n", tk1.inspect
	    break
	  end
	  skip_tkspace
	  if tk = parse_symbol_in_arg
	    args.push tk
	    break if no and args.size >= no
	  end
	end
      end
      args
    end

    def parse_symbol_in_arg
      case tk = get_tk
      when TkSYMBEG
	case tk = get_tk
	when TkCONSTANT, 
	    TkIDENTIFIER,
	    TkFID
	  tk.name
	else
	  printf "Warn: I don't recognize a token next SYMBEG(%s)\n", tk.inspect
	  nil
	end
      when TkSTRING
	eval @readed[-1]
      else
	printf "Warn: I don't recognize a token not SYMBEG and STRING(%s)\n", tk.inspect if $DEBUG
	nil
      end
    end
  end

  class TAGS
    def initialize(files)
      @files = files
    end
  end

  class EMACS_TAGS < TAGS
    def shipout
      open("TAGS", "w") do
	|@output|

	for fn in @files
	  output = []
	  size = 0

	  printf "--\n-- parse file: %s\n", fn if $DEBUG
	  parser = Parser.new(fn)
	  parser.scan do
	    |tk|
	    print tk, "\n" if $DEBUG
	    item = sprintf("%s\C-?%s\C-A%d,%s\n",
			   tk.readed,
			   tk.abs_name,
			   tk.line_no,
			   tk.seek)
	    output.push item
	    size += item.size
	  end
	  @output.print "\C-L\n#{fn},#{size}\n"
	  @output.print output.join
	end
      end
    end
  end

  class VI_TAGS < TAGS
    def shipout
      output = []
      for fn in @files
	printf "--\n-- parse file: %s\n", fn if $DEBUG
	parser = Parser.new(fn) 
	parser.scan do
	  |tk|
	  print tk, "\n" if $DEBUG
	  output.push sprintf("%s\t%s\t/^%s/\n",
				tk.name,
				fn,
				tk.readed)
	  output.push sprintf("%s\t%s\t/^%s/\n",
				tk.abs_name,
				fn,
				tk.readed)
	
	end
      end
      open("tags", "w") do
	|out|
	out << output.sort!
      end
    end
  end
end

if ARGV.size == 0 or ARGV[0] == '--help'
	ARGV.shift
	print usage
	exit 1
end

if /--?vi/ =~ ARGV[0]
  ARGV.shift
  tags = RTAGS::VI_TAGS.new(ARGV)
else
  tags = RTAGS::EMACS_TAGS.new(ARGV)
end
tags.shipout


