#!/bin/bash

if [ $# -ne 1 ]; then
    echo "S0 Generator, converts address to S9 Record"
    echo "$0 \"<Hex address to execute>\""
    exit 1
fi

CHKSUM=3

while read -n 2 a
do
    CHKSUM=$(($CHKSUM+0x${a}))
done <<< "${1}"

CHKSUM=$(( 255 - (${CHKSUM}&255) ))
printf "S9%02X%s%02X\n" 3 "${1}" ${CHKSUM}
