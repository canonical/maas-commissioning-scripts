#!/bin/bash
# --- Start MAAS 1.0 script metadata ---
# name: 01-hp-bios-01-update
# title: HP iLO Configuration
# description: Update Firmware settings on HP Servers
# type: commissioning
# script_type: commissioning
# tags: commissioning
# destructive: False
# hardware_type: node
# may_reboot: True
# recommission: True
# --- End MAAS 1.0 script metadata ---

# Note: this requires that the HP SDR/ILO Rest Repos are available under MAAS Repositories 
# If they are not available via MAAS Repos, uncomment the following lines:
#
# (curl 2>/dev/null -sSlL \
#   https://downloads.linux.hpe.com/SDR/hpPublicKey1024.pub \
#   https://downloads.linux.hpe.com/SDR/hpPublicKey2048.pub \
#   https://downloads.linux.hpe.com/SDR/hpPublicKey2048_key1.pub \
#   https://downloads.linux.hpe.com/SDR/hpePublicKey2048_key1.pub) | \
#   apt-key add -

# echo 'deb [arch=amd64] http://downloads.linux.hpe.com/SDR/repo/mcp '$(lsb_release -sc)'/current non-free'|tee /etc/apt/sources.list.d/hp-mcp-$(lsb_release -sc).list
# echo 'deb [arch=amd64] http://downloads.linux.hpe.com/SDR/repo/ilorest '$(lsb_release -sc)'/current non-free'|tee /etc/apt/sources.list.d/hp-ilortest-$(lsb_release -sc).list
# [[ $? -eq 0 ]] && apt update
#
# --- End MAAS 1.0 script metadata ---


#    MAAS Commissioning Script 
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


#root check
[[ $EUID -eq 0 ]] || { printf "\nThis script requires admin privileges.\n\n";exit 1; }
#install check
printf "\e[2GRunning apt update..." 2>&1
apt update -qq 2>&1
printf "\e[2G - Installing packages..." 2>&1
DEBIAN_FRONTEND=noninteractive apt install ilorest -yq 2>&1
command -v ilorest > /dev/null 2>&1 || { printf "hp ilorest tool failed to install\n" 2>&1;exit 1; }

# Download fwpkg file
#wget -O /tmp/file_name.fwpkg http://url/file_name.fwpkg
#ilorest flashfwpkg /tmp/file_name.fwpkg


