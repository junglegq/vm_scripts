#!/bin/bash

# The target of this script is to centralize VMs loading scripts. 

CreateVM()
{
	cfgfile=$1

	if [ -e ${cfgfile} ]; then
		xl create ${cfgfile}
		sleep 10
	else
		echo "Can't find VM configuration file: ${cfgfile} -- Exit -- "
	fi

}

# Each customer should group indevidual VMs here.


# YUYI, by Jim
CreateVM /vms/yuyi/w12r2/win12r2_00/w12r2.cfg
CreateVM /vms/yuyi/w12r2/win12r2_01/w12r2.cfg
CreateVM /vms/yuyi/centos7/centos7_00/centos7_00.cfg

