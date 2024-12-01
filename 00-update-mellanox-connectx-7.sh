#!/bin/bash
# --- Start MAAS 1.0 script metadata ---
# name: 01-connectx-7-fwupdate
# title: Configure Mellanox MT2910 NICs
# description: Update firmware, enable features on Mellanox MT2910 NICs
# type: commissioning
# script_type: commissioning
# tags: commissioning
# recommission: True
# destructive: False
# hardware_type: network
# for_hardware: pci:15b3:1021
# may_reboot: True
# --- End MAAS 1.0 script metadata ---

#    Foundation Cloud Infrastructure Script
#
#    This script updates the firmware, including the FlexBoot ROM image
#
#    Copyright (C) 2024 Canonical Ltd.
#
#    Authors: Craig Bender <craig.bender@canonical.com>
#             Florian Berchtold <florian.berchtold@gmail.com>
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

# root check
[[ $EUID -eq 0 ]] || {
	echo -e "\nThis script requires admin privileges.\n\n"
	exit 1
}

set -euo pipefail

### Update the four URLs below to keep script current
# https://network.nvidia.com/products/adapter-software/firmware-tools/

if [[ $(uname -m) == "x86_64" ]]; then
	export MLX_FT_URL=https://www.mellanox.com/downloads/MFT/mft-4.30.0-139-x86_64-deb.tgz
	export MLX_UP_URL=https://www.mellanox.com/downloads/firmware/mlxup/4.30.0/SFX/linux_x64/mlxup
elif [[ $(uname -m) == "aarch64" ]]; then
	export MLX_FT_URL=https://www.mellanox.com/downloads/MFT/mft-4.30.0-139-arm64-deb.tgz
	export MLX_UP_URL=https://www.mellanox.com/downloads/firmware/mlxup/4.30.0/SFX/linux_arm64/mlxup
else
	echo "Unsupported architecture: $(uname -m)"
	exit 1
fi

echo "Checking for presence of Mellanox ConnectX-6 card"

lspci -nn | grep -iqE 'mell.*connectx-7' || {
	echo "No Mellanox ConnectX-7 cards detected, exiting."
	exit 0
}

export MLX_DIR='/opt/mellanox'
export WGETARGS=(--retry-connrefused --waitretry=1 --timeout=25 --tries=5 --no-dns-cache)

echo "Running apt update"
apt update
echo "Installing build-essential, dkms, and unzip"
apt install -y build-essential "linux-headers-$(uname -r)" dkms unzip
echo "Creating ${MLX_DIR} directory"
mkdir -p ${MLX_DIR}
cd ${MLX_DIR}
for M in ${MLX_FT_URL} ${MLX_UP_URL}; do
	FILE=${M##*/}
	TARGET=${MLX_DIR}/$FILE
	echo "Downloading $FILE"
	[[ -f $TARGET ]] && rm -rf "$TARGET"
	wget "${WGETARGS[@]}" -qO "$TARGET" "${M}"
done

echo "Setting execute perms on ${MLX_DIR}/${MLX_UP_URL##*/}"
chmod +x ${MLX_DIR}/${MLX_UP_URL##*/}
echo "Extracting FW Tools ${MLX_DIR}/${MLX_FT_URL##*/}"
tar -xzvf ${MLX_DIR}/${MLX_FT_URL##*/}

echo "Installing FW Tools"
FT_DIR=${MLX_FT_URL##*/}
FT_DIR=${FT_DIR%.tgz}

"${MLX_DIR}/${FT_DIR}/install.sh"
echo "Starting MST..."
mst start
mst status

echo "Updating all Mellanox ConnectX cards to latest available"
${MLX_DIR}/mlxup -uy

for D in $(lspci | awk '/Mellanox.*ConnectX-/{print $1}'); do
	echo -e "\n\e[1mConfiguring Mellanox ConnectX-7 Device \"${D}\"\e[0m\n\n"
	echo "Setting Link Type to Ethernet and when Link should be up"
	/usr/bin/mlxconfig -y -d "${D}" set LINK_TYPE_P1=ETH LINK_TYPE_P2=ETH KEEP_ETH_LINK_UP_P1=1 KEEP_LINK_UP_ON_BOOT_P1=1 KEEP_ETH_LINK_UP_P2=1 KEEP_LINK_UP_ON_BOOT_P2=1

	echo "Setting IP version for PXE/UEFI boot. 2 = Default to IPv4 then IPv6 (IPv6 only if IPv4 fails)"
	/usr/bin/mlxconfig -y -d "${D}" set IP_VER=2

	echo "Setting Boot Options.  BOOT_VLAN should be zero for all environments other than Cisco"
	/usr/bin/mlxconfig -y -d "${D}" set BOOT_VLAN=0 BOOT_LACP_DIS=1 BOOT_VLAN_EN=0 BOOT_UNDI_NETWORK_WAIT=30

	echo "Enabling Expansion ROM and passing and enabling configuration of PXE and UEFI boot options through host's BIOS"
	/usr/bin/mlxconfig -y -d "${D}" set EXP_ROM_UEFI_x86_ENABLE=1 EXP_ROM_PXE_ENABLE=1 EXP_ROM_UEFI_ARM_ENABLE=1
done

exit 0
