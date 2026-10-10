#!/bin/bash
# ut-ssh.sh "command" : run a command as root on the running Ubuntu Touch (Mi 10T) over USB networking
exec ssh -i ~/.ssh/ut_apollo -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=~/.ssh/known_hosts_ut -o ConnectTimeout=8 root@10.15.19.82 "$@"
