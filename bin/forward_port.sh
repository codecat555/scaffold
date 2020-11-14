#!/bin/bash

# handy debug rules:
#
# sudo iptables -I FORWARD 1 -p tcp --dport 5000 -j LOG --log-prefix "IPFORW:" --log-level debug
# sudo iptables -t nat -I PREROUTING 1 -p tcp --dport 5000 -j LOG --log-prefix "IPNAT:" --log-level debug
#

if [ $# -ne 5 ]; then
    echo "usage $0 <multipass-instance-name> <host-interface> <proto> <host-port> <instance-port>" >&2
    exit 1
fi
app_host=$1
host_ifc=$2
proto=$3
host_port=$4
instance_port=$5

# get the instance ip addr
instance_ip=$(multipass info $app_host | grep '^IPv4:' | sed -E 's/^.* ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+) *$/\1/')
#echo $instance_ip

# see example at https://discourse.ubuntu.com/t/multipass-port-forwarding-with-iptables/18741
# also see http://www.netfilter.org/documentation/HOWTO/NAT-HOWTO-6.html#ss6.2

# check if rule already exists for some host interface, to avoid conflicts
matched_rule=$(sudo iptables -t nat -L PREROUTING -v | grep "DNAT .* $host_ifc .* $proto dpt:$host_port ")
if [ -z "$matched_rule" ]; then
    # insert the pre-routing rule
    sudo iptables -t nat -I PREROUTING 1 -i $host_ifc -p $proto --dport $host_port -j DNAT --to-destination $instance_ip:$instance_port
elif ! echo "$matched_rule" | grep " to:$instance_ip:$instance_port" > /dev/null; then
    echo "PREROUTING rule already exists mapping the same host interface and port to a different destination, delete that rule first or choose a different host port"
    exit 2
fi

matched_rule=$(sudo iptables -L FORWARD -v | grep ".* $host_ifc .* $instance_ip .* $proto dpt:$instance_port")
if [ -z "$matched_rule" ]; then
    sudo iptables -I FORWARD 1 -i $host_ifc -p $proto -d $instance_ip --dport $host_port -j ACCEPT
fi

