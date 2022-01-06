#!/bin/sh
. ./j
#rm Airdrop
#rm pre
#tsc -b
VERSION=$(cat version)
increment_version $VERSION > version
VERSION=$(cat version)
# pip3 freeze > requirements.txt
configVer
gitpush
