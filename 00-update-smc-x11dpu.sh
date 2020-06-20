#!/bin/bash
# --- Start MAAS 1.0 script metadata ---
# name: 01-supermicro-x11dpu-bios-n-firmware
# title: SMC X11DPU Update   
# description: Update BMC and BIOS on X11DPU motherboards
# type: commissioning
# script_type: commissioning
# tags: update_firmware
# recommission: False
# destructive: False
# hardware_type: node
# for_hardware: mainboard_product:X11DPU
# may_reboot: True
# --- End MAAS 1.0 script metadata ---


#    MAAS Commissioning Script
##
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
sleep 1

#root check
[[ $EUID -eq 0 ]] || { printf "\nThis script requires admin privileges.\n\n";exit 1; }


### Script Parameters

# Args for wget
export WGETARGS="-q --retry-connrefused --waitretry=1 --timeout=25 --tries=5 --no-dns-cache"

# Args for curl
export CARGS='-slSL --connect-timeout 5 --max-time 25 --retry 5 --retry-delay 1'

# Supermicro motherboard
export SMC_MOBO=X11DPU

# Directory to extract files/utils
export SMC_DIR='/opt/smc'

# Firmware URL Update the URLs below to keep script current
export SMC_FW_URL='https://www.supermicro.com/Bios/softfiles/11674/X11DPU_3_3_AST17111_SUM240.zip'

printf "\nConfirming this is a Super Micro Computer Inc ${SMC_MOBO} baseboard:\n\n" 2>&1
dmidecode -t baseboard|awk '/Product Name:/{print $NF}'
[[ $(dmidecode -t baseboard|awk '/Product Name:/{print $NF}') = ${SMC_MOBO} ]] && { printf "\n\nDetected Super Micro Computer Inc ${SMC_MOBO} baseboard, continuing...\n" 2>&1; } || { printf "\n\nDid not detect Super Micro Computer Inc ${SMC_MOBO} baseboard, exiting.\n" 2>&1;exit 0; }

# Download unzip if needed
[[ $(command -v unzip) ]] && { printf "\nPackage \"unzip\" already installed.  Continuing...\n" 2>&1; } || { printf "Running apt update:\n\n" 2>&1;apt update;printf "Installing unzip:\n\n" 2>&1;apt install -y  unzip; }

# Create directory and download FW files
[[ -d ${SMC_DIR} ]] || { printf "\nCreating ${SMC_DIR} directory:..." 2>&1;mkdir -p ${SMC_DIR}; }
cd ${SMC_DIR}
printf "\nDownloading ${SMC_FW_URL##*/} from ${SMC_FW_URL%/*}..." 2>&1
[[ -f ${SMC_DIR}/${SMC_FW_URL##*/} ]] && rm -rf ${SMC_DIR}/${SMC_FW_URL##*/}
wget ${WGETARGS} -O /tmp/${SMC_FW_URL##*/} ${SMC_FW_URL}
#curl ${CARGS} -o /tmp/${SMC_FW_URL##*/} ${SMC_FW_URL}


[[ $? -eq 0 && -f /tmp/${SMC_FW_URL##*/} ]] && { printf "\nSuccessfully downloaded ${SMC_FW_URL##*/} from ${SMC_FW_URL%/*}! \n\n";export SMC_FW_ZIP="/tmp/${SMC_FW_URL##*/}"; } || { printf "\n\nCould not download ${SMC_FW_URL##*/} from ${SMC_FW_URL%/*}! \n\nPlease check the URL for updates.\n\nExiting.\n" 2>&1;exit 0; }

printf "Creating purpose-named directories: \n\n$(eval printf '\\\e[2G-%s\\\n' ${SMC_DIR}/{bmc,bios,sum})\n" 2>&1
mkdir -p ${SMC_DIR}/{bmc,bios,sum}

# Set variables for purpose-named directories
printf "\nSetting variables for purpose-named directories...\n" 2>&1
eval $(printf '%s\n' {bmc,bios,sum}|xargs -rn1 -P0 bash -c 'echo export SMC_${0^^}_DIR=${SMC_DIR}/${0}')

# Set variables based on zip file contents
printf "\nSetting variables for purpose-named zip files contained in ${SMC_FW_ZIP}:\n\n" 2>&1
eval \
	$(awk '{ if (/^SMT.*AST/) print "export SMC_BMC_ZIP=\"opt/smc/"$1"\""; if (/^sum/) print "export SMC_SUM_ZIP=\"/opt/smc/"$1"\"";if (/^X11DPU/) print "export SMC_BIOS_ZIP=\"/opt/smc/"$1"\""}' \
	< <((unzip -l ${SMC_FW_ZIP}|awk '!/^Archive|Name|file|^-/{print $NF}')))

# Set the path to include smc util directories
printf "\nAdding purpose-named directories to \$PATH:\n\n" 2>&1
export PATH=$(printf '%s\n' ${SMC_DIR}/{bmc,bios,sum}|paste -sd:):${PATH}
set|grep -E '^PATH*[^=]+'

# Extract purpose-named zips from main zip file and place in purpose-named directories
printf "\nExtracting purpose-named zip files from main zip file:\n\n" 2>&1
printf '%s\n' {bmc,bios,sum}|xargs -rn1 -P0 bash -c 'echo unzip -jqqo ${SMC_FW_ZIP} $(eval echo \${SMC_${0^^}_ZIP##*/}) -d ${SMC_DIR}/${0}/'
printf '%s\n' {bmc,bios,sum}|xargs -rn1 -P0 bash -c 'unzip -jqqo ${SMC_FW_ZIP} $(eval echo \${SMC_${0^^}_ZIP##*/}) -d ${SMC_DIR}/${0}/'

# Extract purpose-named zips to their respective directories
printf "\nExtracting purpose-named zip files into purpose-named directories:\n\n" 2>&1
printf '%s\n' {bmc,bios,sum}|xargs -rn1 -P0 bash -c 'echo unzip -qqo ${SMC_DIR}/${0}/$(eval echo \${SMC_${0^^}_ZIP##*/}) -d ${SMC_DIR}/${0}/'
printf '%s\n' {bmc,bios,sum}|xargs -rn1 -P0 bash -c 'unzip -qqo ${SMC_DIR}/${0}/$(eval echo \${SMC_${0^^}_ZIP##*/}) -d ${SMC_DIR}/${0}/'

printf "\nSetting variable for Supermicro Update Manager (sum)\n" 2>&1
export SMC_SUM_BIN=$(find ${SMC_SUM_DIR} -type f -executable -iname "*sum*")
set|grep -E '^SMC_SUM_B[^=]+'

# Look for any tgz files that need extracting (e.g. sum)
printf "\nSearching for tarballs that may need extracting...\n\n" 2>&1
printf '%s\n' {bmc,bios,sum}|xargs -rn1 -P0 -I@ find ${SMC_DIR}/@ -type f -iname "sum*linux*.gz" -exec tar --strip-components=1 -xzf {} -C ${SMC_DIR}/@ \;

printf "\nLocating BIOS Image File:\n\n" 2>&1
export SMC_BIOS_IMAGE=$(find ${SMC_BIOS_DIR} -type f -regextype "posix-extended" -iregex ".*(${SMC_MOBO}.*\.[0-9]{3}+)")
set|grep -E '^SMC_BIOS_I[^=]+'

printf "\nLocating BMC Image File:\n\n" 2>&1
export SMC_BMC_IMAGE=$(find ${SMC_BMC_DIR} -type f -regextype "posix-extended" -iregex ".*(SMT_.*.AST.*\.bin)")
set|grep -E '^SMC_BMC_I[^=]+'

# Show variable that start with SMC
printf "\nShowing all SMC_ variables:\n\n" 2>&1
set|grep -E '^SMC_*[^=]+'

printf "\nChecking if BMC needs updating.  Please wait...\n\n" 2>&1
export SMC_BMC_OUTPUT="$(${SMC_SUM_BIN} -c GetBmcinfo --file ${SMC_BMC_IMAGE})"
export UPDATE_BMC=$(echo "${SMC_BMC_OUTPUT}"|awk '{gsub(/[.]+/," ");if (/Managed system:/) next;if (/BMC version/) CUR_BMC=$NF;if (/Local BMC image file:/) next;if (/BMC version/) NEW_BMC=$NF} END {if (CUR_BMC==NEW_BMC) print "false:"CUR_BMC":"NEW_BMC;else print "true:"CUR_BMC":"NEW_BMC}')
export CUR_BMC_VER="$(echo ${UPDATE_BMC%:*}|awk -F":" '{print $2}')"
export NEW_BMC_VER=${UPDATE_BMC##*:}
export SMC_UPDATE_BMC=${UPDATE_BMC%%:*}
[[ ${SMC_UPDATE_BMC} = true ]] && { printf "\e[1;38;2;255;200;0mBMC Needs updating! \e[0m\n\e[2G - \e[1mCurrent BMC Version:\e[0m\e[30G\e[38;2;255;0;0m${CUR_BMC_VER}\e[0m\n\e[2G - \e[1mNew BMC Version:\e[0m\e[30G\e[38;2;0;255;0m${NEW_BMC_VER}\e[0m\n" 2>&1; }
[[ ${SMC_UPDATE_BMC} = false ]] && { printf "\e[1;38;2;0;255;0mBMC is up-to-date! \e[0m\n\e[2G - \e[1mCurrent BMC Version:\e[0m\e[30G\e[38;2;0;255;0m${CUR_BMC_VER}\e[0m\n\e[2G - \e[1mNew BMC Version:\e[0m\e[30G\e[38;2;0;255;0m${NEW_BMC_VER}\e[0m\n" 2>&1; }

[[ ${SMC_UPDATE_BMC} = true ]] && { printf "\nUpdating BMC.  Please wait...\n\n" 2>&1;${SMC_SUM_BIN} -c UpdateBmc --file ${SMC_BMC_IMAGE}; } || { printf "\nSkipping BMC Update\n" 2>&1; }

printf "\nChecking if BIOS needs updating.  Please wait...\n" 2>&1
export SMC_BIOS_OUTPUT="$(${SMC_SUM_BIN} -c GetBiosinfo --file ${SMC_BIOS_IMAGE})"
export UPDATE_BIOS=$(echo "${SMC_BIOS_OUTPUT}"|awk '{gsub(/[.]+/," ");if (/Managed system:/) next;if (/BIOS build date/) CUR_BIOS=$NF;if (/Local BIOS image file:/) next;if (/BIOS build date/) NEW_BIOS=$NF} END {if (CUR_BIOS==NEW_BIOS) print "false:"CUR_BIOS":"NEW_BIOS;else print "true:"CUR_BIOS":"NEW_BIOS}')
export CUR_BIOS_DATE="$(echo ${UPDATE_BIOS%:*}|awk -F":" '{print $2}')"
export NEW_BIOS_DATE=${UPDATE_BIOS##*:}
export SMC_UPDATE_BIOS=${UPDATE_BIOS%%:*}
[[ ${SMC_UPDATE_BIOS} = true ]] && { printf "\e[1;38;2;255;200;0mBIOS Needs updating! \e[0m\n\e[2G - \e[1mCurrent BIOS Build Date:\e[0m\e[30G\e[38;2;255;0;0m${CUR_BIOS_DATE}\e[0m\n\e[2G - \e[1mNew BIOS Build Date:\e[0m\e[30G\e[38;2;0;255;0m${NEW_BIOS_DATE}\e[0m\n" 2>&1; }
[[ ${SMC_UPDATE_BIOS} = false ]] && { printf "\e[1;38;2;0;255;0mBIOS is up-to-date! \e[0m\n\e[2G - \e[1mCurrent BIOS Build Date:\e[0m\e[30G\e[38;2;0;255;0m${CUR_BIOS_DATE}\e[0m\n\e[2G - \e[1mNew BIOS Build Date:\e[0m\e[30G\e[38;2;0;255;0m${NEW_BIOS_DATE}\e[0m\n" 2>&1; }

[[ ${SMC_UPDATE_BMC} = true ]] && { printf "\nUpdating BIOS.  Unit will reboot! Please wait...\n" 2>&1;${SMC_SUM_BIN} -c UpdateBios --file ${SMC_BIOS_IMAGE} --reboot; } || { printf "\nSkipping BIOS Update\n" 2>&1; }

printf "\n\e[38;2;0;255;0m${0##*/} Complete! \e[0mExiting\n\n\n"
exit 0