#!/bin/bash

set -e

echo "BY INSTALLING THE SOFTWARE, YOU ARE AGREEING TO BE BOUND BY THE BlackBerry"
echo "Solution License Agreement which can be reviewed at www.blackberry.com/leg-"
echo "al/bbsla. IF YOU HAVE ANY QUESTIONS OR CONCERNS ABOUT THE TERMS OF THIS AG-"
echo "REEMENT, PLEASE CONTACT blackberry AT LEGALinfo@BLACKBERRY.COM. PLEASE READ"
echo "THIS DOCUMENT CAREFULLY BEFORE INSTALLING OR USING THE SOFTWARE."
echo "***************************************************************************"
echo

BIN="./host/linux-x86/bin"
IMG="./img"
FASTBOOT="fastboot"

echo "Note: If device is not in fastboot mode"
echo "Please switch to fastboot mode by holding the power and volume down key for 30s"
echo

# Detect device name
devname=$($FASTBOOT getvar device 2>&1 | grep device | sed 's/.*device://g' | tr -d '[:space:]')
if [ -z "$devname" ]; then
    echo "Failed to detect the device name"
    exit 1
fi

# Detect variant
dev_variant=$($FASTBOOT getvar variant 2>&1 | grep variant | sed 's/.*variant://g' | tr -d '[:space:]')
if [ -z "$dev_variant" ]; then
    echo "Failed to detect the device variant"
    exit 1
fi

if [ "$dev_variant" = "tmo" ] || [ "$dev_variant" = "cdma" ]; then
    dev_variant="global"
fi

# Detect subvariant
dev_subvariant=$($FASTBOOT getvar subvariant 2>&1 | grep subvariant | sed 's/.*subvariant://g' | tr -d '[:space:]')
devname_sig="$dev_subvariant"

if [ -z "$dev_subvariant" ]; then
    dev_subvariant="common"
fi

# User confirmation
read -rp "This script will wipe off all user data. Do you want to continue? [y/n]: " answer
case "$answer" in
    y|Y) ;;
    n|N) exit 0 ;;
    *) echo "Please enter y or n! Bye bye!!"; exit 1 ;;
esac

echo
$FASTBOOT oem securewipe
echo "It may take 5 to 15 minutes to securely wipe the device"
sleep 5

# Detect bootchain slot
slots=$($FASTBOOT getvar bootchain-slots 2>&1 | grep bootchain-slots | sed 's/.*bootchain-slots://g' | tr -d '[:space:]')
if [ -z "$slots" ]; then
    echo "Failed to detect bootchain slots."
    exit 1
fi

slot=${slots:1:1}

# Flash low-level partitions
$FASTBOOT flash tz_$slot        "$IMG/tz.mbn"

if [ "$dev_variant" = "cn" ]; then
    $FASTBOOT flash devcfg_$slot "$IMG/devcfg_cn.mbn"
else
    $FASTBOOT flash devcfg_$slot "$IMG/devcfg.mbn"
fi

$FASTBOOT flash rpm_$slot       "$IMG/rpm.mbn"
$FASTBOOT flash xbl_$slot       "$IMG/xbl.elf"
$FASTBOOT flash hyp_$slot       "$IMG/hyp.signed.mbn"
$FASTBOOT flash pmic_$slot      "$IMG/pmic.elf"
$FASTBOOT flash abl_$slot       "$IMG/abl.elf"
$FASTBOOT flash cmnlib_$slot    "$IMG/cmnlib.signed.mbn"
$FASTBOOT flash cmnlib64_$slot  "$IMG/cmnlib64.signed.mbn"
$FASTBOOT flash keymaster_$slot "$IMG/keymaster64.signed.mbn"
$FASTBOOT flash mdtpsecapp_$slot "$IMG/mdtpsecapp.signed.mbn"

$FASTBOOT oem switch-bootchain:$slot
$FASTBOOT reboot bootloader

sleep 10

# Flash OS images
$FASTBOOT flash bootsig     "$IMG/boot.img${devname_sig}.sig"
$FASTBOOT flash recoverysig "$IMG/recovery.img${devname_sig}.sig"
$FASTBOOT flash boot        "$IMG/boot.img"
$FASTBOOT flash recovery    "$IMG/recovery.img"
$FASTBOOT flash cache       "$IMG/cache.img"
$FASTBOOT flash userdata    "$IMG/userdata.img"
$FASTBOOT flash modem       "$IMG/NON-HLOS-${dev_variant}.bin"
$FASTBOOT flash dsp         "$IMG/dspso.bin"
$FASTBOOT flash bluetooth  "$IMG/BTFM.bin"
$FASTBOOT flash vendor      "$IMG/vendor.img"
$FASTBOOT flash system      "$IMG/system.img"
$FASTBOOT flash oem         "$IMG/oem_${dev_subvariant}.img"

$FASTBOOT reboot

echo
echo "Done. Press Enter to exit."
read

