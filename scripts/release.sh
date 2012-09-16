#!/bin/sh

progname=rtags
tmpdir=/tmp
version=`cat bin/VERSION`
pkgname=$progname-$version
pkgdir=$tmpdir/$pkgname
cwd=`pwd`

if [ ! -d test ]; then echo "Run from base directory!" ; exit ; fi

echo -n "Release "
echo $version
cd test
ruby runner.rb
cd ..
echo "hit enter to continue"
read 

rm *.gem
rm *.tgz

# Make the gem
ruby ./scripts/rtags.gemspec

# Make the tgz
mkdir $pkgdir
cp -va bin test doc install.sh README TODO LICENSE.txt RELEASENOTES $pkgdir
cd $tmpdir
tar cvzf $pkgname.tgz --exclude *.svn* $pkgname/*
cd $cwd
cp $tmpdir/$pkgname.tgz .
