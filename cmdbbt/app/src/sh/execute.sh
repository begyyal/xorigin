#!/bin/bash

readonly CAUSE=(
    "exit-code"
    "console-output"
    "file-output"
    "file-update"
    "file-delete"
) 

function printStacktrace() {
    index=1
    while frame=($(caller "${index}")); do
        ((index++))
        echo "at function ${frame[1]} (${frame[2]}:${frame[0]})" >&2
    done
}

function checkErr(){
    if [ $? != 0 ]; then
        printStacktrace
        exit -1
    fi
}

shjp=/cmdbbt/lib/sh/shjp.sh

path_mnt=$1 && shift
path_def=$1 && shift
path_resource=$1 && shift
path_env=$1 && shift
idx=$1 && shift
name=$1 && shift

tmp="/tmp/$name/"
result="/result/$name/"
mkdir -p $tmp
mkdir -p $result

cat ${path_mnt}def_operations | 
awk 'NR=='$idx |
$shjp > ${tmp}ope_comp
checkErr
shift

opt_flag=${1:-0}
ofd_flag=$(($opt_flag&1))

$shjp -g ${tmp}ope_comp "command" > ${tmp}command
checkErr
path_resource=${path_resource}${name}/input/
path_work=/work/${name}/
mkdir -p $path_work

for n in `ls $path_env`; do
    cp -r ${path_env}${n} $path_work
done
if [ -d $path_resource ]; then
    for n in `ls $path_resource`; do
        cp -r ${path_resource}${n} $path_work
    done
fi

cd $path_work
co_count=$(cat ${tmp}command | wc -l)
for i in `seq 1 $co_count`; do
    co="$(cat ${tmp}command | awk 'NR=='$i)"
    eval "$co" >>${tmp}co_result 2>/dev/null
    act_code=$?
    [ $act_code != 0 ] && break || :
done

exp_code="$($shjp -g ${tmp}ope_comp exitCode)"
if [ $act_code != $exp_code ]; then
    echo ${CAUSE[0]} > ${result}failure
    echo $act_code > ${result}actual
    exit 0
fi

$shjp -g ${tmp}ope_comp expected |
while read check; do

    $shjp "$check" > ${tmp}check_comp
    act="$($shjp -g ${tmp}check_comp act)"
    $shjp -g ${tmp}check_comp value > ${tmp}expected_v

    if [ $act = console-output ]; then
        diff -q ${tmp}expected_v ${tmp}co_result >/dev/null 2>/dev/null
        if [ $? != 0 ]; then
            printf ${CAUSE[1]} > ${result}failure
            cat ${tmp}co_result > ${result}actual
            exit 1
        fi
    elif [ $ofd_flag = 1 ]; then
        continue
    fi
    
    value=$(cat ${tmp}expected_v)
    if [ $act = file-output ]; then
        diff -rq ${path_work}
    elif [ $act = file-update ]; then
        :
    elif [ $act = file-delete ]; then
        :
    fi
done

exit 0
