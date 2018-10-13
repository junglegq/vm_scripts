#!/bin/bash
#
# /oses/vm_scripts/genAll.sh
# 
# NOTE: 

DEFAULTPOOL='box0 box1 node1 node2 node3'

# Max num available for generating VMs. 
MAX_BOX0=27
MAX_BOX1=20
MAX_NODE1=10
MAX_NODE2=10
MAX_NODE3=10

ROOTPATH=/oses/vm_scripts
#CREATEVM=${ROOTPATH}/createVMs.sh
CREATEVM='echo'

declare -i n

Usage()
{
        echo "$0 -n <number>  [ -p <nodes list> ]"
}

while getopts "n:p:" arg  
do
        case $arg in
             n)
		n=$OPTARG;;
             p)
		_pool=$OPTARG;;
             ?)
                Usage 
		exit 1 ;;
         esac
done

echo " ***   This is a wrapper to generate VMs through all nodes.  *** "
echo ""
#echo "======================================================="

if [[ "x$n" = "x" ]]; then
	Usage
	exit 2
fi

pool=${_pool:-${DEFAULTPOOL}}
echo "We will create $n VMs on nodes: ${pool}"

# Count VM number for each node. 
declare -i _nodes
declare -i _avg

_nodes=`echo $pool | grep -o " " |wc -l`
_nodes=$_nodes+1
_avg=$(($n/$_nodes))

# Using indirect variable referencing 
for _l in MAX_BOX0 MAX_BOX1 MAX_NODE1 MAX_NODE2 MAX_NODE3; do
	if [[ ${!_l} -gt $_avg ]]; then
		=$_avg
	fi
done

declare -i _rest

for _l in MAX_BOX0 MAX_BOX1 MAX_NODE1 MAX_NODE2 MAX_NODE3; do
	echo $_l : ${!_l}
done
#while [[ $n -ne 0 ]]; do
	
#	n=$n-1
#done

#for node in $pool; do
#	echo
	# ssh $node "$CREATEVM -n $n "
#done

echo " ***   Finish generating VMs "
