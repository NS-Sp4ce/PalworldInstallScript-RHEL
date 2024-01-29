# PalworldInstallScript-RHEL-
RHEL linux (Centos7/RHEL7) one key install palworld server script

test on
```
[root@VM-4-11-centos ~]# uname -a
Linux VM-4-11-centos 3.10.0-1160.105.1.el7.x86_64 #1 SMP Thu Dec 7 15:39:45 UTC 2023 x86_64 x86_64 x86_64 GNU/Linux 
[root@VM-4-11-centos ~]# cat /etc/redhat-release 
CentOS Linux release 7.6.1810 (Core)
```

#Functionality:

- Allocate 32GB of SWAP space.
- Create a Steam user with a random 12-character password.
- Install PalServer.
- Continuously terminate high CPU usage processes named "xrx".
- Open the firewall (firewalld).
- Start PalServer in the background.

# Usage
## install
`./pal.sh install`
## backup
`./pal.sh backup` Recommended usage:
```
[root@VM-4-11-centos ~]# crontab -e
#restart palserver
0 6 * * * /root.pal.sh backup
```
## update
`./pal.sh update`
## monitor
The monitor function is used to monitor whether the PalServer has crashed. Recommended usage:
```
[root@VM-4-11-centos ~]# crontab -e
#monitor
* * * * * /root/pal.sh monitor
* * * * * sleep 10; /root/pal.sh monitor
* * * * * sleep 20; /root/pal.sh monitor
* * * * * sleep 30; /root/pal.sh monitor
* * * * * sleep 40; /root/pal.sh monitor
* * * * * sleep 50; /root/pal.sh monitor

```

# E.g

```
[root@VM-4-11-centos ~]# ./pal.sh install
[*]- Mon Jan 29 14:22:28 CST 2024 - Script started
[*]- Mon Jan 29 14:22:28 CST 2024 - Now installing PalServer-Linux...
[*]- Mon Jan 29 14:22:28 CST 2024 - Creating swap file...
[+]- Mon Jan 29 14:22:28 CST 2024 - Swap file information added to /etc/fstab
[+]- Mon Jan 29 14:22:28 CST 2024 - [S] useradd: user 'steam' already exists
[+]- Mon Jan 29 14:22:28 CST 2024 - User 'steam' created with a random password => WbKN8CZi0E9VEK1n
[*]- Mon Jan 29 14:22:28 CST 2024 - Installing dependencies...
Loaded plugins: fastestmirror, langpacks
Loading mirror speeds from cached hostfile
Package glibc-2.17-326.el7_9.i686 already installed and latest version
Package libstdc++-4.8.5-44.el7.i686 already installed and latest version
Nothing to do
[+]- Mon Jan 29 14:22:29 CST 2024 - Dependencies installed successfully
[*]- Mon Jan 29 14:22:29 CST 2024 - Checking if steamcmd.sh exists...
[*]- Mon Jan 29 14:22:29 CST 2024 - /home/steam/Steam/steamcmd.sh already exists. Skipping download.
[+]- Mon Jan 29 14:22:29 CST 2024 - steamcmd.sh found.
[*]- Mon Jan 29 14:22:29 CST 2024 - Proceeding with install PalServer steps...
[*]- Mon Jan 29 14:22:29 CST 2024 - /home/steam/Steam/steamapps/common/PalServer already exists. Skipping game server installation.
[+]- Mon Jan 29 14:22:29 CST 2024 - PalServer-Linux found.
[*]- Mon Jan 29 14:22:29 CST 2024 - Proceeding with install SDK...
[*]- Mon Jan 29 14:22:29 CST 2024 - Copy SDK done
[*]- Mon Jan 29 14:22:29 CST 2024 - Now set firewalld rules
[+]- Mon Jan 29 14:22:29 CST 2024 - [S] 
[+]- Mon Jan 29 14:22:29 CST 2024 - [S] Warning: ALREADY_ENABLED: 8211:udp
success
[+]- Mon Jan 29 14:22:31 CST 2024 - [S] success
[+]- Mon Jan 29 14:22:32 CST 2024 - [S] public
  target: default
  icmp-block-inversion: no
  interfaces: 
  sources: 
  services: dhcpv6-client ssh
  ports: 8211/udp
  protocols: 
  masquerade: no
  forward-ports: 
  source-ports: 
  icmp-blocks: 
  rich rules: 
	
[+]- Mon Jan 29 14:22:32 CST 2024 - Firewall rules set successfully
[!]- Mon Jan 29 14:22:32 CST 2024 - Server start
[!]- Mon Jan 29 14:22:32 CST 2024 - Server start end
[*]- Mon Jan 29 14:22:34 CST 2024 - Checking if PalServer-Linux is running...
[+]- Mon Jan 29 14:22:49 CST 2024 - PalServer-Linux is running and listening on port 8211.PID: 26390
[+]- Mon Jan 29 14:22:49 CST 2024 - [S] * * * * * pgrep -x 'xrx' > /dev/null && pkill -x 'xrx'
[+]- Mon Jan 29 14:22:49 CST 2024 - Crontab set successfully
[+]- Mon Jan 29 14:22:49 CST 2024 - Installation completed successfully,log file is /tmp/pal/pal_script_2024-01-29-14-22-28.log
[*]- Mon Jan 29 14:22:49 CST 2024 - Script ended

```
