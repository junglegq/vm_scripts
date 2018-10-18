#!/bin/bash

DRY_RUN=1
if [[ $DRY_RUN -eq 1 ]]; then
	echo "      !!! WARNING !!! "
	echo "      !!! WARNING !!! "
	echo "      !!! WARNING !!! "	
	echo "    This is dry-run build. "
fi

HOST=`hostname`
if [[ $HOST != "box2" ]]; then
	echo "This script is only for box2. Exit..."
	exit 1
fi

ROOTPATH=/oses/captcha_test_server
SCRIPTSPATH=$ROOTPATH/vm_scripts
NATTABLE=$SCRIPTSPATH/nat.cfg

MAPFILE=$SCRIPTSPATH/mapping.csv
TMPLDIR=/oses/captcha_test_server.tmpl

RAMDIR=/dev/shm

BTRFS=/sbin/btrfs

# Don't use NATIP0 for the GuoPai firewall issue. 08/15/2018
NATIP0="222.73.69.144"
NATIP1="222.73.69.145"				

DEFAULT_BR=br20


declare all
declare vmid

Usage()
{
	echo "$0: Close VMs as required. "
	echo "Usage: $0 [ -b <bridge> ] [ -a | -s <VM NAME> ]"
	echo ""
	echo "Options:"
	echo "     -b <bridge>: bridge where VM is on. If not shown, default: br20"
	echo "     -a: all VMs"
	echo "     -s <VM NAME>: specific VM to be closed "
}


PrepareSingle()
{
	vm=$1
	
	#echo "Prepare for single VM: $vm"
	echo "Destroy VM $vm ..."
	xl -f destroy $vm 2>/dev/null
	
	# $BTRFS subvolume delete $VMDIR/$vm/win7_tmpl
	echo "BTRFS subvolume delete $VMDIR/$vm ..."
	$BTRFS subvolume delete $VMDIR/$vm
	
	# This is new added feature, in order to revoke access to internet via NAT table in router.
	#
	# We sort out WAN port in router by checking VM's IP. Current rule:
	#       int g0/0: 192.168.1.0/24 (box0, box1, node3)
	#       int g0/1: 10.101.20.0/24 (node1, node2)
	#
	# Command should be formatted as below:
	#       ./mngNAT.sh off g0/1 44444 10.101.22.33 2233 vpn20
	#

	LOCALPORT=5900

	ip=`egrep $vm $MAPFILE | cut -d',' -f2`
	
	if [[ $ip =~ "192.168.1" ]]; then
		p_intf='GigabitEthernet0/0'
		_p_port=${ip##"192.168.1."}
		# Form: 59100  -->  5900
		p_port=`printf "59%03d" ${_p_port}`
		l_intf=$ip
		l_port=$LOCALPORT
	
		if [ ${_p_port} -lt 128 ]; then
			# Don't use NATIP0 for the GuoPai firewall issue. 08/15/2018
			currentInterface=${NATIP1}
		else
			currentInterface=${NATIP1} 
		fi
	
	
		# Format: 
		# 	interface GigabitEthernet0/0
		# 	undo nat server protocol tcp global current-interface 59100 inside 192.168.1.100 5900
		echo "interface $p_intf" >> $NATTABLE
		echo "undo nat server protocol tcp global $currentInterface $p_port inside $l_intf $l_port" >> $NATTABLE
		
		# Form: 60100  -->  6660
		LOCALPORT=6660
		p_port=`printf "60%03d" ${_p_port}`
		l_intf=$ip
		l_port=$LOCALPORT
		echo "undo nat server protocol tcp global $currentInterface $p_port inside $l_intf $l_port" >> $NATTABLE
	
	elif [[ $ip =~ "10.101.20" ]]; then
		p_intf='GigabitEthernet0/1'
		v_intf='vpn20'
		p_port=${ip##"10.101.20."}
		p_port='20'$p_port      # Form: 20100
		l_intf=$ip
		l_port=$LOCALPORT
		
		# Format: 
		# 	interface GigabitEthernet0/0
		# 	undo nat server protocol tcp global current-interface 20100 inside 10.101.20.100 5900 vpn-instance vpn20
		echo "interface $p_intf" >> $NATTABLE
		echo "undo nat server protocol tcp global current-interface $p_port inside $l_intf $l_port vpn-instance $v_intf " >> $NATTABLE
	
	else 
		echo "Can't find ip from mapping file $MAPFILE with VM name $vm"
	fi    
	
	echo " ... Done "
}

PrepareAll()
{
	echo "Prepare for all VMS ... "
	
	# To delete subvolumes in $VMDIR
	for vm in $VMDIR/*; do
		curvm=`basename $vm`
		PrepareSingle $curvm	
	done
	
	$BTRFS filesystem defrag $ROOTPATH
}

#### Main function  ####

# Target: 
# 1. Destroy VM
# 2. Delete btrfs subvolume

# Patterns
VMDIR=$ROOTPATH/vms_BRXX
MAPFILE=$SCRIPTSPATH/mapping_BRXX.csv
NATTABLE=$SCRIPTSPATH/nat_BRXX.cfg

while getopts "b:as:" arg  
do
	case $arg in
		b)
			DEFAULT_BR=$OPTARG
			# Rename global variables here: 
			#   for example, New format as is: mapping_br20.csv
			echo "Will close VM on bridge: $DEFAULT_BR" ;;
	    a)
			all="yes"
			# Rename global variables here: 
			#   for example, New format as is: mapping_br20.csv
			echo "Will close all VMs ..." ;;		
	    s)
	        vmid=$OPTARG        
	        # Rename global variables here:  
			#   for example, New format as is: mapping_br20.csv
			echo "Close VM: $vmid ..." ;;			
		?)
			Usage
			exit 1 ;;
	esac
done

if [[ "x$all" = "x" ]] && [[ "x$vmid" = "x" ]]; then
	Usage
	exit 1
fi

VMDIR=${VMDIR/BRXX/${DEFAULT_BR}}
MAPFILE=${MAPFILE/BRXX/${DEFAULT_BR}}
NATTABLE=${NATTABLE/BRXX/${DEFAULT_BR}}

if [[ $all = "yes"  ]]; then
	PrepareAll
fi
if [[ "x$vmid" != "x" ]]; then
	PrepareSingle $vmid
fi

if [ -f $NATTABLE ]; then
	rm -f $NATTABLE
fi

echo "For box2, do not execute script --> $SCRIPTSPATH/mngNAT.sh $NATTABLE"
#echo "Last, invoke mngNAT.sh to remove NAT entries in the interface of the router. "
#echo ""
#$SCRIPTSPATH/mngNAT.sh $NATTABLE
