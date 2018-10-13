#!/bin/bash

# Arg1: domain name to search for

dom=$1

pid=`ps -ef |grep $dom |grep qemu |awk '{print $2}'`
port=`lsof -nPi |egrep $pid |awk '{print $9}' | cut -d":" -f2 `

echo $port |cut -d ' ' -f 1

