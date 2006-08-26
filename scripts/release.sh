#!/bin/sh

if [ ! -d test ]; then echo "Run from base directory!" ; exit ; fi

ruby ./scripts/rtags.gemspec

version=`cat ./bin/VERSION`
tar cvzf rtags-$version.tgz --exclude *.svn* bin/* test/* doc/* install.sh README TODO LICENSE.txt  RELEASENOTES

