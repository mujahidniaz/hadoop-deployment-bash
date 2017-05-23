#!/bin/bash
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Copyright Clairvoyant 2016
#
# $Id:$
#
# Program
#     Does something.
#
# EXIT CODE:
#     0 = success
#     1 = print_help function (or incorrect commandline)
#     2 = ERROR: Must be root.
#
AUTHOR="Michael Arnold <michael.arnold@clairvoyantsoft.com>"
VERSION=YYYYMMDD
#
if [ $DEBUG ]; then set -x; fi
#
##### START CONFIG ###################################################

##### STOP CONFIG ####################################################
PATH=/usr/bin:/usr/sbin:/bin:/sbin
FSTYPE=xfs
FSMOUNTOPT=noatime

# Function to print the help screen.
print_help () {
  printf "Usage:  $1 --device <device> --mountpoint <mountpoint>\n"
  printf "\n"
  printf "         -d|--device           Disk device to encrypt.  Device will be wiped.\n"
  printf "         -m|--mountpoint       Mountpoint of the unencrypted filesystem.\n"
  printf "        [-h|--help]\n"
  printf "        [-v|--version]\n"
  printf "\n"
  printf "   ex.  $1 --navpass \"mypasssword\" --device /dev/sdb --mountpoint /data/2\n"
  exit 1
}

# Function to check for root priviledges.
check_root () {
  if [[ `/usr/bin/id | awk -F= '{print $2}' | awk -F"(" '{print $1}' 2>/dev/null` -ne 0 ]]; then
    printf "You must have root priviledges to run this program.\n"
    exit 2
  fi
}

## If the variable DEBUG is set, then turn on tracing.
## http://www.research.att.com/lists/ast-users/2003/05/msg00009.html
#if [ $DEBUG ]; then
#  # This will turn on the ksh xtrace option for mainline code
#  set -x
#
#  # This will turn on the ksh xtrace option for all functions
#  typeset +f |
#  while read F junk
#  do
#    typeset -ft $F
#  done
#  unset F junk
#fi

# Process arguments.
while [[ $1 = -* ]]; do
  case $1 in
    -d|--device)
      shift
      DEVICE=$1
      ;;
    -m|--mountpoint)
      shift
      MOUNTPOINT=$1
      ;;
    -h|--help)
      print_help "$(basename $0)"
      ;;
    -v|--version)
      printf "\tProgram\n"
      printf "\tVersion: $VERSION\n"
      printf "\tWritten by: $AUTHOR\n"
      exit 0
      ;;
    *)
      print_help "$(basename $0)"
      ;;
  esac
  shift
done

# Check to see if we have no parameters.
if [[ -z "$DEVICE" ]]; then print_help "$(basename $0)"; fi
if [[ -z "$MOUNTPOINT" ]]; then print_help "$(basename $0)"; fi

# Lets not bother continuing unless we have the privs to do something.
check_root

# main
if [ ! -f /etc/navencrypt/keytrustee/clientname ]; then
  printf "** WARNING: This host is not yet registered.  Skipping..."
  exit 3
fi
if ! mountpoint -q ${MOUNTPOINT}; then
  printf "** WARNING: ${MOUNTPOINT} is not a mountpoint. Exiting..."
  exit 4
fi
if [ -d ${MOUNTPOINT}tmp ]; then
  printf "** WARNING: ${MOUNTPOINT}tmp exists.  Is another move process running?  Exiting..."
  exit 5
fi
# add a check to make sure there is enough space in /data

ESCMOUNTPOINT=$(echo $MOUNTPOINT | sed -e 's|/|\\/|g')
FULLDEVICE=$(mount | awk "\$3~/${ESCMOUNTPOINT}\$/{print \$1}")
ESCFULLDEVICE=$(echo $FULLDEVICE | sed -e 's|/|\\/|g')
DEVICE=$(echo $FULLDEVICE | sed -e 's|[0-9]$||')
if [ ! -b $DEVICE ]; then
  DEVICE=$(echo $DEVICE | sed -e 's|.$||')
  if [ ! -b $DEVICE ]; then
    printf "** WARNING: ${DEVICE} does not exit. Exiting..."
    exit 6
  fi
fi

set -euo pipefail
echo "** Moving data off of ${MOUNTPOINT}..."
mkdir -p -m 0755 ${MOUNTPOINT}tmp
mv ${MOUNTPOINT}/* ${MOUNTPOINT}tmp/
umount $MOUNTPOINT
sed -e "/^${ESCFULLDEVICE} /d" -i /etc/fstab
rmdir $MOUNTPOINT
mv ${MOUNTPOINT}tmp ${MOUNTPOINT}

echo "** Wiping the device to prepare it for navencrypt-prepare..."
dd if=/dev/zero of=${DEVICE} bs=1M count=10
kpartx -d ${DEVICE}
rm -f ${FULLDEVICE}

