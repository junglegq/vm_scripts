#!/bin/bash

SHUTDOWN=/sbin/shutdown
POWEROFF=/sbin/poweroff
REBOOT=/sbin/reboot

SHUTDOWN_REAL=$SHUTDOWN.real
POWEROFF_REAL=$POWEROFF.real
REBOOT_REAL=$REBOOT.real

mv -n $SHUTDOWN $SHUTDOWN_REAL
mv -n $POWEROFF $POWEROFF_REAL
mv -n $REBOOT $REBOOT_REAL

cat > $SHUTDOWN << EOF
#!/bin/bash

echo "WARNING !!!  This is DOM 0. Are you sure to shutdown/reboot the system ?"
echo "Please run $SHUTDOWN_REAL instead if confirmed. "
EOF

chmod 700 $SHUTDOWN

cat > $POWEROFF << EOF
#!/bin/bash

echo "WARNING !!!  This is DOM 0. Are you sure to shutdown/reboot the system ?"
echo "Please run $POWEROFF_REAL instead if confirmed. "
EOF

chmod 700 $POWEROFF

cat > $REBOOT << EOF
#!/bin/bash

echo "WARNING !!!  This is DOM 0. Are you sure to shutdown/reboot the system ?"
echo "Please run $REBOOT_REAL instead if confirmed. "
EOF

chmod 700 $REBOOT
