#!/bin/bash
for i in $(find . -maxdepth 1 -type d) ; do 
    echo -n $i": " ; 
    ( find $i -type f | wc -l ) ; 
done
