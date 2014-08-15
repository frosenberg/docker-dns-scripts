docker-dns-scripts
==================

A set of generic scripts that make life a bit easier when working with docker and DNS (and VPN). The idea behind the scripts is described in my blog entry: http://www.devopslife.com/2014/08/08/docker-boot2docker-and-dns-resolution-of-containers.html

Please be aware: I'm not a good bash hacker, so improvement requests are welcome :).

## Scripts

`enable-docker-dns.sh`: fixes up boot2docker and local networking to provide seamless access to all docker containers from MacOS. Starts SkyDock and SkyDNS to enable boot2docker on MacOS to provide. Script is idempotent, i.e.,
it won't do anything if everything is already setup correctly (meaning you can run it again and again).

`vpn-fix.sh`: checks if a specific filewall rules exists that VPN clients usually create and deletes it as it blocks working with docker containers and DNS.