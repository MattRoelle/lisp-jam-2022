target=$1
location=$(dirname "$0")
cp -rf $location/../../* $target
cp -rf $location/overwrite/* $target
mv $target/sample-macros.fnl $target/src/
rm -rf $target/*fnl
mv -f $target/src/sample-macros.fnl $target
