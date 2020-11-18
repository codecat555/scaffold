#!/bin/bash -x

# handy debug rules:
#
# iptables -t filter -I FORWARD 1 -p tcp --dport 5000 -j LOG --log-prefix "IPFORW:" --log-level debug
# iptables -t nat -I PREROUTING 1 -p tcp --dport 5000 -j LOG --log-prefix "IPNAT:" --log-level debug
#

FORCE=0

if [[ $# -ne 5 && $# -ne 6 ]]; then
    echo "usage $0 [-f] <multipass-instance-name> <host-interface> <proto> <host-port> <instance-port>" >&2
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
instance_port=$5

# get the instance ip addr
#instance_ip=$(multipass info $app_host | grep '^IPv4:' | sed -E 's/^.* ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+) *$/\1/')
# regex pulled from https://stackoverflow.com/questions/11482951/extracting-ip-address-from-a-line-from-ifconfig-output-with-grep/11483005#11483005
instance_ip=$(multipass list | grep $app_host | grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b')
if [ $? -ne 0 ]; then
    echo "Error: failed to retrieve instance ip address - is host up?" >&2
    multipass list
    exit 4
fi

#echo $instance_ip

# see example at https://discourse.ubuntu.com/t/multipass-port-forwarding-with-iptables/18741
# also see http://www.netfilter.org/documentation/HOWTO/NAT-HOWTO-6.html#ss6.2

doit() {
    table=$1
    chain=$2
    action=$3
    purpose=$4

    # check if rule already exists for some host interface, to avoid conflicts
    matched_rule=$(iptables -t $table -L $chain -v --line-numbers | grep ".* $host_ifc .* $proto dpt:$host_port ")

    echo "$matched_rule" | grep " to:$instance_ip:$instance_port" > /dev/null
    matched_same_dest=$?
    if [ -n "$matched_rule" ] && [ $matched_same_dest -ne 0 ]; then
        if [ $FORCE -eq 1 ]; then
            line_num=$(echo $matched_rule | cut -d' ' -f1)
            iptables -t $table -D $chain $line_num
            if [ $? -ne 0 ]; then
                echo "failed to delete partially-matched $chain rule" >&2
                exit 3
            fi
            matched_rule=""
        else
            echo "$chain rule already exists mapping the same host interface and port to a different destination, delete that rule first or choose a different host port" >&2
            exit 2
        fi
    fi

    if [ -z "$matched_rule" ]; then
        # insert the pre-routing rule
        extra_args=
        if [ $table == 'nat' ]; then
            extra_args="--to-destination $instance_ip:$instance_port"
        fi
        iptables -t $table -I $chain 1 -i $host_ifc -p $proto --dport $host_port -j $action $extra_args -m comment --comment "generated for $purpose"
    fi
}

doit 'nat' 'PREROUTING' 'DNAT' $app_host
doit 'filter' 'FORWARD' 'ACCEPT' $app_host

# persist the change
iptables-save > /etc/iptables/rules.v4

