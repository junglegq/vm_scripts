#!/bin/bash

## This script is used to setup new OS for security concern. 
#  Run it w/o any parameter

## Add user: insys
useradd insys -s /home/insys/bin/login.sh -m
mkdir -p /home/insys/bin
touch /home/insys/bin/login.sh
chown insys.insys -R /home/insys

## Edit default shell script
cat > /home/insys/bin/login.sh <<EOF
#!/bin/sh
stty erase ^H
stty kill ^U

echo -en "Enter pin: "
read -s pin

if [[ \$pin != 'WinWin88' ]]; then
        exit 0
fi

echo -en "Username: "
read username

su - \$username
EOF

chmod +x /home/insys/bin/login.sh

## AllowUsers for ssh login
echo '' >> /etc/ssh/sshd_config
echo 'AllowUsers insys root@node1 root@node2 root@node3 root@node4 root@box0 root@box1' >> /etc/ssh/sshd_config
service sshd restart

## Remove unused user/group
# Run from node3
#scp -r /tmp/collection/ root@node1:/tmp
# Run from node1
for f in passwd shadow group gshadow; do
	mv /etc/${f} /etc/${f}.bak
	mv /tmp/collection/${f} /etc/${f}
done

## Change passwords
#passwd insys
# 1Jibiji
#passwd root
# I'mRobot8

# Stop unnecessary services
services='fcoe cups kdump postfix oswatcher osmd ovm-consoled ovmport ovmwatch ovs-agent ovs-devmon'
for serv in $services; do
	chkconfig $serv off
done

# Generate trusts between each nodes
#ssh-kengen
#ssh-copy-id <remote host>


# Bypass welcome prompt
> /etc/motd
