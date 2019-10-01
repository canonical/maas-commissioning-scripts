#!/bin/bash -x
# --- Start MAAS 1.0 script metadata ---
# name: 02-dell-02-firmware-update
# title: BIOS Update for PowerEdge R740xd 
# description: Firmware Update 
# script_type: commissioning
# tags: update_firmware update_firmware_bios update_firmware_nvme update_firmware_idrac update_firmware_cpld update_firmware_sas
# packages:
#  url: https://downloads.dell.com/FOLDER05328929M/1/BIOS_CVHH4_LN_1.6.12.BIN
#  url: https://downloads.dell.com/FOLDER05352961M/1/iDRAC-with-Lifecycle-Controller_Firmware_FDMV1_LN_3.21.26.22_A00.BIN
#  url: https://downloads.dell.com/FOLDER05313029M/1/CPLD_Firmware_PC0N3_LN_1.0.6_A00.BIN
#  url: https://downloads.dell.com/FOLDER05152843M/2/Express-Flash-PCIe-SSD_Firmware_KNW4M_LN64_QDV1DP15_A02_01.BIN
#  url: https://downloads.dell.com/FOLDER05319759M/1/SAS-RAID_Firmware_MKV82_LN64_2.5.13.3016_A04.BIN
#  url: https://downloads.dell.com/FOLDER05244202M/1/Network_Firmware_YHF9V_LN_18.8.9_A00.BIN
# for_hardware: mainboard_product:00WGD1
# may_reboot: True
# recommission: True
# --- End MAAS 1.0 script metadata ---

# Note: this requires that the Dell OpenManage Repos are available under MAAS Repositories 
# If they are not available via MAAS Repos, uncomment the following lines:
#
# sudo apt-key adv --keyserver pool.sks-keyservers.net --recv-keys 1285491434D8786F
# if [[ $(lsb_release -sc) = bionic ]];then
# 	echo "deb http://linux.dell.com/repo/community/openmanage/920/$(lsb_release -sc) $(lsb_release -sc) main"|sudo tee /etc/apt/sources.list.d/dell-openmanage-$(lsb_release -sc).list
# elif [[ $(lsb_release -sc) = xenial ]];then
# 	echo "deb http://linux.dell.com/repo/community/openmanage/911/$(lsb_release -sc) $(lsb_release -sc) main"|sudo tee /etc/apt/sources.list.d/dell-openmanage-$(lsb_release -sc).list
# fi
# [[ $? -eq 0 ]] && sudo apt update
#

apt install build-essential dkms srvadmin-all

# BIOS - No reboot given to BIN (-r).  Wait until last update.
# Make self extracting package executable
chmod +x $DOWNLOAD_PATH/BIOS_CVHH4_LN_1.6.12.BIN
# Make sure we can/should run this update
$DOWNLOAD_PATH/BIOS_CVHH4_LN_1.6.12.BIN -qc
if [[ $? -eq 0 ]];then
	$DOWNLOAD_PATH/BIOS_CVHH4_LN_1.6.12.BIN -qn
fi


# iDRAC - No reboot given to BIN (-r).  Wait until last update.
# Make self extracting package executable
chmod +x $DOWNLOAD_PATH/iDRAC-with-Lifecycle-Controller_Firmware_FDMV1_LN_3.21.26.22_A00.BIN
# Make sure we can/should run this update
$DOWNLOAD_PATH/iDRAC-with-Lifecycle-Controller_Firmware_FDMV1_LN_3.21.26.22_A00.BIN -qc
if [[ $? -eq 0 ]];then
	$DOWNLOAD_PATH/iDRAC-with-Lifecycle-Controller_Firmware_FDMV1_LN_3.21.26.22_A00.BIN -qn
fi

# NVME - No reboot given to BIN (-r).  Wait until last update.
# Make self extracting package executable
chmod +x $DOWNLOAD_PATH/Express-Flash-PCIe-SSD_Firmware_KNW4M_LN64_QDV1DP15_A02_01.BIN
# Make sure we can/should run this update
$DOWNLOAD_PATH/Express-Flash-PCIe-SSD_Firmware_KNW4M_LN64_QDV1DP15_A02_01.BIN -qc
if [[ $? -eq 0 ]];then
	$DOWNLOAD_PATH/Express-Flash-PCIe-SSD_Firmware_KNW4M_LN64_QDV1DP15_A02_01.BIN -qn
fi

#SAS - No reboot given to BIN (-r).  Wait until last update.
# Make self extracting package executable
chmod +x $DOWNLOAD_PATH/SAS-RAID_Firmware_MKV82_LN64_2.5.13.3016_A04.BIN
# Make sure we can/should run this update
$DOWNLOAD_PATH/SAS-RAID_Firmware_MKV82_LN64_2.5.13.3016_A04.BIN -qc
if [[ $? -eq 0 ]];then
	$DOWNLOAD_PATH/SAS-RAID_Firmware_MKV82_LN64_2.5.13.3016_A04.BIN -qn
fi

# CPLD - No reboot given to BIN (-r).  Wait until last update.
# Make self extracting package executable
chmod +x $DOWNLOAD_PATH/CPLD_Firmware_PC0N3_LN_1.0.6_A00.BIN
# Make sure we can/should run this update
$DOWNLOAD_PATH/CPLD_Firmware_PC0N3_LN_1.0.6_A00.BIN -qc
if [[ $? -eq 0 ]];then
	$DOWNLOAD_PATH/CPLD_Firmware_PC0N3_LN_1.0.6_A00.BIN -qn
fi

# NIC - Reboot.  Add reboot flag (-r) since it's our last update
# Make self extracting package executable
chmod +x $DOWNLOAD_PATH/Network_Firmware_YHF9V_LN_18.8.9_A00.BIN
# Make sure we can/should run this update
$DOWNLOAD_PATH/Network_Firmware_YHF9V_LN_18.8.9_A00.BIN -qc
if [[ $? -eq 0 ]];then
	$DOWNLOAD_PATH/Network_Firmware_YHF9V_LN_18.8.9_A00.BIN -qnr
fi


exit 0