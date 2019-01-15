#!/bin/sh

DIR='build/doxyxml/'

for x in `ls ${DIR}`
do
   tidy -xml -o ${DIR}/$x ${DIR}/$x
done

