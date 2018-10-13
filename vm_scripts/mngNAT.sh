#!/usr/bin/expect -f
# 
# Usage: 
# 	./mngNAT.sh <on|off> <public interface> <public port> <local IP> <local port> [vpn-interface]
#
# Where, 
# 	public interface: g0/0, g0/1
# 	vpn-interface: Optional, currently, only "vpn20" available. By default, no vpn-interface.
#
# For example, to generate rule:
# 	nat server protocol tcp global current-interface 21605 inside 10.101.21.160 2121 vpn-instance vpn20
# Should be:	
#	./mngNAT.sh on g0/1 44444 10.101.22.33 2233 vpn20 
#	./mngNAT.sh on g0/0 44444 192.168.1.234 2233 
#
# Total time consumption for above command
#	real    0m0.771s
#	user    0m0.004s
#	sys     0m0.008s

set timeout 20
set router 192.168.1.1
set user admin
set passwd Wh88oa**mI

# Should be path to nat.cfg
if {$argc == 1} {
	set file [lrange $argv 0 0]
} else {
	set file "nat.cfg"
}

spawn ssh ${user}@${router}
expect "${user}@192.168.1.1's password:" {send "${passwd}\r"}
expect "<H3C>" {send "system\r"}

set fd [open $file r]  
while {[gets $fd line] != -1} {  
        send "$line\r"  
}  
close $fd

# Quit from interface to system mode
#send "quit\r"

# save config
send "save\r"
expect "The current configuration will be written to the device. Are you sure?" {send "y\r"}
expect "(To leave the existing filename unchanged, press the enter key):" {send "\r"}
expect "flash:/startup.cfg exists, overwrite?" {send "y\r"}

#interact

