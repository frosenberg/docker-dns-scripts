#!/bin/sh
# Author: Florian Rosenberg

# This script will automate the process that I'm describing in my blog post here:
# http://www.devopslife.com/2014/08/08/docker-boot2docker-and-dns-resolution-of-containers.html

# It makes the following assumptions:
#   - VirtualBox vboxnet0 can be used for the boot2docker-vm
#   - docker0 bridge has the IP 172.17.42.1
# 
# If these assumptions don't hold, this script may not work and needs to be improved.

function printOK {
 	if [ $? == 0 ];
 	then
  		echo "$(tput setaf 2)[OK]$(tput sgr0)"
  	else
  		echo "$(tput setaf 1)[FAIL]$(tput sgr0)"
  	fi
}

function waitForDockerDaemon {
	status=1                               
	while [ $status == 1 ]
	do
		docker version > /dev/null 2>&1
		status=$?
		sleep 3
	done
	printOK
}

# check if root or sudo
#[ $(id -u) = 0 ] || { echo "You must be root (or use 'sudo')" ; exit 1; }

# check if boot2docker is installed
command -v boot2docker > /dev/null 2>&1 || { echo >&2 "boot2docker command not found." ; exit 1; }


# check if boot2docker-vm exists
vm=`VBoxManage list vms | grep boot2docker-vm`
if [ $? == 1 ]; # VM does not exist
then
	printf "*** boot2docker-vm not found. Creating ..."
	boot2docker init > /dev/null 2>&1 || { echo >&2 "  \nSkipping boot2docker (already ran)"; }
	printOK
else
	echo "*** Found existing boot2docker-vm"
fi

printf "*** (Re-)Creating vboxnet0 adapter ..."
VBoxManage hostonlyif remove vboxnet0 > /dev/null  2>&1   # we ingore an error
VBoxManage hostonlyif create > /dev/null 2>&1
printOK

printf "*** Configuring vboxnet0 adapter with 172.16.0.1/16 ..."
VBoxManage hostonlyif ipconfig vboxnet0 --ip 172.16.0.1 --netmask 255.255.0.0
printOK

printf "*** Booting boot2docker-vm ... "	
boot2docker up > /dev/null 2>&1 
printOK

#printf "*** Setting nic2 to use vboxnet0 ..."
#VBoxManage controlvm boot2docker-vm nic2 hostonly vboxnet0
#printOK

printf "*** Configuring eth1 to 172.16.0.11/16 ..."
boot2docker ssh "sudo ifconfig eth1 172.16.0.11 netmask 255.255.0.0"
printOK

printf "*** Setting up route from this host to containers ..."
route=`netstat -nr |grep 172\.17 | awk '{ print $1 }'`
if [ "$route" != "172.17" ];
then
	sudo -i route -n add 172.17.0.0/16 172.16.0.11 > /dev/null
fi
printOK

printf "*** Killing existing docker daemon ... "
docker_pid=`boot2docker ssh "pgrep /bin/docker"`
if [ $? == 0 ]; # we found a process to kill
then
	boot2docker ssh "nohup /usr/bin/sudo sh -c 'kill -KILL ${docker_pid} < /dev/null > /dev/null'" > /dev/null
	printOK
fi

sleep 30 # short wait used to cause troubles

printf "*** Prepare docker daemon to be used with SkyDock and SkyDNS ... "
boot2docker ssh "nohup /usr/bin/sudo sh -c '/usr/local/bin/docker -d -g /var/lib/docker -H unix:// -H tcp://0.0.0.0:2375 --bip=172.17.42.1/16 --dns=172.17.42.1 < /dev/null > /var/log/docker.log 2>&1 &'"
printOK

# export now so we can issue docker command from localhost
export DOCKER_HOST="tcp://:2375"

printf "*** Waiting for docker daemon to be running ... "
waitForDockerDaemon

printf "*** Starting SkyDNS ... "
id=`docker ps | grep skydns:latest`
if [ $? == 1 ];
then
	echo "--------"
	docker run -d -p 172.17.42.1:53:53/udp --name skydns crosbymichael/skydns -nameserver 8.8.8.8:53 -domain docker
	printOK
else
	echo "$(tput setaf 3)[SKIPPED]$(tput sgr0)"
fi

printf "*** Starting SkyDock ... "
id=`docker ps | grep skydock:latest`
if [ $? == 1 ];
then
	echo "--------"
	docker run -d -v /var/run/docker.sock:/docker.sock --name skydock crosbymichael/skydock -ttl 30 -environment dev -s /docker.sock -domain docker -name skydns
	printOK
else
	echo "$(tput setaf 3)[SKIPPED]$(tput sgr0)"
fi

echo "\n   Add export DOCKER_HOST=\"tcp://:2375\" to your .bash_profile if you haven't already ..."
