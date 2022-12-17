#!/bin/bash

tmp_dir='/tmp/act_'$(date +%Y%m%d%H%M%S)
mkdir -p $tmp_dir
tmp=${tmp_dir}'/'$$'_'

cmd_dir=`dirname $0`
shjp=${cmd_dir}/shjp

function end(){
  rm -f ${tmp}*
  exit $1
}

prefix="$1"
target=$2
event_path=$3

$shjp "$event_path" -t commits | 
$shjp -t id > ${tmp}target_commits
[ $? != 0 ] && end 1 || :

first_commit=$(cat ${tmp}target_commits | head -n 1)
if [ -z "$first_commit" ]; then
  echo 'The target commits of the processing dont exist.'
  end 0
fi

target_nr=$(git log --pretty=oneline | awk '{if($1=="'$first_commit'"){print NR}}')
if [ -z "$target_nr" ]; then
  echo 'The target commits of the processing dont exist in the target branch.'
  end 0
fi

parent=$(git log --pretty=oneline |
cut -d " " -f 1 |
head -n $(($target_nr+1)) | 
tac |
tee ${tmp}targets_of_revision |
head -n 1)

head_ref="./.git/refs/heads/$target"
started=''

cat ${tmp}targets_of_revision |
sed '1d' |
while read commit_hash; do

  props=$(git cat-file -p $commit_hash | awk '{if($0==""){flag=1}else if(flag!=1){print $0}}')
  tree=$(echo "$props" | grep ^tree | cut -d " " -f 2)
  author=$(echo "$props" | grep ^author | cut -d " " -f 2-)

  comments=$(git cat-file -p $commit_hash | awk '{if(flag==1){print $0}else if($0==""){flag=1}}')
  if [ -z $started ]; then
    started=$(echo "$comments" | awk '{if(NR==1 && $0 !~ /^('$prefix').*$/){print "1"}}')
    [ -z $started ] && continue || :
  fi

  target_flag=$(cat ${tmp}target_commits | grep ^$commit_hash)
  if [ -n $target_flag ]; then
    comments=$(echo "$comments" | 
    awk -v prefix="${prefix} " '{if(NR==1 && $0 !~ /^('$prefix').*$/){print prefix $0}else{print}}')
  fi

  git commit-tree $tree -p $parent -m "$comments" > $head_ref
  git reset --hard HEAD
  git commit --amend --author="$author" -C HEAD --allow-empty
  parent=$(cat $head_ref)
done

if [ $? != 0 ]; then
  echo 'Error occurred.'
  end 1
fi

end 0
