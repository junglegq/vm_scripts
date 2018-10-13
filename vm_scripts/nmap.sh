#!/bin/bash
if [ `hostname` != 'node4' ]; then
	echo "This script MUST be run in 'node4' "
	exit 1
fi

logfile=nmap.log
rm -f $logfile

# box0 
nmap -p5900 192.168.1.130-139 &>> $logfile
# box1
nmap -p5900 192.168.1.160-169 &>> $logfile

# node1 
nmap -p5900 192.168.1.60-69 &>> $logfile
# node2
nmap -p5900 192.168.1.90-99 &>> $logfile
