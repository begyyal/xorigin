#!/bin/bash

tmp_dir='/tmp/'$(date +%Y%m%d%H%M%S)
mkdir -p $tmp_dir
tmp=${tmp_dir}'/'$$'_'
cmd_dir=`dirname $0`

function end(){
  rm -f ${tmp}*
  exit $1
}

twt_ext="#test"
repos=$(git remote get-url origin | sed -e 's/^.*://' -e 's/\.git//')
repos_name=${repos/*\///}
readme_path=${cmd_dir}/README.md
twt_temp_path=${cmd_dir}/.github/workflows/sh/tweet_template.sh

cp $readme_path ${tmp}readme_bk
sed 's/begyyal\/xorigin/'"${repos//\//\\\/}"'/g' ${tmp}readme_bk > $readme_path

cp $twt_temp_path ${tmp}twt_temp_bk
awk -f ${tmp}twt_temp_bk \
'{
    if($0 ~= ^repos_name=){print "repos_name='${repos_name}'"}
    else if($0 ~= ^ext=){print "ext='${twt_ext}'"}
    else{print $0}
}' > $twt_temp_path

find ${cmd_dir}/.github/workflows/sh/* |
git update-index --add -chmod=+x
git update-index --add -chmod=+x ${cmd_dir}/test.sh

git add . && git commit -m "init"
end 0
