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

prefix=$1
head_tree=$($shjp $2 -t head_commit.tree_id)

touch ${tmp}hits
git fetch
git branch -a | 
grep -E '^remotes/origin/'${prefix}'/[1-9][0-9]*$' |
while read b; do
    bc=$(git log $b --pretty=oneline | head -n 1 | cut -d ' ' -f 1)
    git cat-file -p $bc | 
    grep ^tree |
    grep "tree ${head_tree}" -oq && echo ${b#remotes/origin/} || : >> ${tmp}hits
done

count=$(cat ${tmp}hits | wc -l)
if [ $count = 0 ]; then
    end 0
elif [ $count -gt 1 ]; then
    echo 'Some branches prefixed are found, it must be one.' >&2
    cat ${tmp}hits >&2
    end 1
fi

cat ${tmp}hits | head -n 1
end 0
