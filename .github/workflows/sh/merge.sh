#!/bin/bash

tmp_dir='/tmp/'$(date +%Y%m%d%H%M%S)
mkdir -p $tmp_dir
tmp=${tmp_dir}'/'$$'_'

cmd_dir=`dirname $0`
shjp=${cmd_dir}/shjp

function end(){
  rm -f ${tmp}*
  exit $1
}

prefix="$1"
event_path=$2
git_dir=$3
repos=$4
head_refs="${git_dir}refs/heads/stg"
dev_head_refs="${git_dir}refs/heads/develop"

$shjp "$event_path" -t commits | 
$shjp -t tree_id > ${tmp}target_trees
[ $? != 0 ] && end 1 || :  

last_tree=$(cat ${tmp}target_trees | tail -n 1)
from=$parent
to=''
started=''

function main(){

  git rebase develop
  [ $? != 0 ] && end 1 || :

  git log --pretty="%T %H" | 
  awk '{if($1=="'$before'"){flag=1};if(flag!=1){print $0};}' |
  tac |
  while read tchash; do

    tree=$(echo "$tchash" | cut -d " " -f 1)
    commit=$(echo "$tchash" | cut -d " " -f 2)
    props=$(git cat-file -p $commit | awk '{if($0==""){flag=1}else if(flag!=1){print $0}}')
    author=$(echo "$props" | grep ^author | cut -d " " -f 2-)

    git cat-file -p $commit | awk '{if(flag==1){print $0}else if($0==""){flag=1}}' > ${tmp}comments
    if [ -z $started ]; then
      started=$(cat ${tmp}comments | awk '{if(NR==1 && $0 !~ /^('$prefix').*$/){print "1"}}')
      [ -z $started ] && continue || :
    fi

    target_flag=$(cat ${tmp}target_trees | grep ^$tree)
    if [ -n $target_flag ]; then
      cat ${tmp}comments > ${tmp}comments_cp
      cat ${tmp}comments_cp | 
      awk -v prefix="${prefix} " '{if(NR==1 && $0 !~ /^('$prefix').*$/){print prefix $0}else{print}}' > ${tmp}comments 
      if [ "$tree" == "$last_tree" -a "$(cat ${tmp}comments | tail -n 1)" != "[skip ci]" ]; then
        echo "[skip ci]" >> ${tmp}comments 
      fi
    fi

    git commit-tree $tree -p $parent -m "$(cat ${tmp}comments)" > $head_refs
    git reset --hard HEAD
    git commit --amend --author="$author" -C HEAD --allow-empty
    parent=$(cat $head_refs)
    [ -n $target_flag ] && to=$parent || :[ $? != 0 ] && end 1 || :
  done
}
[ $? != 0 ] && end 1 || :

function checkDiff(){
  git fetch
  diff -q ${tmp}head_refs_bk ${git_dir}refs/remotes/origin/$target 1>/dev/null && \
  diff -q ${tmp}mst_head_refs_bk ${git_dir}refs/remotes/origin/master 1>/dev/null
}

git checkout master # set upstream
git checkout $target

cp $head_refs ${tmp}head_refs_bk
cp $mst_head_refs ${tmp}mst_head_refs_bk
main
while ! checkDiff ; do
  git checkout master
  git branch -D $target
  git checkout $target
  cp $head_refs ${tmp}head_refs_bk
  cp $mst_head_refs ${tmp}mst_head_refs_bk
  main
done
[ $? != 0 ] && end 1 || :

git push origin HEAD -f
[ $? != 0 ] && end 1 || :

git reset --hard $to
git checkout master
git merge develop
[ $? != 0 ] && end 1 || :
git push origin master
[ $? != 0 ] && end 1 || :

end 0
