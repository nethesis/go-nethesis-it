#!/bin/bash

#
# Install NethServer Enterprise on a clean CentOS
#

# Output only on console
function out_c
{
    echo $@ 1>&3
}

# Output both on console and log
function out
{
    echo $@ | tee /dev/fd/3
    out_c # add extra new line
}


function end {
    out_c
    out "NethServer Enterprise successfully installed!"
    out_c "============================================="
    out_c
    out_c "You can access the Web interface at:"
    hostname=`/sbin/e-smith/db configuration get SystemName`
    domainname=`/sbin/e-smith/db configuration get DomainName`
    out_c
    out_c -n "    https://$hostname.$domainname:980 "
    for k in `/sbin/e-smith/db networks keys`
    do
       role=`/sbin/e-smith/db networks getprop $k role`
       if [ "$role" == "green" ]; then
           ip=$(/sbin/e-smith/db networks getprop $k ipaddr)
           out_c " (or https://$ip:980)"
       fi
    done
    out_c
    out_c "    Login: root" 
    out_c "    Password: <your_root_password>"
    out_c
    out_c
}

function exit_error
{
    out "[ERROR]" $@
    out_c "See the log file for more info: $LOG_FILE"
    out_c
    out_c "If the problem persists, please contact Nethesis support."
    out_c "Kindly provide to the support the following files: $LOG_FILE /var/log/messages"
    exit 1
}


TMP_DIR=/tmp/nethserver-enterprise-install
LOG_FILE="$TMP_DIR/install.log"

# Prepare temporary directory
mkdir -p $TMP_DIR
# Cleanup log file
> ${LOG_FILE}
# Redirecting evertything to the log file
# FD 3 can be used to write on the console
exec 3>&1 1>>${LOG_FILE} 2>&1

centos_release=$(cat /etc/redhat-release  | grep -oP "\d\.\d\.\d+")

out "Downloading nethserver-register ..." 
# FIXME! cannot access Porthos if LK is missing:
curl http://update.nethesis.it/nethserver/$centos_release/nethserver-register.rpm -o $TMP_DIR/nethserver-register.rpm

if [ ! -f $TMP_DIR/nethserver-register.rpm ]; then
    exit_error "Current CentOS release ($centos_release) is not supported by NethServer Enterprise!"
fi

out "Configuring yum repositories ..."
pushd /
# FIXME! nethesis.repo is a template now, the RPM file is just a placeholder
rpm2cpio $TMP_DIR/nethserver-register.rpm | cpio -imdv ./etc/yum.repos.d/nethesis.repo
popd

if [ ! -f /etc/yum.repos.d/nethesis.repo ]; then
    exit_error "Can't extract nethesis.repo file"
fi

echo $centos_release > /etc/yum/vars/nsrelease

out "Installing nethserver-release ..."
yum --disablerepo=* --enablerepo=nh-\* --nogpgcheck install nethserver-release -y

if [ $? -gt 0 ]; then
    exit_error "Installation of nethsever-release failed!"
fi

out "Importing GPG keys ..."
rpm --import /etc/pki/rpm-gpg/*
if [ $? -gt 0 ]; then
    exit_error "Can't import GPG keys!"
fi

out "Starting installation process. It will take a while..."
yum --disablerepo=\* --enablerepo=nh-\* --disablerepo=nh-epel install epel-release deltarpm -y

if [ $? -gt 0 ]; then
    exit_error "Can't install epel-release!"
fi

# If NethServer release is greater than installed CentOS, force the upgrade
nethserver_release=$(cat /etc/e-smith/db/configuration/force/sysconfig/Version)
latest_release=$(echo -e "$centos_release\n$nethserver_release" | sort -V -r | head -n 1)

if [ "$latest_release" == "$nethserver_release" ]; then
    out "Forcing CentOS upgrade from $centos_release to $nethserver_release"
    yum --disablerepo=* --enablerepo=nh-\* update -y
    echo $nethserver_release > /etc/yum/vars/nsrelease
else
    # FIXME! this seems duplicate of line 88
    echo $centos_release > /etc/yum/vars/nsrelease
fi

# Make sure to access nethserver-iso group
yum --disablerepo=* --enablerepo=nh-\* install @nethserver-iso --setopt=nh-nethserver-updates.enablegroups=1 -y | tee /dev/fd/3

if [ $? -gt 0 ]; then
    exit_error "Can't install nethserver-iso group!"
fi

out_c
out "Configuring system, please wait..."
rm -f /etc/yum/vars/nsrelease
for UNIT in NetworkManager firewalld; do
    if systemctl is-active -q $UNIT; then
        systemctl stop $UNIT
        systemctl preset $UNIT
    fi
done

systemctl enable nethserver-config-network
/sbin/e-smith/signal-event system-init

if [ $? -gt 0 ]; then
    exit_error "Configuration failed!"
fi

rpm -q nethserver-register &>/dev/null # do not fail if nethserver-register is already installed
if [ $? -gt 0 ]; then
    out "Installing nethserver-register ..."
    yum --disablerepo=\* --enablerepo=nh-\* install $TMP_DIR/nethserver-register.rpm -y
fi

if [ $? -gt 0 ]; then
    exit_error "Installation of nethsever-register failed!"
fi

end
