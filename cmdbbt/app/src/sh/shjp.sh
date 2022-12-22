#!/bin/bash

# This software is released under the MIT License

# Copyright (c) 2021 begyyal

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

if [ "$1" = -g ]; then
    flg_get=1
    shift
fi
if [ -p /dev/stdin ]; then
    input="$(cat)"
    if [ -z "$input" ]; then
        input=$1
        shift
    fi
else
    input=$1
    shift
fi

if [ -z "$input" ]; then
    echo "Input value is empty." >&2
    exit 1
fi

function generateTmpPath(){
    tmp_id="-1"
    for id in $(ls -1 $tmp_dir | grep $timestamp | cut -d _ -f 2); do
        [[ "$id" =~ ^[0-9]+$ ]] || continue
        [ "$tmp_id" -lt $id ] && tmp_id=$id || :
    done
    tmp=${tmp_dir}${timestamp}'_'$(($tmp_id+1))'/'
}

function setupTmp(){
    tmp_dir='/tmp/shjp/'
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

function end(){
    rm -rdf ${tmp}
    exit $1
}

function extractValue(){

    if [ ${#targets[@]} -eq 0 ]; then
        echo "Arguments lack." >&2
        end 1
    elif [ ! -f $input ]; then
        echo '-g option requires a file path as first argument.' >&2
        end 1
    fi

    for target in ${targets[@]}; do
        cat $input |
        awk '{
            if(keySeq=="1"){
                if($0 ~ /^4.*$/){
                    print substr($0,2)
                    exit 0
                }else{
                    exit 1
                }
            }else if(keySeq=="2"){
                if($0 ~ /^4.*$/){
                    print substr($0,2)
                }else if($0 ~ /^2('${target//\\/\\\\}').*$/){
                    end=1
                    exit 0
                }else{
                    end=1
                    exit 1
                }
            }
            if($0 ~ /^[1-3]('${target//\\/\\\\}')$/){
                keySeq=substr($0,1,1)
                if(keySeq=="3")
                    exit 2
            }
        }END{
            if(!keySeq){
                print "'${target//\\/\\\\}'" > "'${tmp}missed_target'"
                exit 3
            }else if(keySeq=="2" && !end){
                exit 1
            }
        }'      
    done > ${tmp}answer
    exit_code=$?
    if [ $exit_code -eq 1 ]; then
        echo "This compiled file has invalid format." >&2
        end 1
    elif [ $exit_code -eq 2 ]; then
        echo 'Object type can'\''t be applicable for a target in compile mode.' >&2
        echo 'Please specify value of literal or array, or use function of the directly get.' >&2
        end 1
    elif [ $exit_code -eq 3 ]; then
        echo 'The target ['$(cat ${tmp}missed_target)'] is not found.' >&2
        end 1
    fi

    cat ${tmp}answer
}

declare -a targets
while [ -n "$1" ]; do
    targets+=($1)
    shift
done

if [ -n "$flg_get" ]; then
    extractValue
    end 0
fi

LF=$'\n'
CR=$'\r'
TAB=$'\t'

function printStacktrace() {
    index=1
    while frame=($(caller "${index}")); do
        ((index++))
        echo "at function ${frame[1]} (${frame[2]}:${frame[0]})" >&2
    done
}

function invalidFormatError(){
    echo 'This json has invalid format.' >&2
    echo $json_value >&2
    printStacktrace
    end 1
}

function checkLiteral(){
    str=$1
    temp+=$char
    [ ${#temp} != ${#str} ] && return || :
    if [ "$temp" = $str ]; then
        pre_processed_jv+=${str:0:1}
        flg_on_read=''
        literal=''
        temp=''
    else
        invalidFormatError
    fi
}

function preProcess(){

    json_value=${json_value_origin//$CR/}
    json_value=${json_value//$LF/}
    flg_on_read='' # 1-str/2-literal
    nr_index=0
    temp=''
    literal=''

    for i in `seq 1 ${#json_value}`; do    
        char=${json_value:(($i-1)):1}
        if [ "$flg_on_read" = 1 ]; then
            [ "a$char" != 'a"' -o "a${json_value:(($i-2)):1}" = 'a\' ] && continue || :
            str_shelf+=("${json_value:$marked_idx:(($i-$marked_idx-1))}")
            flg_on_read=''
            pre_processed_jv+='"'$((nr_index++))
        elif [ "$flg_on_read" = 2 ]; then 
            checkLiteral $literal
        elif [ "$char" = '"' ]; then
            marked_idx=$i
            flg_on_read=1
        elif [ "$char" = 't' ]; then
            checkLiteral true
            literal=true
            flg_on_read=2
        elif [ "$char" = 'f' ]; then
            checkLiteral false
            literal=false
            flg_on_read=2
        elif [ "$char" = 'n' ]; then
            checkLiteral null
            literal=null
            flg_on_read=2
        elif [ "a$char" != "a " -a "a$char" != "a$TAB" ]; then
            pre_processed_jv+=$char
        fi
    done
    [ -n "$flg_on_read" ] && invalidFormatError || :
}

if [ -f "$input" ]; then
    json_value_origin="$(cat $input)"
else
    json_value_origin="$input"
fi    

declare -a str_shelf=()
pre_processed_jv=''
preProcess

touch ${tmp}answer
[ ${#targets[@]} -ne 0 ] && flg_direct=1 || :

function record(){

    if [ -n "$flg_direct" ]; then
        if [ $(($flg_target&1)) != 0 ]; then
            echo "$key" >> ${tmp}answered_targets
            echo "$1" >> ${tmp}answer
        else : 
        fi
    else
        if [ "$flg_on_read" = 1 -o "$flg_on_read" = 2 ]; then
            key_prefix=1
        elif [ "$flg_on_read" = 3 ]; then
            key_prefix=3
        elif [ "$flg_on_read" = 4 ]; then
            key_prefix=2
        fi
        echo ${key_prefix}${key} >> ${tmp}answer
        if [ "$flg_on_read" = 3 ]; then
            output=$(r4process "$1" "$key")
            if [ $? -ne 0 ]; then
                [ -n "$output" ] && echo "$output" || :
                end 1
            fi
        else
            echo "$1" | awk '{print "4" $0}' >> ${tmp}answer
        fi
        [ "$key_prefix" = 2 -o "$key_prefix" = 3 ] && echo ${key_prefix}${key} >> ${tmp}answer || :
    fi
    flg_on_read=''
    flg_target=0
    key=''
}

function readNumValue(){
    
    if [ -z "${json_value:$i:1}" ]; then
        [[ "$char" =~ ^[0-9]$ ]] || invalidFormatError
        last_idx=$(($i-$marked_idx+1))
    elif [[ "$char" =~ ^[0-9]$ ]]; then
        return 0
    else
        [ "$char" != ',' ] && invalidFormatError || :
        [ -z "$1" ] && flg_force=1 || :
        flg_state=1
        last_idx=$(($i-$marked_idx))
    fi

    num_value=${json_value:(($marked_idx-1)):$last_idx}
    if [ -n "$1" ]; then
        echo $num_value
        flg_on_read=''
    else
        record $num_value
    fi
}

function restoreObjValue(){

    if [ $char = '"' ]; then
        str_idx=${json_value:$i:1}
        flg_continue=1
    elif [ -n "$str_idx" ]; then
        if [[ "${json_value:$i:1}" =~ ^[0-9]$ ]]; then
            str_idx+=${json_value:$i:1}
            flg_continue=1
            return 0
        fi
        obj_value+=\"${str_shelf[$str_idx]}\"
        str_idx=''
        flg_continue=1
    elif [ $char = 't' ]; then
        obj_value+=true
        flg_continue=1
    elif [ $char = 'f' ]; then
        obj_value+=false
        flg_continue=1
    elif [ $char = 'n' ]; then
        obj_value+=null
        flg_continue=1
    else
        obj_value+=$char
    fi
}

function identifyClosingBracket(){

    if [ "$char" = '{' ]; then
        depth_counter=$depth_counter'{'
    elif [ "$char" = '['  ]; then
        depth_counter=$depth_counter'['
    elif [ "$char" = '}'  ]; then
        if [ "${depth_counter: -1}" = '{' ]; then
            depth_counter=${depth_counter:0:((${#depth_counter}-1))}
        else 
            invalidFormatError
        fi
    elif [ "$char" = ']'  ]; then
        if [ "${depth_counter: -1}" = '[' ]; then
            depth_counter=${depth_counter:0:((${#depth_counter}-1))}
        else 
            invalidFormatError
        fi
    fi

    [ -n "$depth_counter" ] && flg_continue=1 || :
}

function next(){
    flg_force=2
    flg_state=''
}

function processAarray(){

    flg_force='' # 1-dbq/2-comma
    flg_state=1 # 1-distinguish value/2-extract value
    flg_on_read='' # 1-str/2-num/3-array or obj
    marked_idx=0
    key=''
    depth_counter=''

    for i in `seq 1 ${#json_value}`; do
    
        char=${json_value:(($i-1)):1}

        if [ -n "$flg_force" ]; then

            if [ "$flg_force" = 1 ]; then
                [ "$char" != '"' ] && invalidFormatError || :
                flg_force=''
                flg_on_read=1
            elif [ "$flg_force" = 2 ]; then
                [ "$char" != ',' ] && invalidFormatError || :
                flg_force=''
                flg_state=1
            fi
        
        elif [ "$flg_state" = 1 ]; then
            
            marked_idx=$i
            flg_state=2
            
            if [ "$char" = '"' ]; then
                flg_on_read=1
            elif [[ "$char" =~ ^[0-9]$ ]]; then
                readNumValue 1
                flg_on_read=2
            elif [ "$char" = '{' ]; then
                flg_on_read=3
                depth_counter='{'
                obj_value='{'
            elif [ "$char" = '['  ]; then
                flg_on_read=3
                depth_counter='['
                obj_value='['
            elif [ "$char" = 't' ]; then
                next 
                echo true
            elif [ "$char" = 'f' ]; then
                next 
                echo false
            elif [ "$char" = 'n' ]; then
                next 
                echo null
            else
                invalidFormatError
            fi

        elif [ "$flg_on_read" = 1 ]; then

            str_idx+=$char
            [[ "${json_value:$i:1}" =~ ^[0-9]$ ]] && continue || :
            echo ${str_shelf[$str_idx]}
            str_idx=''

            flg_on_read=''
            next
            
        elif [ "$flg_on_read" = 2 ]; then
            
            readNumValue 1

        elif [ "$flg_on_read" = 3 ]; then

            flg_continue=''
            restoreObjValue
            [ -n "$flg_continue" ] && continue || :

            identifyClosingBracket
            [ -n "$flg_continue" ] && continue || :
            
            flg_on_read=''
            [ "$flg_state" = 2 ] && next || :

            echo "$obj_value"
            obj_value=''
        fi
    done
}

function r4process(){

    json_value=$1
    layer=$2

    char_start=${json_value:0:1}
    char_end=${json_value: -1}
    json_value=${json_value:1:((${#json_value}-2))}

    if [ "$char_start" = '{' ]; then
        [ "$char_end" != '}' ] && invalidFormatError || :
    elif [ "$char_start" = '[' ]; then
        [ "$char_end" = ']' ] && flg_array=1 || invalidFormatError
    fi

    [ -z "$json_value" ] && return 0 || :
    if [ -n "$flg_array" ]; then
        processAarray
        return 0
    fi

    flg_force=1 # 1-dbq/2-comma/3-colon
    flg_state=1 # 1-extract key/2-distinguish value/3-extract value
    flg_on_read='' # 1-str/2-num/3-obj/4-array
    flg_target=0 # 1-this is the target./2-including the target as children./3-both.
    marked_idx=0
    key=''
    depth_counter=''

    for i in `seq 1 ${#json_value}`; do
    
        char=${json_value:(($i-1)):1}

        if [ -n "$flg_force" ]; then

            if [ "$flg_force" = 1 ]; then
                [ "$char" != '"' ] && invalidFormatError || :
                flg_force=''
                flg_on_read=1
            elif [ "$flg_force" = 2 ]; then
                [ "$char" != ',' ] && invalidFormatError || :
                flg_state=1
                flg_force=1
            elif [ "$flg_force" = 3 ]; then
                [ "$char" != ':' ] && invalidFormatError || :
                flg_force=''
                flg_state=2
            fi
        
        elif [ "$flg_state" = 2 ]; then
            
            marked_idx=$i
            flg_state=3
            
            if [ "$char" = '"' ]; then
                flg_on_read=1
            elif [[ "$char" =~ ^[0-9]$ ]]; then
                readNumValue
                flg_on_read=2
            elif [ "$char" = '{' ]; then
                flg_on_read=3
                depth_counter='{'
                obj_value='{'
            elif [ "$char" = '['  ]; then
                flg_on_read=4
                depth_counter='['
                obj_value='['
            elif [ "$char" = 't' ]; then
                next 
                record true
            elif [ "$char" = 'f' ]; then
                next 
                record false
            elif [ "$char" = 'n' ]; then
                next 
                record null
            else
                invalidFormatError
            fi

        elif [ "$flg_on_read" = 1 ]; then

            str_idx+=$char
            [[ "${json_value:$i:1}" =~ ^[0-9]$ ]] && continue || :
            str_value=${str_shelf[$str_idx]}
            str_idx=''

            if [ "$flg_state" = 1 ]; then
    
                flg_force=3
                flg_on_read=''
                str_value=${str_value//./\\.}
                [ "$layer" = 'root' ] && key=$str_value || key=${layer}.${str_value}
                [ -z "$flg_direct" ] && continue || :
    
                for target in ${targets[@]}; do
                    if [ "$target" = "$key" ]; then
                        flg_target=$(($flg_target|1))
                    elif [[ "$target" =~ ^("$key").+$ ]]; then
                        flg_target=$(($flg_target|2))
                    fi
                done
    
            elif [ "$flg_state" = 3 ]; then
                next
                record "$str_value"
            fi

        elif [ "$flg_on_read" = 2 ]; then
            
            readNumValue

        elif [ "$flg_on_read" = 3 -o "$flg_on_read" = 4 ]; then

            flg_continue=''
            if [ "$flg_on_read" = 3 -a $(($flg_target&1)) != 0 ]; then
                restoreObjValue
                [ -n "$flg_continue" ] && continue || :
            fi

            identifyClosingBracket
            [ -n "$flg_continue" ] && continue || :
            
            indexed_obj_value="${json_value:(($marked_idx-1)):(($i-$marked_idx+1))}"
            if [ -z "$flg_direct" -a "$flg_on_read" = 3 ]; then
                obj_value="$indexed_obj_value"

            elif [ -z "$flg_direct" -a "$flg_on_read" = 4 -o \
                 "$flg_on_read" = 3 -a $(($flg_target&2)) != 0 -o \
                 "$flg_on_read" = 4 -a $(($flg_target&1)) != 0 ]; then

                output=$(r4process "$indexed_obj_value" "$key")
                if [ $? -ne 0 ]; then
                    [ -n "$output" ] && echo "$output" || :
                    end 1
                fi
                
                [ "$flg_on_read" = 4 ] && obj_value="$output" || :
            fi

            [ "$flg_state" = 3 ] && next || :

            record "$obj_value"
            obj_value=''
        fi
    done
}

r4process "$pre_processed_jv" root

if [ -n "$flg_direct" ]; then
    if [ ! -f ${tmp}answered_targets ]; then
        echo "Specified targets is not found." >&2
        end 1
    fi
    for target in ${targets[@]}; do
        if ! cat ${tmp}answered_targets | grep -sq "${target//\\/\\\\}" ; then
            echo "$target is not found." >&2
            end 1
        fi
    done
fi

cat ${tmp}answer

end 0
