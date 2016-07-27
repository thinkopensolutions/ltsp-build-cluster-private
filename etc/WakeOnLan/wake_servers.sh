#!/bin/bash

MACS="proxmox01.E6:ED:90:62:E4:2b proxmox02.00:18:FE:6E:78:06 proxmox03.00:19:BB:4A:47:A8 proxmox04.00:19:BB:4A:7E:EF proxmox05.00:19:BB:4A:80:B8 proxmox06.00:19:BB:5F:64:2E proxmox07.00:19:BB:4A:81:BD"

if [ $# -eq 0 ]; then
	echo "Please run like 'wake_servers.sh SERVER01 SERVER02 ...' or 'wake_servers.sh all'"
	echo "Possible Servers:"
	echo "	SERVER		MAC"
	for m in $MACS; do
		server=$(echo $m | awk 'BEGIN { FS = "." } ; {print $1}')
		mac=$(echo $m | awk 'BEGIN { FS = "." } ; {print $2}')
		echo "	$server	$mac"
	done
else
	for param in $*; do
		for m in $MACS; do
			server=$(echo $m | awk 'BEGIN { FS = "." } ; {print $1}')
			mac=$(echo $m | awk 'BEGIN { FS = "." } ; {print $2}')
			if [ $param == $server -o $param == "all" ]; then
				echo "Waiking $server:"
				echo -n "	"
				wakeonlan $mac
			fi
		done
	done
fi
