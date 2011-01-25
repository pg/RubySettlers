#!/bin/bash
echo 
echo Updating ri documentation ...
rdoc -f ri -S -x ../lib/ui/ -x ../rubyscript2exe.rb -x tests/ -o ../doc/ri -i ..
echo 
echo Updating html documentation ...
rdoc -f html -S -x ../lib/ui/ -x ../rubyscript2exe.rb -x tests/ -o ../doc/html -i ..