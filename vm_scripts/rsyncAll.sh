#!/bin/bash

rsync=`which rsync`
rsyncopt="-avz -e ssh"

#tgtsys="box0 box1 node1 node2"
tgtsys="box0 node2"

for tgt in $tgtsys; do
	dir_win7=/mnt/mfs/all_templates/w7_paipai_latest.tmpl/
	dir_scripts=/mnt/mfs/all_templates/vm_scripts/
	remote_win7=${tgt}:/oses/win7_tmpl
	remote_scripts=${tgt}:/oses/vm_scripts

	echo Todo: ${rsync} ${rsyncopt} ${dir_win7} ${remote_win7}
	${rsync} ${rsyncopt} ${dir_win7} ${remote_win7}
	echo Todo: ${rsync} ${rsyncopt} ${dir_scripts} ${remote_scripts}
	${rsync} ${rsyncopt} ${dir_scripts} ${remote_scripts}

done

