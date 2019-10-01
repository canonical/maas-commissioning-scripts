#!/bin/bash
# --- Start MAAS 1.0 script metadata ---
# name: 01-connectx5-01-fwupdate
# title: Configure Mellanox MCX516A-CCA_Ax NICs
# description: Update firmware, enable features on Mellanox MCX516A-CCA_Ax NICs
# type: commissioning
# script_type: commissioning
# tags: commissioning
# recommission: True
# destructive: False
# hardware_type: node
# for_hardware: pci:15b3:1017
# may_reboot: True
# --- End MAAS 1.0 script metadata ---


#    Foundation Cloud Infrastructure Script
#
#    This script updates the firmware, including the FlexBoot ROM image
#
#    Copyright (C) 2018 Canonical Ltd.
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


#root check
[[ $EUID -eq 0 ]] || { printf "\nThis script requires admin privileges.\n\n";exit 1; }


### Update the four URLs below to keep script current

# Firmware URL
export MLX_FW_URL='http://www.mellanox.com/downloads/firmware/fw-ConnectX5-rel-16_24_1000-MCX516A-CCA_Ax-UEFI-14.17.11-FlexBoot-3.5.603.bin.zip'
# Firmware Tools URL
export MLX_FT_URL='http://www.mellanox.com/downloads/MFT/mft-4.11.0-103-x86_64-deb.tgz'
# Mellanox Update util URL
export MLX_UP_URL='http://www.mellanox.com/downloads/firmware/mlxup/4.10.0/SFX/linux_x64/mlxup'
# Mellanox Driver URL
export MLX_EN_URL='http://www.mellanox.com/downloads/ofed/MLNX_EN-4.4-2.0.7.0/mlnx-en-4.4-2.0.7.0-ubuntu18.04-x86_64.tgz'


printf "Checking for presence of Mellanox ConnectX-5 card \n" 2>&1

#Exit if no Mellanox card are detected
[[ -z $(lspci -nn |grep -iE 'mell.*connectx-5') ]] && { printf "No Mellanox ConnectX-5 cards detected, exiting.\n" 2>&1;exit 0; }


export MLX_DIR='/opt/mellanox'
export WGETARGS="--retry-connrefused --waitretry=1 --timeout=25 --tries=5 --no-dns-cache"


printf "Running apt update\n" 2>&1
apt update
printf "Installing build-essential, dkms, and unzip\n" 2>&1
apt install -y build-essential linux-headers-$(uname -r) dkms unzip
printf "Creating ${MLX_DIR} directory\n" 2>&1
mkdir -p ${MLX_DIR}
cd ${MLX_DIR}
for M in ${MLX_FW_URL} ${MLX_FT_URL} ${MLX_UP_URL} ${MLX_EN_URL};do
        printf "Downloading ${M##*/} \n" 2>&1
        [[ -f ${MLX_DIR}/${M##*/} ]] && rm -rf ${MLX_DIR}/${M##*/}
        wget ${WGETARGS} -qO ${MLX_DIR}/${M##*/} ${M}
done



printf "Setting execute perms on ${MLX_DIR}/${MLX_UP_URL##*/} \n" 2>&1
chmod +x ${MLX_DIR}/${MLX_UP_URL##*/}
printf "Unzipping Firmware ${MLX_DIR}/${MLX_FW_URL##*/} \n" 2>&1
unzip -qqo ${MLX_DIR}/${MLX_FW_URL##*/}
printf "Extracting FW Tools ${MLX_DIR}/${MLX_FT_URL##*/} \n" 2>&1
tar -xzvf ${MLX_DIR}/${MLX_FT_URL##*/}
printf "Extracting Drivers ${MLX_DIR}/${MLX_EN_URL##*/} \n" 2>&1
tar -xzvf ${MLX_DIR}/${MLX_EN_URL##*/}

printf "Installing FW Tools \n" 2>&1
export FT_DIR=$(echo ${MLX_FT_URL##*/}|sed 's/.tgz//g')
${MLX_DIR}/${FT_DIR}/install.sh
printf "Starting MST... \n" 2>&1
mst start
mst status

printf "Updating all Mellanox ConnectX-5 cards to (echo ${MLX_FW_URL##*/}|sed 's/.zip//g') \n" 2>&1
${MLX_DIR}/mlxup -uy -D ${MLX_DIR}


# See http://www.mellanox.com/related-docs/MFT/MFT_User_Manual_v4_11_0.pdf
# for configuration Values

MST_DEV_P1=$(mst status|awk '/mst.mt/{print $1}')
MST_DEV_P2="${MST_DEV_P1}.1"

for D in $(lspci|awk '/Mellanox.*ConnectX-5/{print $1}');do
	printf "\e[1mConfiguring Mellanox ConnectX-5 Device \"${D}\"\e[0m\n\n" 2>&1
	printf "Setting Link Type to Ethernet and when Link should be up\n" 2>&1|fold -w70 -s
	/usr/bin/mlxconfig -y -d ${D} set LINK_TYPE_P1=ETH LINK_TYPE_P2=ETH KEEP_ETH_LINK_UP_P1=1 KEEP_LINK_UP_ON_BOOT_P1=1 KEEP_ETH_LINK_UP_P2=1 KEEP_LINK_UP_ON_BOOT_P2=1

	printf "Setting IP version for PXE/UEFI boot. 2 = Default to IPv4 then IPv6 (IPv6 only if IPv4 fails)\n" 2>&1|fold -w70 -s
	/usr/bin/mlxconfig -y -d ${D} set IP_VER=2 IP_VER_P1=2 IP_VER_P2=2
	
	printf "Setting Boot Options.  BOOT_VLAN should be zero for all environments other than Cisco\n"|fold -w70 -s
	/usr/bin/mlxconfig -y -d ${D} set BOOT_VLAN_P1=0 BOOT_VLAN_P2=0 BOOT_RETRY_CNT1=1 BOOT_RETRY_CNT_P1=1 BOOT_RETRY_CNT_P2=1 BOOT_LACP_DIS=1 BOOT_VLAN_EN=0 BOOT_VLAN_EN_P1=0 BOOT_VLAN_EN_P2=0 BOOT_UNDI_NETWORK_WAIT=30

	printf "Enabling Expansion ROM and passing and enabling configuration of PXE and UEFI boot options through host's BIOS\n"|fold -w70 -s
	/usr/bin/mlxconfig -y -d ${D} set EXP_ROM_UEFI_x86_ENABLE=1 EXP_ROM_PXE_ENABLE=1 EXP_ROM_UEFI_ARM_ENABLE=1 BOOT_OPTION_ROM_EN=1 BOOT_OPTION_ROM_EN_P1=1 BOOT_OPTION_ROM_EN_P2=1 LEGACY_BOOT_PROTOCOL=4 LEGACY_BOOT_PROTOCOL_P1=4 LEGACY_BOOT_PROTOCOL_P2=4 UEFI_HII_EN=1 UEFI_HII_EN_P1=1 UEFI_HII_EN=1
done

exit 0
