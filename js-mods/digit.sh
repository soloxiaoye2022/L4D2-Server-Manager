#!/bin/bash

start=1
end=200

for ((i=start; i<=end; i++)); do
  echo -n "$i"
  
  if [ $i -ne $end ]; then
    echo -n ";"
  fi
done

echo