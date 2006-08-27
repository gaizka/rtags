#!/bin/sh

if [ ! -d test ]; then echo "Run from base directory!" ; exit ; fi

echo -n "Release "
cat bin/VERSION
cd test
ruby runner.rb
cd ..
echo "hit enter to continue"
read 

rm *.gem
rm *.tgz

ruby ./scripts/rtags.gemspec

version=`cat ./bin/VERSION`
tar cvzf rtags-$version.tgz --exclude *.svn* bin/* test/* doc/* install.sh README TODO LICENSE.txt  RELEASENOTES

