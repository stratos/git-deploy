#!/bin/bash

restore

FIRST_RUN=false

mkdir -p /git/.ssh/host_keys
for TYPE in rsa dsa ecdsa ed25519; do
    if [ ! -f "/git/.ssh/host_keys/ssh_host_${TYPE}_key" ]; then
        FIRST_RUN=true
        echo -n "Generating SSH ${TYPE} Host Key..."
        ssh-keygen -N '' -qt ${TYPE} -f /git/.ssh/host_keys/ssh_host_${TYPE}_key
        echo " Done"
    fi
done

if [ "$FIRST_RUN" = "true" ]; then
    backup
fi

env | sed -e "s/^/export /" -e "s/$/'/" -e "s/=/='/" > /git/.profile

# Loop reads, reading from fifo
mkfifo /var/log/git-deploy/hooks.log
while cat /var/log/git-deploy/hooks.log; do :; done &

echo "Starting Git-Deploy on port $PORT"
if [ -z "$SSH_LOG_FILE" ]; then
	/usr/sbin/sshd -D -e -p $PORT
else
	/usr/sbin/sshd -D -e -p $PORT -E $SSH_LOG_FILE
fi
