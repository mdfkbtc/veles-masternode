#!/bin/bash

# Create main /run dir
if [ ! -d /var/run/veles ]; then
	mkdir /var/run/veles
fi
chown veles /var/run/veles
chmod 775 /var/run/veles

# Run first-run scripts, to create /run dirs, etc.
#source /etc/veles/services.d/*.firstrun
ls /etc/veles/services.d/ | grep ".firstrun" | xargs -L1 bash

# Run proccess controller
/usr/bin/supervisord -c  /etc/veles/velesctl.conf --nodaemon
