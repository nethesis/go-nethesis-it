#!/bin/bash

#
# Install NethServer Enterprise on a clean CentOS
#

# Output only on console
function out_c
{
    echo "${@}" 1>&3
}

# Output both on console and log
function out
{
    echo "${@}" | tee /dev/fd/3
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
    out_c "It is then safe to remove $INSTALL_DIR"
    out_c
}

function exit_error
{
    out "[ERROR]" "${@}"
    out_c "See the log file for more info: $LOG_FILE"
    out_c
    out_c "If the problem persists, please contact Nethesis support."
    out_c "Kindly provide to the support the following files:"
    out_c "    $LOG_FILE"
    out_c "    /var/log/messages"
    exit 1
}


function exit_help
{
    out_c "[ERROR] bad invocation! " "${@}"
    out_c
    out_c "Usage:"
    out_c "    curl -sS https://go.nethesis.it/install/ns7.sh | bash -s - <SECRET>"
    out_c
    out_c "Create a new server and get the SECRET token here:"
    out_c "    https://my.nethesis.it/#/servers?action=newServer"
    exit 1
}

function json_pick
{
    python -c "import json; import sys; print json.load(sys.stdin)$1"
}

INSTALL_DIR=/root/nethserver-enterprise-install
LOG_FILE="$INSTALL_DIR/install.log"

# Prepare the installer directory
mkdir -p $INSTALL_DIR
# Cleanup log file
> ${LOG_FILE}
# Redirecting evertything to the log file
# FD 3 can be used to write on the console
exec 3>&1 1>>${LOG_FILE} 2>&1

SECRET=${1}

if [[ -z ${SECRET} ]]; then
    exit_help "The SECRET argument is missing"
fi

chmod 600 $LOG_FILE

API_RESPONSE=$(curl -s -L -X POST -H "Content-type: application/json" -H "Accept: application/json" -d "{\"secret\": \"${SECRET}\"}" "https://my.nethesis.it/api/systems/info")
if [[ -z ${API_RESPONSE} ]]; then
    exit_error "Could not get remote API response"
fi

echo "[NOTICE] API_RESPONSE: ${API_RESPONSE}" 1>&2

SYSTEM_ID=$(json_pick '["uuid"]' <<<"${API_RESPONSE}")
if [[ -z ${SYSTEM_ID} ]]; then
    exit_error "Could not parse SYSTEM_ID from API response:" $(json_pick '["error"]["message"]' <<<"${API_RESPONSE}")
fi

export YUM1=${SYSTEM_ID}
export YUM0=no

centos_release=$(cat /etc/redhat-release  | grep -oP "\d\.\d\.\d+")

cat >/etc/yum.repos.d/subscription.repo <<'EOF'
#
# Temporary NethServer Enterprise repository configuration
#

[nh-base]
name=Nethesis mirror: CentOS Base $releasever
mirrorlist=http://mirrorlist.nethesis.it/?systemid=$YUM1&repo=base&arch=$basearch&nsversion=$nsrelease&usetier=$YUM0
failovermethod=priority
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-$releasever
gpgcheck=1
repo_gpgcheck=1
enablegroups=0
enabled=1
http_caching=none
mirrorlist_expire=7200
metadata_expire=7200

[nh-updates]
name=Nethesis mirror: CentOS Updates $releasever
mirrorlist=http://mirrorlist.nethesis.it/?systemid=$YUM1&repo=updates&arch=$basearch&nsversion=$nsrelease&usetier=$YUM0
failovermethod=priority
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-$releasever
gpgcheck=1
repo_gpgcheck=1
enablegroups=0
enabled=1
http_caching=none
mirrorlist_expire=7200
metadata_expire=7200

[nh-extras]
name=Nethesis mirror: CentOS Extras $releasever
mirrorlist=http://mirrorlist.nethesis.it/?systemid=$YUM1&repo=extras&arch=$basearch&nsversion=$nsrelease&usetier=$YUM0
failovermethod=priority
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-$releasever
gpgcheck=1
repo_gpgcheck=1
enablegroups=0
enabled=1
http_caching=none
mirrorlist_expire=7200
metadata_expire=7200

[nh-centos-sclo-rh]
name=Nethesis mirror: SCLo rh $releasever
mirrorlist=http://mirrorlist.nethesis.it/?systemid=$YUM1&repo=centos-sclo-rh&arch=$basearch&nsversion=$nsrelease&usetier=$YUM0
failovermethod=priority
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-SIG-SCLo
gpgcheck=1
repo_gpgcheck=0
enablegroups=0
enabled=1
http_caching=none
mirrorlist_expire=7200
metadata_expire=7200

[nh-centos-sclo-sclo]
name=Nethesis mirror: SCLo sclo $releasever
mirrorlist=http://mirrorlist.nethesis.it/?systemid=$YUM1&repo=centos-sclo-sclo&arch=$basearch&nsversion=$nsrelease&usetier=$YUM0
failovermethod=priority
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-SIG-SCLo
gpgcheck=1
repo_gpgcheck=0
enablegroups=0
enabled=1
http_caching=none
mirrorlist_expire=7200
metadata_expire=7200

[nh-epel]
name=Nethesis mirror: EPEL $releasever
mirrorlist=http://mirrorlist.nethesis.it/?systemid=$YUM1&repo=epel&arch=$basearch&nsversion=$nsrelease&usetier=$YUM0
failovermethod=priority
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-$releasever
gpgcheck=1
repo_gpgcheck=0
enablegroups=0
enabled=1
http_caching=none
mirrorlist_expire=7200
metadata_expire=7200

[nh-nethserver-updates]
name=Nethesis mirror: NethServer Updates $releasever
mirrorlist=http://mirrorlist.nethesis.it/?systemid=$YUM1&repo=nethserver-updates&arch=$basearch&nsversion=$nsrelease&usetier=$YUM0
failovermethod=priority
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-NethServer-$releasever
gpgcheck=1
repo_gpgcheck=1
enablegroups=1
enabled=1
http_caching=none
mirrorlist_expire=7200
metadata_expire=7200

[nh-nethserver-base]
name=Nethesis mirror: NethServer Base $releasever
mirrorlist=http://mirrorlist.nethesis.it/?systemid=$YUM1&repo=nethserver-base&arch=$basearch&nsversion=$nsrelease&usetier=$YUM0
failovermethod=priority
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-NethServer-$releasever
gpgcheck=1
repo_gpgcheck=1
enablegroups=0
enabled=1
http_caching=none
mirrorlist_expire=7200
metadata_expire=7200

[nethesis-updates]
name=Nethesis Updates $releasever
mirrorlist=http://mirrorlist.nethesis.it/?systemid=$YUM1&repo=nethesis-updates&arch=$basearch&nsversion=$nsrelease&usetier=$YUM0
failovermethod=priority
gpgcheck=1
repo_gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-NethServer-$releasever
enablegroups=1
enabled=1
enablesubscription=1
http_caching=none
mirrorlist_expire=7200
metadata_expire=7200

EOF

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

out "Starting installation process. It will take a while ..."
yum --disablerepo=\* --enablerepo=nh-\* --disablerepo=nh-epel install epel-release deltarpm -y

if [ $? -gt 0 ]; then
    exit_error "Can't install epel-release!"
fi

out "Extracting nethserver-register configuration ..."
yum -y --disablerepo=\* --enablerepo=nh-\*,nethesis-updates --downloadonly --downloaddir=$INSTALL_DIR install nethserver-register
pushd /
rpm2cpio $INSTALL_DIR/nethserver-register-*.rpm | cpio -imdv ./etc/e-smith/db/configuration/force/sysconfig/Version
if [ $? -gt 0 ]; then
    exit_error "Can't install nethserver-register"
fi
popd

# If NethServer release is greater than installed CentOS, force the upgrade
nethserver_release=$(cat /etc/e-smith/db/configuration/force/sysconfig/Version)
latest_release=$(echo -e "$centos_release\n$nethserver_release" | sort -V -r | head -n 1)

if [ "$latest_release" == "$nethserver_release" ]; then
    if [ "$centos_release" == "$nethserver_release" ]; then
        out "Installing updates for CentOS $centos_release ..."
    else
        out "Forcing CentOS upgrade from $centos_release to $nethserver_release ..."
    fi
    yum --disablerepo=* --enablerepo=nh-\* update -y
    echo $nethserver_release > /etc/yum/vars/nsrelease
fi

# Make sure to access nethserver-iso group
yum --disablerepo=* --enablerepo=nh-\* install @nethserver-iso --setopt=nh-nethserver-updates.enablegroups=1 -y | tee /dev/fd/3

if [ $? -gt 0 ]; then
    exit_error "Can't install nethserver-iso group!"
fi

out_c
out "Configuring system, please wait ..."
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

/sbin/e-smith/config setprop subscription SystemId "${SYSTEM_ID}" Secret "${SECRET}"
/sbin/e-smith/signal-event nethserver-subscription-save

end
