#!/bin/bash
# --- Start MAAS 1.0 script metadata ---
# name: 01-connectx4_smc_S100G-01-fwupdate
# title: Super Micro Computer Inc MT27700 [ConnectX-4]   
# description: Update firmware, enable features on Super Micro Computer Inc MT27700 Family [ConnectX-4] (SMC OEM of Mellanox ConnectX-4)
# type: commissioning
# script_type: commissioning
# tags: commissioning, AOC-S100G-m2C, MT27700
# recommission: False
# destructive: False
# hardware_type: node
# for_hardware: pci:15b3:1013
# may_reboot: True
# --- End MAAS 1.0 script metadata ---


#    MAAS Commissioning Script
#
#    This script updates the firmware, including the FlexBoot ROM image
#
#    Copyright (C) 2020 Canonical Ltd.
#
#    Author(s): Craig Bender <craig.bender@canonical.com>
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

# Banner
echo 'ICAgICAgICAgICAgICAgICAgICAgICAgICAgICA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQogICAgICAgICAgICAgICAgICAgICAgICAgICAgID0gID09PT09ICA9PT09PSAgPT09PT09PT0gID09PT09PSAgICAgID09CiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgPSAgID09PSAgID09PT0gICAgPT09PT09ICAgID09PT0gID09PT0gID0KICAgICAgICAgICAgICAgICAgICAgICAgICAgICA9ICA9ICAgPSAgPT09ICA9PSAgPT09PSAgPT0gID09PSAgPT09PSAgPQogICAgICAgICAgICAgICAgICAgICAgICAgICAgID0gID09ID09ICA9PSAgPT09PSAgPT0gID09PT0gID09PSAgPT09PT09CiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgPSAgPT09PT0gID09ICA9PT09ICA9PSAgPT09PSAgPT09PT0gID09PT0KICAgICAgICAgICAgICAgICAgICAgICAgICAgICA9ICA9PT09PSAgPT0gICAgICAgID09ICAgICAgICA9PT09PT09ICA9PQogICAgICAgICAgICAgICAgICAgICAgICAgICAgID0gID09PT09ICA9PSAgPT09PSAgPT0gID09PT0gID09ICA9PT09ICA9CiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgPSAgPT09PT0gID09ICA9PT09ICA9PSAgPT09PSAgPT0gID09PT0gID0KICAgICAgICAgICAgICAgICAgICAgICAgICAgICA9ICA9PT09PSAgPT0gID09PT0gID09ICA9PT09ICA9PT0gICAgICA9PQogICAgICAgICAgICAgICAgICAgICAgICAgICAgID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIO+8o++9j++9je+9je+9ie+9k++9k++9ie+9j++9ju+9ie+9ju+9hyAg772T772D772S772J772Q772UCg=='|base64 -d


#root check
[[ $EUID -eq 0 ]] || { printf "\nThis script requires admin privileges.\n\n";exit 1; }


### Update the three URLs below to keep script current

# Firmware URL
export MLX_FW_URL='https://www.supermicro.com/wftp/Firmware/Mellanox/AOC-S100G-m2C/S100G1C.zip'
# Firmware Tools URL
export MLX_FT_URL='https://www.mellanox.com/downloads/MFT/mft-4.14.4-6-x86_64-deb.tgz'
# Mellanox Update util URL
export MLX_UP_URL='http://www.mellanox.com/downloads/firmware/mlxup/4.14.4/SFX/linux_x64/mlxup'

printf "Checking for presence of Super Micro Computer Inc MT27700 Family [ConnectX-4] cards\n" 2>&1

#Exit if no Mellanox card are detected
[[ -z $(lspci -nn |grep -iE 'mell.*connectx-4') ]] && { printf "No Super Micro Computer Inc MT27700 Family [ConnectX-4] cards detected, exiting.\n" 2>&1;exit 0; }


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
printf "Getting FW Filename from ${MLX_DIR}/${MLX_FW_URL##*/} \n" 2>&1
export FW_BIN_NAME=$(unzip -l ${MLX_DIR}/${MLX_FW_URL##*/} |awk '/bin/{print $NF}')
printf "Unzipping Firmware file from ${MLX_DIR}/${MLX_FW_URL##*/} \n" 2>&1
unzip -jqqo ${MLX_DIR}/${MLX_FW_URL##*/} ${FW_BIN_NAME} -d ${MLX_DIR}
export FW_BIN=${MLX_DIR}/${FW_BIN_FILE##*/}
printf "Extracting FW Tools ${MLX_DIR}/${MLX_FT_URL##*/} \n" 2>&1
tar -xzvf ${MLX_DIR}/${MLX_FT_URL##*/}

printf "Installing FW Tools (with --oem option) \n" 2>&1
export FT_DIR=$(echo ${MLX_FT_URL##*/}|sed 's/.tgz//g')
${MLX_DIR}/${FT_DIR}/install.sh --oem
printf "Starting MST... \n" 2>&1
mst start
mst status

printf "Updating all Super Micro Computer Inc MT27700 Family [ConnectX-4] cards\n" 2>&1
${MLX_DIR}/mlxup -uy -D ${MLX_DIR}

# See http://www.mellanox.com/related-docs/MFT/MFT_User_Manual_v4_11_0.pdf
# for configuration Values

# Get MST Device IDs
MST_DEV_P1=$(mst status|awk '/mst.mt/{print $1}')
MST_DEV_P2="${MST_DEV_P1}.1"

# Update features/settings
# See http://www.mellanox.com/related-docs/MFT/MFT_User_Manual_v4_11_0.pdf
# for configuration Values

for D in $(lspci|awk '/Mellanox.*ConnectX-4/{print $1}');do
	printf "Configuring Links To Stay Up to reduce POST time\n" 2>&1|fold -w70 -s
	/usr/bin/mlxconfig -y -d ${D} set KEEP_ETH_LINK_UP_P1=1 KEEP_LINK_UP_ON_BOOT_P1=1 KEEP_ETH_LINK_UP_P2=1 KEEP_LINK_UP_ON_BOOT_P2=1

	printf "Enabling UEFI HII Menus to allow configuration under Machine setup menu\n"|fold -w70 -s
	/usr/bin/mlxconfig -y -d ${D} set UEFI_HII_EN=1
done

exit 0
