#!/bin/bash

help="new-game.sh: \n
    A tool for duplicating min-love2d-fennel. \n\
\n\
usage: \n\
    ./new-game.sh [project-name] [opts]\n\
\n
opts:\n
  -o= (--output-directory=) Target parent directory. Defaults to PWD\n
  -l= (--layut=) Set the layout. Defaults to minimal layout.\n
  -f (--force) overwrite the target directory if it exists\n
  -h  (--help) Display this text\n
\n
eg: \n\
./new-game.sh sample-game -o=../ -f
"

name=$1
output_dir=$(pwd)
gethelp=false
location=$(dirname "$0")
force=false
layout="clone"

for i in "$@"
do
case $i in
    -o=*|--output-directory=*)
    output_dir="${i#*=}"
    ;;
    -l=*|--layout=*)
    layout="${i#*=}"
    ;;    
    -f|--force)
    force=true
    ;;    
    -h|--help)
    gethelp=true
    ;;
    *)
            # unknown option
    ;;
esac
done


if [ ! -d $output_dir ]; then
    echo "output directory not found!"
    echo $output_dir
    exit 1
fi

if [ ! -d $location/$layout ]; then
    echo "\"$layout\" layout not found!"
    echo "Valid built in layouts are:"
    echo "clone"
    echo "seperate-source"
    exit 1
fi

target_dir=$output_dir/$name

if [ -d $target_dir ]; then
    if [ $force = true ]; then
        echo "Overwriting $target_dir."
        rm -rf $target_dir
    else
        echo "target directory already exists! Use -f or --force to overwrite this directory."
        echo $target_dir
        exit 1
    fi    
fi

copy-dir (){
    mkdir $target_dir
    ./$location/$layout/update-layout.sh $target_dir
    rm -rf $location/.duplicate
    rm -rf $location/.git
}

if [ $gethelp = true ]; then
    echo -e $help
else
    copy-dir
fi
   
