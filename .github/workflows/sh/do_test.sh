#!/bin/bash

base=$1
head=$2

do_test=false
while read d; do
    if [[ \
        $d =~ ^cmd/main/.* || \
        $d =~ ^lib/main/.* || \
        $d =~ ^cmd/jar/.* || \
        $d =~ ^lib/jar/.* \
    ]]; then
        do_test=true
        break
    fi
done < <(git diff ${base}..${head} --name-only)

echo $do_test
