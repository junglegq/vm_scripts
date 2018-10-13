#!/bin/bash


xl list |cut -d ' ' -f 1 | while read -r line; do printf "$line";printf ",";  /oses/vm_scripts/find_vncport.sh "$line" 2>/dev/null; done


