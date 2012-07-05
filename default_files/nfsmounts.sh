# Start portmap in case it gets started further on down the line (as is the case in ltsp startup)
# if the ping command returns a "0 received" then we assume server down
# we then do nothing, because there inst a way to mount that NFS
# if we don't get the "0" in received then we assume it already up and then run the Mount

sudo /etc/init.d/portmap restart

if [ "$(ping -c 3 172.31.100.2 | grep '0 received')" ]
then
        : ; exit 1
else
        # check to see if your NFS is mounted
        # : means if your NFS is there then doing nothing
        # if its not then mount your NFS

        if df | grep -q '172.31.100.2:/home'
        then :
        else
                mount -t nfs 172.31.100.2:/home /home
        fi
fi
