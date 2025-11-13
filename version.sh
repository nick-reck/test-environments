#!/bin/bash

original_array=($(echo "$1" | tr / '\n' | tr . '\n'))
array=(${original_array[@]:1:4})

commit_message="$2"
if [[ $commit_message == *"hotfix"* ]]; then
  array+=("hotfix")
elif [[ $commit_message == *"major"* ]]; then
  array[2]=0
  array[1]=0
  array[0]=$((array[0]+1))
elif [[ $commit_message == *"minor"* ]]; then
  array[2]=0
  array[1]=$((array[1]+1))
else
  array[2]=$((array[2]+1))
fi

echo "$original_array/$(IFS=.; echo "${array[*]}")"
