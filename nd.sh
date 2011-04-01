#!/bin/bash

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

# Check if a device is up
# TODO: check for link/ether
DEVCOUNT=$(ip addr | grep -c 'state UP')
if [ $DEVCOUNT == 0 ]; then
    echo "There are no network devices up."
    exit 6
fi

# Get the name of the first interface that is up
# TODO: This is not necessarily the real internet device. Maybe do the following for all of them?
DEV=$(ip addr | grep 'state UP' | cut -d: -f2 | cut -c2-)
echo "* Active device: $DEV"

# Is it a wireless device?
if [ -d "/sys/class/net/$DEV/wireless" ]; then
    ESSID=$(iwconfig wlan0 | grep ESSID | cut -d: -f2 |  sed 's/.*\"\([^\"]*\)".*/\1/')

    if [ -z $ESSID ]; then
        echo "The wireless activated device $DEV is not associated to any access point"
        exit 7
    fi

    echo -e "\tAssociated to $ESSID"
fi

echo -e "\tLocal IP: $(ip addr show $DEV | grep 'inet ' | grep -v 127.0.0.1 | sed 's/inet \([0-9.]*\).*/\1/')"

GW=$(ip route show | grep 'default via' | sed 's/default via \([0-9.]*\).*/\1/')
if [ $GW == "" ]; then
    echo "No default gateway specified."
    exit 1
fi

echo "* Default gateway: $GW" 
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

echo -e "\nYou seem to have a working internet connection!"
