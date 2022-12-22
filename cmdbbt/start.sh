#!/bin/bash

cmd_dir=`dirname $0`

function generateTmpPath(){
    tmp_id="-1"
    for id in $(ls -1 $tmp_dir | grep $timestamp | cut -d _ -f 2); do
        [[ "$id" =~ ^[0-9]+$ ]] || continue
        [ "$tmp_id" -lt $id ] && tmp_id=$id || :
    done
    tmp=${tmp_dir}${timestamp}'_'$(($tmp_id+1))'/'
}

function setupTmp(){
    tmp_dir=$cmd_dir'/tmp/'
    mkdir -p $tmp_dir
    timestamp=$(date +%Y%m%d%H%M%S)
    generateTmpPath
    while ! mkdir $tmp 2>/dev/null; do
        generateTmpPath
    done
}

function rmExpired(){
    ts_sec=$(date +%s)
    expired_sec=$(($ts_sec-60*60))
    expired_date=$(date --date=@$expired_sec +%Y%m%d%H%M%S)
    for d in `ls $tmp_dir`; do
        d_date=${d:0:14}
        if [[ $d_date =~ ^[0-9]+$ ]]; then
            [ $d_date -lt $expired_date ] && rm -rdf ${tmp_dir}${d} || :
        fi
    done
}

setupTmp
rmExpired

function processShortOpt(){
    opt=$1
    for i in `seq 2 ${#opt}`; do
        char=${opt:(($i-1)):1}
        if [ "a$char" = ao ]; then
            opt_flag=$(($opt_flag|1))
        else
            echo "The specified option as $char is invalid." >&2
            exit 1
        fi
    done    
}

function processOpt(){
    for arg in "$@"; do
        if [[ ! "$arg" =~ ^-.+ ]]; then
            if [ "$argext_flag" = 1 ]; then
                apts=$arg
            elif [ -z "$def_path" ]; then
                def_path=$arg
            fi
            argext_flag=''
        elif [ "$arg" = --omit-filedef ]; then
            opt_flag=$(($opt_flag|1))
        elif [ "$arg" = --apt-get ]; then
            argext_flag=1
        else
            processShortOpt "$arg"
        fi
    done
}

processOpt "$@"

def_path=${def_path:-./bbtdef.json}
if [ ! -f "$def_path" ]; then
    echo "Definition file is not found." >&2
    exit 1
fi

shjp=${cmd_dir}/app/src/sh/shjp.sh
$shjp $def_path > ${tmp}def_comp
$shjp -g ${tmp}def_comp operations > ${tmp}def_operations

mkdir -p ${tmp}env/
mkdir -p ${tmp}resource/

cat $def_path |
grep -v "^\s*$" |
if [ -z "$opt_flag" ]; then 
    cat
else
    awk '{print}END{
        match($0,/^.*}/); 
        base=substr($0,0,RLENGTH-1)
        print base ",\"opt_flag\":'$opt_flag'}"
    }' 
fi > ${tmp}bbtdef.json

for n in `$shjp -g ${tmp}def_comp need`; do
    cp -r ./$n ${tmp}env/
done

rsc_path_def="./$($shjp -g ${tmp}def_comp resource)" 
for n in `ls $rsc_path_def`; do
    cp -r ${rsc_path_def}${n} ${tmp}resource/
done

doc_name=$(pwd | md5sum | cut -d " " -f 1)_cmdbbt
docker build \
    -t $doc_name \
    --build-arg apts="${apts//,/ }" \
    $cmd_dir 2>${tmp}build_err
exit_code=$?
if [ $exit_code != 0 ]; then
    cat ${tmp}build_err >&2
    rm -rdf ${tmp}
    exit $exit_code
fi

run_args="\
    --rm \
    --name $doc_name \
    -v `realpath $tmp`:/mnt/main \
    $doc_name"
os_name=$(uname)
if [[ ${os_name,,} =~ ^(mingw).* ]]; then
    MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL="*" docker run $run_args
else
    docker run $run_args
fi
exit_code=$?

rm -rdf ${tmp}
exit $exit_code
