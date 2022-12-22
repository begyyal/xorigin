#!/bin/bash

tmp_dir='/tmp/act_'$(date +%Y%m%d%H%M%S)
mkdir -p $tmp_dir
tmp=${tmp_dir}'/'$$'_'

function end(){
  rm -f ${tmp}*
  exit $1
}


end 0
