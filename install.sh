#!/bin/bash
#
# About: Install Batocera automatically
# Author: liberodark
# Thanks : 
# License: GNU GPLv3

version="0.0.1"

echo "Welcome on RecalBox2Batocera Script $version"

do_clean() {
    test -n "${GETPERPID}" && kill -9 "${GETPERPID}"
    rm -f "/recalbox/share/upgrade/boot.tar.xz"
    rm -f "/recalbox/share/upgrade/boot.tar.xz.md5"
}
trap do_clean EXIT

# ---- MAIN ----

CUSTOM_URLDIR=
if test $# -eq 1
then
    CUSTOM_URLDIR=$1
fi

echo "Starting the upgrade..."

# --- Prepare update URLs ---

updateurl="https://updates.batocera.org"

arch=$(cat /recalbox/recalbox.arch)
test "${arch}" = "rpi4" && arch=rpi464 # "temporarly" download on rpi464 for rpi4

#updatetype="$(/usr/bin/batocera-settings-get updates.type)"
#settingsupdateurl="$(/usr/bin/batocera-settings-get updates.url)"

# customizable upgrade url website
test -n "${settingsupdateurl}" && updateurl="${settingsupdateurl}"

# force a default value in case the value is removed or miswritten
test "${updatetype}" != "stable" -a "${updatetype}" != "unstable" -a "${updatetype}" != "beta" && updatetype="stable"

# custom the url directory
DWD_HTTP_DIR="${updateurl}/${arch}/${updatetype}/last"

if test -n "${CUSTOM_URLDIR}"
then
    DWD_HTTP_DIR="${CUSTOM_URLDIR}"
fi

# --- Prepare file downloads ---

# download directory
mkdir -p /recalbox/share/upgrade || exit 1

# download
url="${DWD_HTTP_DIR}/boot.tar.xz"
echo "url: ${url}"
#curl -A "batocera-upgrade" -sfL "${url}" -o "/recalbox/share/upgrade/boot.tar.xz" || exit 1
wget -U "batocera-upgrade" -q --show-progress "${url}" -O "/recalbox/share/upgrade/boot.tar.xz" || exit 1

# try to download an md5 checksum
curl -A "batocera-upgrade.md5" -sfL "${url}.md5" -o "/recalbox/share/upgrade/boot.tar.xz.md5"
if test -e "/recalbox/share/upgrade/boot.tar.xz.md5"
then
    DISTMD5=$(cat "/recalbox/share/upgrade/boot.tar.xz.md5")
    CURRMD5=$(md5sum "/recalbox/share/upgrade/boot.tar.xz" | sed -e s+' .*$'++)
    if test "${DISTMD5}" = "${CURRMD5}"
    then
        echo "valid checksum."
    else
        echo "invalid checksum. Got +${DISTMD5}+. Attempted +${CURRMD5}+."
        exit 1
    fi
else
    echo "no checksum found. don't check the file."
fi

# remount /boot in rw
echo "remounting /boot in rw"
if ! mount -o remount,rw /boot
then
    exit 1
fi

# backup boot files
# all these files doesn't exist on non rpi platform, so, we have to test them
# don't put the boot.ini file while it's not really to be customized
echo "backing up some boot files"
BOOTFILES="config.txt batocera-boot.conf"
for BOOTFILE in ${BOOTFILES}
do
    if test -e "/boot/${BOOTFILE}"
    then
        if ! cp "/boot/${BOOTFILE}" "/boot/${BOOTFILE}.upgrade"
        then
            exit 1
        fi
    fi
done

# extract file on /boot
echo "extracting files"
if ! (cd /boot && xz -dc < "/recalbox/share/upgrade/boot.tar.xz" | tar xvf -)
then
    exit 1
fi

# restore boot files
for BOOTFILE in ${BOOTFILES}
do
    if test -e "/boot/${BOOTFILE}.upgrade"
    then
        if ! mv "/boot/${BOOTFILE}.upgrade" "/boot/${BOOTFILE}"
        then
            echo "Outch" >&2
        fi
    fi
done

echo "synchronizing disk"

# remount /boot in ro
if ! mount -o remount,ro /boot
then
    exit 1
fi

echo "Run Recalbox to Batocera"
# create folder
mkdir -p /userdata/bios
mkdir -p /userdata/cheats
mkdir -p /userdata/decorations
mkdir -p /userdata/extractions
mkdir -p /userdata/kodi
mkdir -p /userdata/music
mkdir -p /userdata/roms
mkdir -p /userdata/saves
mkdir -p /userdata/screenshots
mkdir -p /userdata/splash
mkdir -p /userdata/system
mkdir -p /userdata/themes

# clean
rm -rf /recalbox/share/userscripts
rm -rf /recalbox/share/shaders
rm -rf /recalbox/share/themes/*
mv /recalbox/share/system /recalbox/share/system.old

# a sync
rm -rf "/recalbox/share/upgrade"
rm -rf "/recalbox/share/upgrade"
sync

echo; echo "Done. Please reboot the system so that the changes take effect!"
exit 0
