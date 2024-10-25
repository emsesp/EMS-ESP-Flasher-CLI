#!/bin/sh

# See README.md for more information
#
# make sure GitHub CLI is installed and authorized
# See https://cli.github.com/manual/installation
#

cd firmware

rm -f *.bin *.md5 *.md

# for dev versions:
gh release download latest -R emsesp/EMS-ESP32 --clobber

# for stable versions:
gh release download -p "*" -R emsesp/EMS-ESP32 --clobber

# don't need the changelog or the .md5 files
rm -f *.md*

cd ..
