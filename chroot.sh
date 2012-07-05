#!/bin/bash

sudo mount --bind /dev /opt/ltsp/i386/dev && sudo mount -t proc none /opt/ltsp/i386/proc && sudo chroot /opt/ltsp/i386/

