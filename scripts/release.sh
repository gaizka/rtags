#!/bin/sh

if [ ! -d test ]; then echo "Run from base directory!" ; exit ; fi

ruby ./scripts/rtags.gemspec
