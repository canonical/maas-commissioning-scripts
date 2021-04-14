#!/bin/bash -x
# --- Start MAAS 1.0 script metadata ---
# name: 01-dell-01-openmanage-repos
# title: Dell OpenManage Repos for PowerEdge Servers 
# description: BMC Configuration Tools 
# script_type: commissioning
# tags: Run
# for_hardware: mainboard_product:00WGD1
# may_reboot: True
# recommission: True
# --- End MAAS 1.0 script metadata ---

# THat board ID is for a 740, but double check if later 740's match

# Get GPG-key for Dell Open Manager Repos
sudo apt-key adv --keyserver pool.sks-keyservers.net --recv-keys 1285491434D8786F

# Install the right repo based on Ubuntu release

if [[ $(lsb_release -sc) = focal ]];then
	echo "deb [arch=amd64] https://linux.dell.com/repo/community/openmanage/950/$(lsb_release -sc) $(lsb_release -sc) main"|sudo tee /etc/apt/sources.list.d/dell-openmanage-$(lsb_release -sc).list
elif [[ $(lsb_release -sc) = bionic ]];then
	echo "deb [arch=amd64] https://linux.dell.com/repo/community/openmanage/920/$(lsb_release -sc) $(lsb_release -sc) main"|sudo tee /etc/apt/sources.list.d/dell-openmanage-$(lsb_release -sc).list
elif [[ $(lsb_release -sc) = xenial ]];then
	echo "deb [arch=amd64] https://linux.dell.com/repo/community/openmanage/911/$(lsb_release -sc) $(lsb_release -sc) main"|sudo tee /etc/apt/sources.list.d/dell-openmanage-$(lsb_release -sc).list
fi

[[ $? -eq 0 ]] && sudo apt update


apt install apt-transport-https build-essential dkms -y
apt install srvadmin-all -y

## FROM HERE We should be able to do racadm commands without credentials
## Just remember to "submit a job" or the changes will remain pending.