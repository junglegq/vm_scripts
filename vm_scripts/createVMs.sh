#!/bin/bash
#
# /oses/vm_scripts/create_required_vms.sh
# 
# NOTE: current implementation will identify the hostname for the config policy. Be aware. 


ROOTPATH=/oses
SCRIPTSPATH=$ROOTPATH/vm_scripts
NATTABLE=$SCRIPTSPATH/nat.cfg

MAPFILE=$ROOTPATH/mapping.csv
VMDIR=$ROOTPATH/vms
TMPLDIR=$ROOTPATH/win7_tmpl

RAMDIR=/dev/shm

BTRFS=/sbin/btrfs

# memory size used by VM
MEMSIZE_VM=3500

# Don't use NATIP0 for the GuoPai firewall issue. 08/15/2018
NATIP0="222.73.69.144"
NATIP1="222.73.69.145"

HOST=`hostname`
# This is the IP that new VM in each node starts with.
IPPREFIX="10.101.20."
case $HOST in
	"box0" )
		IPOFFSET=130
		;;
	"box1" )
		IPOFFSET=160
		;;
	"node1" )
		IPOFFSET=60
		;;
	"node2" )
		IPOFFSET=90
		;;
	"box2" )
		IPOFFSET=190
		;;
esac

#####################################################################

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
	sed -i -e "/^name.*$/d" $CURCONF
	sed -i -e "/^vcpus.*$/d" $CURCONF
	sed -i -e "/^cpus.*$/d" $CURCONF
	sed -i -e "/^pci.*$/d" $CURCONF
	sed -i -e "/^vif.*$/d" $CURCONF
	sed -i -e "/^disk.*$/d" $CURCONF
	sed -i -e "/^memory.*$/d" $CURCONF

	# Append special entries
	echo "name=\"$hostname\"" >> $CURCONF

# Test Only, to Pin CPU to target VM
	pinstart=`echo $cpupin |cut -d'-' -f1`
	pinend=`echo $cpupin |cut -d'-' -f2`
	cpucores=$(($pinend-$pinstart+1))

	echo "vcpus=$cpucores" >> $CURCONF
	# echo "cpus=\"$cpupin\"" >> $CURCONF

	echo "memory=\"$MEMSIZE_VM\"" >> $CURCONF

	# echo "disk = [ 'file:/$CURVM/base.img,xvda,w', 'file:/$RAMDIR/ram$hostname.img,xvdb,w' ]" >> $CURCONF
	echo "disk = [ 'file:/$CURVM/base.img,xvda,w' ]" >> $CURCONF

	# Need to setup correct NIC configure for dedicated machines.
	# Current logic is based on hostname.
	thisbox=`hostname`
	if [[ $thisbox = "box0" || $thisbox = "box1" || $thisbox = "node3" ]]; then
		echo "vif = [ 'type=ioemu, mac=$mac, bridge=br0' ]" >> $CURCONF
	elif [[ $thisbox = "node1" || $thisbox = "node2" ]]; then
		#echo "vif = [ 'type=ioemu, mac=$mac, bridge=br20' ]" >> $CURCONF
		echo "vif = [ 'type=ioemu, mac=$mac, bridge=br0' ]" >> $CURCONF
	elif [[ $thisbox = "box2" ]]; then
		echo "vif = [ 'type=ioemu, mac=$mac, bridge=br20' ]" >> $CURCONF
	fi
}

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
	$BTRFS subvolume snapshot $TMPLDIR $CURVM
	
	GenConfig $mac $ip $bdf $hostname $cpupin

	echo "Now, create VM: $hostname"
	xl create $CURCONF

# This is new added feature, in order to assign/revoke access to internet via NAT table in router.
# Any operation should be revoke when close VM. 
#
# We sort out WAN port in router by checking VM's IP. Current rule:
#	int g0/0: 192.168.1.0/24 (box0, box1, node3)
#	int g0/1: 10.101.20.0/24 (node1, node2)
#
# Command should be formatted as below:
# 	./mngNAT.sh on g0/1 44444 10.101.22.33 2233 vpn20
#
	echo "Add new rule to NAT table in router ..."

# Format: 
# 	interface GigabitEthernet0/0
# 	nat server protocol tcp global current-interface 59103 inside 192.168.1.103 5900
# Or, 
# 	interface GigabitEthernet0/1
# 	nat server protocol tcp global current-interface 20100 inside 10.101.20.100 5900 vpn-instance vpn20
#	quit

	LOCALPORT=5900

	if [[ $ip =~ "192.168.1" ]]; then
		p_intf='GigabitEthernet0/0'
		_p_port=${ip##"192.168.1."}
		# Form: 59100  -->  5900
		p_port=`printf "59%03d" ${_p_port}`
		l_intf=$ip
		l_port=$LOCALPORT

		if [ ${_p_port} -lt 128 ]; then
# Don't use NATIP0 for the GuoPai firewall issue. 08/15/2018
			# currentInterface=${NATIP0}
			currentInterface=${NATIP1}
		else
			currentInterface=${NATIP1}
		fi

		echo "interface $p_intf " >> $NATTABLE
		echo "nat server protocol tcp global $currentInterface $p_port inside $l_intf $l_port" >> $NATTABLE
		# Currently, 'quit' command is not required as we then just save config and quit CLI.
		# echo "quit" >> $NATTABLE

		# Form: 60100  -->  6660
		LOCALPORT=6660
		p_port=`printf "60%03d" ${_p_port}`
		l_intf=$ip
		l_port=$LOCALPORT
		# Disable below entry by request from David, 07/20/2018
		# Re-enable below entry by request from David, 08/15/2018
		echo "nat server protocol tcp global $currentInterface $p_port inside $l_intf $l_port" >> $NATTABLE


	elif [[ $ip =~ "10.101.20" ]]; then
	## Don't enter, wrong codes.
		p_intf='GigabitEthernet0/1'
		v_intf='vpn20'
		_p_port=${ip##"10.101.20."}
		# Form: 20100  -->  5900
		p_port=`printf "20%03d" ${_p_port}`
		l_intf=$ip
		l_port=$LOCALPORT

		echo "interface $p_intf " >> $NATTABLE
		echo "nat server protocol tcp global current-interface $p_port inside $l_intf $l_port vpn-instance $v_intf" >> $NATTABLE

		# Form: 60100  -->  6660
		LOCALPORT=6660
		p_port=`printf "60%03d" ${_p_port}`
		l_intf=$ip
		l_port=$LOCALPORT
		# Disable below entry by request from David, 07/20/2018
		# echo "nat server protocol tcp global current-interface $p_port inside $l_intf $l_port vpn-instance $v_intf" >> $NATTABLE


	fi

	echo " ...  Done"

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

# Generate prefix of the mac address
# OBSOLETE : Format: "00:16:3e:CHASSISxx:NODExx"
# Format: 00:16:3e:<Hec of partial IP>:<Hec of partial IP>:<Hec of partial IP>
# For example, IP: 10.101.20.190
#     Should be mapped to 00:16:3e:<hec of 101>:<hec of 20>:<hec of 190>, which equals
#     00:16:3e:65:14:be

PrefixMAC () {
	_prefixVM="00:16:3e"
	_prefixChas=""
	_prefixNode=""
	case $HOST in
		"box0" )
			_prefixChas="00"
			_prefixNode="00"
			;;
		"box1" )
			_prefixChas="01"
			_prefixNode="00" 
			;;
		"node1" )
			_prefixChas="02"
			_prefixNode="01" 
			;;
		"node2" )
			_prefixChas="02"
			_prefixNode="02" 
			;;
		"box2" )
			_prefixChas="65"
			_prefixNode="14" 
			;;
	esac

	echo ${_prefixVM}":"${_prefixChas}":"${_prefixNode}

}



## main function

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



if [ -f $NATTABLE ]; then
	rm -f $NATTABLE
fi


# Target for function PrepareXXX: 
# 1. Destroy VM
# 2. Delete btrfs subvolume
if [[ "x$vmid" != "x" ]]; then
	PrepareSingle $vmid
elif [[ "x$n" != "x" ]]; then
	PrepareAll
fi


if [ "x$n" != "x" ]; then
	## Generate mapping.csv
	rm -f $MAPFILE

	for ((i=0;i<$n;i++)); do
		_prefixmac=$(PrefixMAC)
		_char=`printf "%02x" $((IPOFFSET+i))`
		newmac=${_prefixmac}":"${_char}	
		newip=${IPPREFIX}$((IPOFFSET+i))		
		vmname=${HOST}VF$((IPOFFSET+i))		
		# PS: 0-2 now just means to assign 3 CPU threads
		echo "$newmac,$newip,XENVIRT,$vmname,0-2" >> $MAPFILE
	done
	
	## Generate dhcp configfile
	echo Generate dhcp configfile
	dhcpcfg="paipai_$HOST.conf"
	rm -f $dhcpcfg

	echo "## Reserved range for paipai program in $HOST" >> $dhcpcfg
	echo "" >> $dhcpcfg
	while read line; do
		mac=`echo $line |cut -d',' -f1`
		ip=`echo $line |cut -d',' -f2`
		bdf=`echo $line |cut -d',' -f3`
		hostname=`echo $line |cut -d',' -f4`
		
		echo "host $hostname {" >> $dhcpcfg
		echo "    hardware ethernet ${mac};" >> $dhcpcfg
		echo "    fixed-address ${ip};" >> $dhcpcfg
		echo "}" >> $dhcpcfg
		
	done < $MAPFILE

	echo Send dhcpd.conf to remote keysrv and restart remote dhcpd service...
	dhcpserver=keysrv-20
	scp $dhcpcfg ${dhcpserver}:/etc/dhcp/paipai/
	ssh ${dhcpserver} "systemctl restart dhcpd"
	
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

echo For box2, disable script mngNAT.sh
# echo "Last, invoke mngNAT.sh to enable NAT config in router"
# echo ""
# $SCRIPTSPATH/mngNAT.sh $NATTABLE

echo " ***   Bye   *** "
echo " ***     End by `date` "
