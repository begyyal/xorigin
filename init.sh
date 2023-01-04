#!/bin/bash

tmp_dir='/tmp/'$(date +%Y%m%d%H%M%S)
mkdir -p $tmp_dir
tmp=${tmp_dir}'/'$$'_'
cmd_dir=`dirname $0`

function end(){
  rm -f ${tmp}*
  [ "$1" != 0 ] && git reset --hard HEAD || :
  exit $1
}

twt_ext="#test"
repos=$(git remote get-url origin | sed -e 's/^.*://' -e 's/\.git//')
repos_name=${repos/*\///}
readme_path=${cmd_dir}/README.md
twt_temp_path=${cmd_dir}/.github/workflows/sh/tweet_template.sh

cp $readme_path ${tmp}readme_bk
sed 's/begyyal\/xorigin/'"${repos//\//\\\/}"'/g' ${tmp}readme_bk > $readme_path
[ $? != 0 ] && end 1 || : 

cp $twt_temp_path ${tmp}twt_temp_bk
sed -e "s/\x27/\\\'/g" ${tmp}twt_temp_bk | 
awk '{
    if($0 ~ /^repos_name=/){print "repos_name='${repos_name}'"}
    else if($0 ~ /^ext=/){print "ext=\"'${twt_ext}'\""}
    else{print $0}
}' |
sed -e "s/\x5c\x5c\x27/'/g" > $twt_temp_path
[ $? != 0 ] && end 1 || : 

find ${cmd_dir}/.github/workflows/sh/* |
git update-index --add --chmod=+x
[ $? != 0 ] && end 1 || : 
git update-index --add --chmod=+x ${cmd_dir}/test.sh
[ $? != 0 ] && end 1 || : 

git add . && git commit -m "init [skip ci]"
if [ "$(git branch | wc -l)" == 1 ]; then
  git checkout -b dev
  git checkout -b stg
  git checkout mst
  git push origin dev stg -f
fi
git push origin HEAD
end 0
