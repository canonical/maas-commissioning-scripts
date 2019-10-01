#!/bin/bash
#
#    Foundation Cloud Infrastructure Setup Script for HP Smart Array CLI 
#    
#    This script configures HP Smart Array Controllers
#
#    Copyright (C) 2019 Canonical Ltd.
#
#    Authors: Craig Bender <craig.bender@canonical.com>
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, version 3 of the License.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# 







#Exit script if non-hp hardware detected
NODE_VENDOR="$(dmidecode -s system-manufacturer)"
[[ ${NODE_VENDOR} = HP ]] || { printf "Non-HP Server Detected, exiting.\n" 2>&1;exit 0; }
#Get the Server Model incase we have to run a different utility other than hpssacli
export NODE_MODEL="$(dmidecode -s system-product-name)"

printf "Detected ${NODE_VENDOR} ${NODE_MODEL}\n" 2>&1





#Download repository keys and package for HP SSA Client
export SCMD=sudo
printf "Installing HP Utilities\n" 2>&1
sh -c "echo 'deb http://downloads.linux.hpe.com/SDR/repo/mcp xenial/current non-free' > /etc/apt/sources.list.d/mcp.list"
sh -c "echo 'deb http://downloads.linux.hpe.com/SDR/repo/hprest xenial/current non-free' > /etc/apt/sources.list.d/hprest.list"
curl -s https://downloads.linux.hpe.com/SDR/hpPublicKey1024.pub |apt-key add - > /dev/null 2>&1
curl -s https://downloads.linux.hpe.com/SDR/hpPublicKey2048.pub |apt-key add - > /dev/null 2>&1
curl -s https://downloads.linux.hpe.com/SDR/hpPublicKey2048_key1.pub |apt-key add - > /dev/null 2>&1
curl -s https://downloads.linux.hpe.com/SDR/hpePublicKey2048_key1.pub |apt-key add - > /dev/null 2>&1
apt update 
DEBIAN_FRONTEND=noninteractive apt install hponcfg hprest hpssacli hpssa linux-image-extra-$(uname -r) --no-install-recommends -y 
sudo apt dist-upgrade -y
modprobe hpilo


#Check if packages downloaded has already been downloaded, otherwise add to pkg list
command -v hpssacli > /dev/null 2>&1 || { printf "hpssacli failed to download\n" 2>&1; exit 0; }
[[ -n $(lsmod|grep hpilo) ]] || { printf "hpilo kernel mod failed to load\n" 2>&1; exit 0; }
[[ $(dpkg -l linux-image-extra-$(uname -r)|awk '/linux/{print $2}') = linux-image-extra-$(uname -r) ]] || { printf "linux-image-extra-$(uname -r) failed to download\n" 2>&1; exit 0; }




#Run commands based on server model

declare -a CONTROLLERS=($(hpssacli ctrl all show|grep -Po '(?<=Slot )[^ ]+'))
	
		
for ctl in ${CONTROLLERS[@]};do

	#Get Controller Model
	export CTL_MODEL="$(hpssacli controller slot=${ctl} show|grep -m1 -Po '(?<=^)[^in]+'|sed -E 's/^ | $//g')"	
	printf "Current config for Controller ${ctl} (${CTL_MODEL})\n" 2>&1
	hpssacli controller slot=${ctl} show config


	#
	##
	### Delete Any logical Drives
	##
	#
	
	printf "Checking for logical drives on ${CTL_MODEL}\n" 2>&1
	LD_ARR=($(hpssacli ctrl slot=${ctl} show config |awk '/logicaldrive/{print $2}'))
	printf "Discovered  ${#LD_ARR[@]} logical drives on ${CTL_MODEL}\n" 2>&1
	for l in ${LD_ARR[@]}; do 
		printf "Deleting Logical Drive ${l} from the ${CTL_MODEL} controller in slot ${ctl}\n" 2>&1
		printf 'y\n'|hpssacli ctrl slot=${ctl} ld ${l} delete
	done
	
	
	#
	##
	### Enable True HBA Mode for Controllers that support it
	##
	#
			
	if [[ ${CTL_MODEL} != "Smart HBA H240ar" ]];then
		
		printf "Attempting to enable HBA Mode on ${HOST}: ${NODE_MODEL}\n" 2>&1
		
		#These commands should work for all other HP Controllers, but were tested on XL420
		printf 'y\n'|hpssacli controller slot=${ctl} modify hbamode=off forced 
		printf 'y\n'|hpssacli controller slot=${ctl} modify hbamode=on forced 
		printf 'y\n'|hpssacli controller slot=${ctl} modify hbamode=off forced 
		printf 'y\n'|hpssacli controller slot=${ctl} modify hbamode=on forced 
		sleep 2
		
		#The following value will be true if successful
		export HBA_ENABLED=$(hpssacli controller slot=${ctl} show|awk '/HBA Mode Enabled:/{print $NF}')
		[[ ${HBA_ENABLED} = True ]] && printf "HBA Mode enabled for the ${CTL_MODEL} controller on ${HOST}: Model=${NODE_MODEL}\n" 2>&1

		
		


	#
	##
	### Enable AHCI mode (Ubuntu does not support Dynamic RAID on the Smart HBA H240ar)
	##
	#			
		
	elif [[ ${CTL_MODEL} = "Smart HBA H240ar" ]];then
		if [[ "$(hprest get EmbeddedSata --selector HpBios.|grep -m1 -Po '(?<=EmbeddedSata=)[^$]+'|sed -E 's/^ | $//g')" != Ahci ]];then
			printf "Enabling AHCI mode on ${CTL_MODEL}\n" 2>&1
			hprest set EmbeddedSata=Ahci --selector HpBios --commit 
			sleep 1
		else
			printf "AHCI already enabled for the ${CTL_MODEL} controller on ${HOST}: Model=${NODE_MODEL}\n" 2>&1
		fi
		
		
		#
		##
		### Original Mode
		### --------------
		### /dev/sda (Single-Drive Logical Disk - RAID 0)
		### /dev/sdb (Four-Drive Logical Disk - RAID 0)
		##
		#	
		printf "Building RAID Configuration on ${CTL_MODEL}\n" 2>&1
		printf 'y\n'|hpssacli ctrl slot=${ctl} create type=ld drives=1I:1:1 raid=0 stripsize=128
		printf 'y\n'|hpssacli ctrl slot=${ctl} create type=ld drives=1I:1:2,1I:1:3,1I:1:4,2I:1:5 raid=0 stripsize=128

		#
		##
		### Big Disk Mode
		### --------------
		### /dev/sda (Five-Drive Logical Disk - RAID 0)
		##
		#	
		
		#printf 'y\n'|hpssacli ctrl slot=${ctl} create type=ld drives=1I:1:1,1I:1:2,1I:1:3,1I:1:4,2I:1:5 raid=0 stripsize=128

		
		#
		##
		### Fake JBOD
		### ----------
		### /dev/sda (Single-Drive Logical Disk, RAID 0)
		### /dev/sdb (Single-Drive Logical Disk, RAID 0)
		### /dev/sdc (Single-Drive Logical Disk, RAID 0)
		### /dev/sdd (Single-Drive Logical Disk, RAID 0)
		### /dev/sde (Single-Drive Logical Disk, RAID 0)
		##
		#	
		
		#printf 'y\n'|hpssacli ctrl slot=${ctl} create type=ld drives=1I:1:1 raid=0 stripsize=128
		#printf 'y\n'|hpssacli ctrl slot=${ctl} create type=ld drives=1I:1:2 raid=0 stripsize=128
		#printf 'y\n'|hpssacli ctrl slot=${ctl} create type=ld drives=1I:1:3 raid=0 stripsize=128
		#printf 'y\n'|hpssacli ctrl slot=${ctl} create type=ld drives=1I:1:4 raid=0 stripsize=128
		#printf 'y\n'|hpssacli ctrl slot=${ctl} create type=ld drives=2I:1:5 raid=0 stripsize=128
		
		
		
	fi
	printf "New config for Controller ${ctl} (${CTL_MODEL})\n" 2>&1
	hpssacli controller slot=${ctl} show config 2>&1
	unset HBA_ENABLED CTL_MODEL
done



printf "${0##*/} Complete\n" 2>&1
sleep 1


exit 0
