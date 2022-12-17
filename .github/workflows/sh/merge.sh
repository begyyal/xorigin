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
target=$2
event_path=$3
git_dir=$4
token=$5
repos=$6
head_refs="${git_dir}refs/heads/$target"
mst_head_refs="${git_dir}refs/heads/master"

$shjp "$event_path" -t commits | 
$shjp -t tree_id > ${tmp}target_trees
[ $? != 0 ] && end 1 || :  

first_tree=$(cat ${tmp}target_trees | head -n 1)
if [ -z "$first_tree" ]; then
  echo 'The target commits of the processing dont exist.' >&2
  end 1
fi

function main(){

  git rebase master
  [ $? != 0 ] && end 1 || :

  target_nr=$(git log --pretty=format:%T | awk '{if($1=="'$first_tree'"){print NR}}')
  if [ -z "$target_nr" ]; then
    echo 'The target commits of the processing dont exist in the target branch.' >&2
    echo 'Maybe the target branch is rollbacked because preceeded CI failed.' >&2
    end 1
  fi

  parent=$(git log --pretty=oneline |
  cut -d " " -f 1 |
  head -n $(($target_nr+1)) | 
  tac |
  tee ${tmp}targets_of_revision |
  head -n 1)

  from=$parent
  to=''
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

    target_flag=$(cat ${tmp}target_trees | grep ^$tree)
    if [ -n $target_flag ]; then
      comments=$(echo "$comments" | 
      awk -v prefix="${prefix} " '{if(NR==1 && $0 !~ /^('$prefix').*$/){print prefix $0}else{print}}')
    fi

    git commit-tree $tree -p $parent -m "$comments" > $head_refs
    git reset --hard HEAD
    git commit --amend --author="$author" -C HEAD --allow-empty
    parent=$(cat $head_refs)
    [ -n $target_flag ] && to=$parent || :
  done
  [ $? != 0 ] && end 1 || :
}

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

git push HEAD -f
[ $? != 0 ] && end 1 || :

git reset --hard $to
curl \
  -X POST \
  -H "AUTHORIZATION: token ${token}" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/${repos}/statuses/${to} \
  -d '{"state":"success","context":"ci-passed-ph2"}'
[ $? != 0 ] && end 1 || :

git checkout master
git merge $target
[ $? != 0 ] && end 1 || :
git push origin master
[ $? != 0 ] && end 1 || :

end 0
