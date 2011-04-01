#!/bin/bash

function pinger {
    PING=$(ping -c1 -n $1)
    if [ "$?" -ne "0" ]; then
        return 1
    fi

    RT=$( echo $PING | sed 's/.*time\=\([0-9.]* ms\).*/\1/')
    echo "   $1 responded to ping in $RT"
    return 0
}

echo "Local IP: " $(ip address show | grep 'inet ' | grep -v 127.0.0.1 | sed 's/inet \([0-9.]*\).*/\1/')

GW=$(ip route show | grep 'default via' | sed 's/default via \([0-9.]*\).*/\1/')

if [ $GW == "" ]; then
    echo "No default gateway specified."
    exit 1
fi

echo "Default gateway:  $GW" 

pinger $GW
if [ $? -ne 0 ]; then
    echo "Could not ping default gateway."
    exit 2
fi

echo "Testing external IP..."
pinger '8.8.8.8'
if [ $? -ne 0 ]; then
    echo "Could not ping remote server 8.8.8.8"
    exit 3
fi

echo "Testing DNS resolver..."
pinger 'google.com'
if [ $? -ne 0 ]; then
    echo "Could not look-up google.com"
    exit 4
fi

echo "You seem to have working internet connection!"
