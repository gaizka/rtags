#!/bin/bash
#
# Installation script for rtags (works on Unix) - requires ruby and
# irb.
# 
# Usage: install.sh [prefix]
# 

function fail()
{
  echo $1
	echo "INSTALLATION FAILED!"
	exit 1
}

###############################################################################
#
# CONFIG SECTION - EDIT TO SUIT YOUR SITE 
#
###############################################################################
#
# prefix : everything will be installed under this
#
  prefix="$1"
	if [ "$prefix" == "" ] ; then prefix='/usr/local' ; fi

#
# sudo : set to 'sudo' if you will need sudo to install into prefix
#
  sudo=""
  #sudo="sudo"
#
# libdir : libs will installed here
#
  libdir="${prefix}/lib"
#
# bindir : executables and scripts will installed here
#
  bindir="${prefix}/bin"
#
# full path of dir containing packages to be installed
#
  packagedir="`pwd`/packages"
#
# full path of dir where packages will be built 
#
  builddir="`pwd`/build"

###############################################################################
#
# END OF CONFIG SECTION - do not edit below
#
###############################################################################

# listing of all packages to install into $prefix
#
# info 
#
  printf "\n$div\n"
  printf "CONFIG\n"
  printf -- "$line\n"
  printf "prefix <$prefix>\n"
  printf "libdir <$libdir>\n"
  printf "bindir <$bindir>\n"
  # printf "packagedir <$packagedir>\n"
  # printf "builddir <$builddir>\n"
  printf -- "$line\n"
#
# important env settings for proper compilation
#
  export PATH="${bindir}:$PATH"
  export LD_RUN_PATH="${libdir}"
  export LD_LIBRARY_PATH="${libdir}"
#
# important aliases for proper complilation and installation
#
  make="env LD_RUN_PATH=${libdir} LD_LIBRARY_PATH=${libdir} make"
  ruby=`which ruby`
	irb=`which irb`
	rtags='./bin/rtags'
#
# Test dependencies
#

if [ -z $ruby ]; then
	fail "The Ruby interpreter can not be found. Please install Ruby first."
fi

if [ -z $irb ]; then
	fail "The irb (interactive Ruby) interpreter can not be found. Please install irb first."
fi

if [ ! -f $rtags ] ; then
  fail "Run this script from the root of the unpacked rtags package"
fi

target=$bindir/rtags
if [ -f $target ] ; then
  fail "$target already exists, please remove first!"
fi

cp $rtags $target
chmod a+x $target
echo "rtags installed as $target. Try $target --help"

exit 0


