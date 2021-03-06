#!/bin/bash
#
# Add entries to dhcpd configure file

ROOTPATH=/oses

MAPFILE=$ROOTPATH/mapping.csv
VMDIR=$ROOTPATH/vms
TMPLDIR=$ROOTPATH/win7_tmpl

RAMDIR=/dev/shm

BTRFS=/sbin/btrfs


declare -i n
declare vmid

Usage()
{
        echo "$0 [ -n <number> | -s <VM NAME> ]"
}

######################################################################
# GenConfig()
# Args: 
#      mac, ip, bdf, hostname, cpupin

GenConfig()
{
	mac=$1
	ip=$2
	bdf=$3
	hostname=$4
	cpupin=$5
		
	CURCONF=$CURVM/$hostname.cfg
	mv $CURVM/*.cfg $CURCONF
	echo "Modify config file: $CURCONF"

	# Remove special entries
	sed -i -e "/^name=.*$/d" $CURCONF
	sed -i -e "/^vcpus=.*$/d" $CURCONF
	sed -i -e "/^cpus=.*$/d" $CURCONF
	sed -i -e "/^pci =.*$/d" $CURCONF
	sed -i -e "/^disk =.*$/d" $CURCONF

	# Append special entries
	echo "name=\"$hostname\"" >> $CURCONF

# Test Only, to Pin CPU to target VM
	pinstart=`echo $cpupin |cut -d'-' -f1`
	pinend=`echo $cpupin |cut -d'-' -f2`
	cpucores=$(($pinend-$pinstart+1))

	echo "vcpus=$cpucores" >> $CURCONF
	echo "cpus=\"$cpupin\"" >> $CURCONF


	# echo "disk = [ 'file:/$CURVM/base.img,xvda,w', 'file:/$RAMDIR/ram$hostname.img,xvdb,w' ]" >> $CURCONF
	echo "disk = [ 'file:/$CURVM/base.img,xvda,w' ]" >> $CURCONF
	echo "pci = [ '$bdf' ]" >> $CURCONF

}


while getopts "n:s:" arg  
do
        case $arg in
             n)
		n=$OPTARG 
		echo "Open $n VMs ..." ;;
             s)
		vmid=$OPTARG 
		echo "Create VM: $vmid ..." ;;
             ?)
                Usage 
		exit 1 ;;
         esac
done

if [[ "x$n" = "x" ]] && [[ "x$vmid" = "x" ]]; then
	Usage
	exit 2
fi

##################
#exit 0
##################

echo " ***   Hello, world   *** "
echo " ***     Start from : `date` "
echo ""
echo "======================================================="
echo ""

#########################################################
# CreateSingleVM()
# Args: 
#      mac, ip, bdf, hostname, cpupin

CreateSingleVM()
{
        mac=$1
        ip=$2
        bdf=$3
        hostname=$4
        cpupin=$5

	echo " *** Creating VM instance: `date` "

	echo "Create btrfs snapshot for each vm, and name it as hostname. "
	CURVM=$VMDIR/$hostname
	$BTRFS subvolume snapshot $ROOTPATH/win7_tmpl/ $CURVM
	
	GenConfig $mac $ip $bdf $hostname $cpupin

	echo "Now, create VM: $hostname"
	xl create $CURCONF

}

PrepareSingle()
{
	vm=$1

	#echo "Prepare for single VM: $vm"
	echo "Destroy VM $vm ..."
	xl destroy $vm 2>/dev/null
	$BTRFS subvolume delete $VMDIR/$vm
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



# Target for function PrepareXXX: 
# 1. Destroy VM
# 2. Delete btrfs subvolume

if [[ "x$vmid" != "x" ]]; then
	PrepareSingle $vmid
elif [[ "x$n" != "x" ]]; then
	PrepareAll
fi

# Read mapping.csv
while read line; do

	mac=`echo $line |cut -d',' -f1`
	ip=`echo $line |cut -d',' -f2`
	bdf=`echo $line |cut -d',' -f3`
	hostname=`echo $line |cut -d',' -f4`

# Test Only, to Pin CPU to target VM
	cpupin=`echo $line |cut -d',' -f5`

	if [[ "x$vmid" != "x" ]]; then
		if [[ $vmid = $hostname ]]; then 
			echo " *** Creating single VM: $vmid -- `date` "

			CreateSingleVM $mac $ip $bdf $hostname $cpupin
			break
		else
			continue
		fi

	elif [ $n -ne 0 ]; then
		CreateSingleVM $mac $ip $bdf $hostname $cpupin
# For generic HD, we need to wait 3 mins to initialize VM without experiencing HD I/O flooding.
# But, that's not true for NVMe.  
		echo "     Sleep 15 seconds for the initialization of VM $hostname ... "
		sleep 15

		echo ""
		echo "======================================================="
		echo ""

		n=$n-1

	fi
done < $MAPFILE


echo " ***   Bye   *** "
echo " ***     End by `date` "
