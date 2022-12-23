#!/bin/bash

tag_name=$1
repo_url=$2 # https
repos_name=""
ext="" # hashtag etc...

LF=$'\\n'
text="${repos_name} updated to ${tag_name}${LF}${repo_url}"
[ -n "$ext" ] && text=${text}${LF}${ext} || :

echo -n "{\"text\":\"${text}\"}"