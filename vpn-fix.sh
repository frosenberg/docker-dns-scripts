#!/bin/sh

[ $(id -u) = 0 ] || { echo "You must be root (or use 'sudo')" ; exit 1; }

fwrule=`ipfw -a list | grep "deny ip from any to any"`
fwrule_id=`echo $fwrule | awk '{ print $1 }'`
if [ "$fwrule" != "" ]
then
	echo "Found blocking firewall rule: $(tput setaf 1)${fwrule}$(tput sgr0)"
	printf "Deleting rule ${fwrule_id} ... "
	ipfw delete ${fwrule_id}
	if [ $? == 0 ]
	then
		echo "$(tput setaf 2)[OK]$(tput sgr0)"
    else
    	echo "$(tput setaf 1)[FAIL]$(tput sgr0)"
    fi
else
	echo "No rules found. You are good to go"
fi

