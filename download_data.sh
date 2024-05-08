#!/bin/bash

wget https://github.com/ES-DOC/esdoc-archive/archive/refs/heads/master.zip -O tmp/esdoc.zip
cd tmp
unzip esdoc.zip
cd esdoc-archive-master
source sh/activate
source sh/uncompress.sh
mv esdoc ../../data/
cd ..
cd ..
rm -rf tmp/esdoc-archive-master
rm -rf tmp/esdoc.zip