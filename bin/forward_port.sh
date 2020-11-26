#!/bin/bash

# handy debug rules:
#
# iptables -t filter -I FORWARD 1 -p tcp --dport 5000 -j LOG --log-prefix "IPFORW:" --log-level debug
# iptables -t nat -I PREROUTING 1 -p tcp --dport 5000 -j LOG --log-prefix "IPNAT:" --log-level debug
#

FORCE=0
SYSCTL_FILE="/etc/sysctl.d/23-custom.conf"

# get local ip address on multipass bridge network
LOCAL_IP=$(/usr/sbin/ip -family inet -br address show dev mpqemubr0 | grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b')

if [[ $# -ne 6 && $# -ne 7 ]]; then
    echo "usage $0 [-f] <multipass-instance-name> <host-interface> <proto> <host-port> <instance-ip> <instance-port>" >&2
    exit 1
fi
if [ $1 == "-f" ]; then
    shift
    FORCE=1
fi
app_host=$1
host_ifc=$2
proto=$3
host_port=$4
instance_ip=$5
instance_port=$6

# see example at https://discourse.ubuntu.com/t/multipass-port-forwarding-with-iptables/18741
# also see http://www.netfilter.org/documentation/HOWTO/NAT-HOWTO-6.html#ss6.2

# check if rule already exists for some host interface, to avoid conflicts
# note: tac is used to capture rules in reverse order, for last-first deletion
for table in filter nat; do
    chains=$(sudo iptables -t $table -L | grep '^Chain' | cut -d' ' -f2)
    for chain in $chains; do
        matching_rules=$(iptables -t $table -L $chain -v --line-numbers | grep -E ".* ($host_ifc|any) .* $proto dpt:$host_port" | tac)
        if [ -n "$matching_rules" ]; then
            if [ $FORCE -eq 1 ]; then
                echo "$matching_rules" | while read matched_rule; do
                    rule_num=$(echo "$matched_rule" | cut -d' ' -f1)
                    iptables -t $table -D $chain $rule_num
                    if [ $? -ne 0 ]; then
                        echo "failed to delete matching rule in table $table and chain $chain" >&2
                        exit 3
                    fi
                done
            else
                echo "one or more rules already exist mapping the same host interface and port, use force option or choose different parameters" >&2
                exit 2
            fi
        fi
    done
done

# rules for accepting external connections
iptables -t nat -I PREROUTING 1 -i $host_ifc -p $proto --dport $host_port -j DNAT --to-destination $instance_ip:$instance_port

iptables -t filter -I FORWARD 1 -i $host_ifc -p $proto --dport $host_port -j ACCEPT

# rules for accepting localhost connections
# - see https://serverfault.com/questions/551487/dnat-from-localhost-127-0-0-1
sysctl -w net.ipv4.conf.all.route_localnet=1
iptables -t nat -A OUTPUT -p $proto -d 127.0.0.1 --dport $host_port -j DNAT --to $instance_ip:$instance_port
iptables -t nat -A POSTROUTING -p $proto -s 127.0.0.1 -d $instance_ip --dport $host_port -j SNAT --to $LOCAL_IP

# persist the changes
if [ ! -f $SYSCTL_FILE ]; then
    # make it persistent
    echo "net.ipv4.conf.all.route_localnet=1" > $SYSCTL_FILE
fi
iptables-save > /etc/iptables/rules.v4

