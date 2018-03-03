#!/bin/bash

# Taken from this gist
# https://gist.github.com/andrewrech/4bd15a195489b864bdf46ee43df3eb3c

# AWS documentation: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/sriov-networking.html
# HVM only

# See also: https://gist.github.com/fermayo/1f1b9f10bf14b19a9f1b

# Download latest ixgbevf module from: https://sourceforge.net/projects/e1000/files/ixgbevf%20stable/

sudo su

tar -xzf ixgbevf-*.tar.gz

# e.g. 4.1.1
export IXGBEVF_OLD_VERSION=$(modinfo ixgbevf | grep version: | grep -Po '[0-9]\.[0-9]\.[0-9]')
export IXGBEVF_VERSION=$(find -type d -name 'ixgbevf*' | grep -Po '[0-9]\.[0-9]\.[0-9]')
# e.g. 1028
export LATEST_KERNEL_VERSION=$(uname -r | grep -Po '[0-9]{4}(?=-aws)')

sudo apt-get install linux-headers-aws linux-image-aws

# remove old
sudo dkms remove ixgbevf/$IXGBEVF_OLD_VERSION --all

# remove broken version check
sed -i -- 's/#if UTS_UBUNTU_RELEASE_ABI > 255//g' ./ixgbevf-$IXGBEVF_VERSION/src/kcompat.h
sed -i -- 's/#error UTS_UBUNTU_RELEASE_ABI is too large...//g' ./ixgbevf-$IXGBEVF_VERSION/src/kcompat.h
sed -i -- 's|#endif /\* UTS_UBUNTU_RELEASE_ABI > 255 \*/||g' ./ixgbevf-$IXGBEVF_VERSION/src/kcompat.h

sudo cp -R ixgbevf-$IXGBEVF_VERSION /usr/src/

# set up conf

echo "PACKAGE_NAME=\"ixgbevf\"
PACKAGE_VERSION=\"$IXGBEVF_VERSION\"
CLEAN=\"cd src/; make clean\"
MAKE=\"cd src/; make BUILD_KERNEL=\${kernelver}\"
BUILT_MODULE_LOCATION[0]=\"src/\"
BUILT_MODULE_NAME[0]=\"ixgbevf\"
DEST_MODULE_LOCATION[0]=\"/updates\"
DEST_MODULE_NAME[0]=\"ixgbevf\"
AUTOINSTALL=\"yes\"" > /usr/src/ixgbevf-$IXGBEVF_VERSION/dkms.conf

# verify correct
< /usr/src/ixgbevf-$IXGBEVF_VERSION/dkms.conf

# reinstall module

sudo dkms add -m ixgbevf -v $IXGBEVF_VERSION
sudo dkms build -m ixgbevf -v $IXGBEVF_VERSION -k 4.4.0-$LATEST_KERNEL_VERSION-aws
sudo dkms install -m ixgbevf -v $IXGBEVF_VERSION --all
sudo update-initramfs -c -k all

# verify correct
modinfo ixgbevf
