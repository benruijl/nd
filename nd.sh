#!/bin/bash
#    nd - A network diagnostics utility for Linux
#    Copyright (C) 2011 Ben Ruijl
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

TEST_EXT_IP="192.0.32.10" # IP used for testing if an external connection can be made
TEST_HOST="example.com" # Test hostname used to check if DNS is working

function pinger {
    PING=$(ping -c1 -n $1)
    if [ "$?" -ne "0" ]; then
        return 1
    fi

    RT=$( echo $PING | sed 's/.*time\=\([0-9.]* ms\).*/\1/')
    echo -e "\tResponded to ping in $RT"
    return 0
}

function is_link_up() {
	local _interface=$1
	[[ -z "$_interface" ]] && return 1
	interface_up=$(ip link show dev $_interface up | grep -F 'LOWER_UP')
	[[ -n "$interface_up" ]] && return 0 || return 1
}

function is_interface_up() {
	local _interface=$1
	[[ -z "$_interface" ]] && return 1
	interface_up=$(ip link show dev $_interface up)
	[[ -n "$interface_up" ]] && return 0 || return 1
}

function is_dhcp_client_running() {
	local _interface=$1
	[[ -z "$_interface" ]] && return 1
	# Check for running dhcp clients
	local dhcp_pid=$(pgrep '^(dhcp|dhclient)')
	# Nothing found?
	[[ -z "$dhcp_pid" ]] && return 1
	# We found something, see if it's for this interface
	grep -qF "$_interface" /proc/$dhcp_pid/cmdline
	return $?
}

DEV="$1"
# Get the first ethernet interface that is up if the user does not supply an interface name
[[ -z "$DEV" ]] && DEV=$(ip link show up | grep -B1 'link/ether' | head -n1 | cut -d: -f2 | cut -c2-)

is_link_up $DEV && echo "* Link OK" || { echo "No link on $DEV"; exit 1; }
is_interface_up $DEV && echo "* Interface is UP" || { echo "$DEV is DOWN"; exit 1; }

# Is it a wireless device?
if [ -d "/sys/class/net/$DEV/wireless" ]; then
    ESSID=$(iwconfig wlan0 | grep ESSID | cut -d: -f2 |  sed 's/.*\"\([^\"]*\)".*/\1/')

    if [ -z $ESSID ]; then
        echo "The wireless activated device $DEV is not associated to any access point"
        exit 7
    fi

    echo -e "\tAssociated to $ESSID"
fi

IP=$(ip addr show $DEV | grep 'inet ' | grep -v 127.0.0.1 | sed 's/inet \([0-9.]*\).*/\1/')
is_dhcp_client_running $DEV && HAS_DHCP='yes' || HAS_DHCP=''

if [ -z $IP ]; then
    echo "No IP address assigned to this computer."

    if [ -z $HAS_DHCP ]; then
        echo -e "\tA DHCP daemon is running, however."
    fi
fi

echo -e "\tLocal IP:$IP" 
if [ -n "$HAS_DHCP" ]; then
    echo -e "\tDHCP: yes"
else
    echo -e "\tDHCP: no"
fi

GW=$(ip route show | grep 'default via' | sed 's/default via \([0-9.]*\).*/\1/')
if [ -z $GW ]; then
    echo "No default gateway specified."
    exit 1
fi

echo "* Default gateway: $GW"

if [[ $(echo $IP | cut -d. -f1-3) != $(echo $GW | cut -d. -f1-3) ]]; then
    echo -e "\tWarning: Local IP and gateways are not on the same subnet!"
fi

pinger $GW
if [ $? -ne 0 ]; then
    echo "Could not ping default gateway."
    exit 2
fi

echo "* Testing external IP..."
pinger $TEST_EXT_IP
if [ $? -ne 0 ]; then
    echo "Could not ping remote server $TEST_EXT_IP"
    exit 3
fi

echo "* Testing DNS resolver..."
RES=$(host $TEST_HOST)
if [ $? -ne 0 ]; then
    NS=$(cat /etc/resolv.conf | grep '^nameserver')

    if [ $NS == ""]; then
        echo "There are no nameservers specified in /etc/resolv.conf!"
        exit 4
    fi

    echo "Could not look-up $TEST_HOST."
    exit 5
fi
echo -e "\tHostname was resolved."

echo -e "\nYou seem to have a working internet connection!"
