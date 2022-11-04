#!/usr/bin/env bash
#
# 40-maas-01-dhcp-lease-info.sh - Get DHCP lease information for all interfaces
#
# Copyright (C) 2022 Canonical
# Author: craig.bender@caonical.com
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# --- Start MAAS 1.0 script metadata ---
# name: 40-maas-01-dhcp-lease-info
# title: DHCP Lease Information
# description: Get DHCP Lease information for all interfaces
# script_type: commissioning
# timeout: 5
# --- End MAAS 1.0 script metadata ---

# Runs `/usr/sbin/netplan ip leases $iface` on all the physical interfaces
# This is done to validate that 1) MAAS if providing DHCP, 2) Ensure the correct DNS
# information is supplied to the client, and if applicable, 3) Validate any MAAS
# dhcpsnippets (such as increasing the lifetime for lease during PXE booting.

for NIC in $(/usr/bin/find /sys/class/net -type l ! -lname "*virtual*" -printf '%P\n'|sort -uV);do
	printf "\n\n${NIC}\n${NIC//[a-z0-9]/=}\n";/usr/sbin/netplan ip leases ${NIC};
done
exit 0
