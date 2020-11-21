#!/bin/bash -x

# handy debug rules:
#
# iptables -t filter -I FORWARD 1 -p tcp --dport 5000 -j LOG --log-prefix "IPFORW:" --log-level debug
# iptables -t nat -I PREROUTING 1 -p tcp --dport 5000 -j LOG --log-prefix "IPNAT:" --log-level debug
#

FORCE=0
SYSCTL_FILE="/etc/sysctl.d/23-custom.conf"

LOCAL_IP=$(hostname -I | cut -d' ' -f1)

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

# get the instance ip addr
#instance_ip=$(multipass info $app_host | grep '^IPv4:' | sed -E 's/^.* ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+) *$/\1/')
# regex pulled from https://stackoverflow.com/questions/11482951/extracting-ip-address-from-a-line-from-ifconfig-output-with-grep/11483005#11483005
#instance_ip=$(multipass list | grep $app_host | grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b')
#if [ $? -ne 0 ]; then
#    echo "Error: failed to retrieve instance ip address - is host up?" >&2
#    multipass list
#    exit 4
#fi

#echo $instance_ip

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

#
# rules for localhost, from https://serverfault.com/questions/551487/dnat-from-localhost-127-0-0-1
#
#iptables -t nat -A OUTPUT -p tcp -d 127.0.0.1 --dport 4242 -j DNAT --to 11.22.33.44:5353
#sysctl -w net.ipv4.conf.eth0.route_localnet=1
#iptables -t nat -A POSTROUTING -p tcp -s 127.0.0.1 -d 11.22.33.44 --dport 5353 -j SNAT --to $your-eth0-ip
#
###    # insert the pre-routing rule
###    extra_args=
###    if [ $table == 'nat' ]; then
###        if [ $target == 'DNAT' ]; then
###            # -A OUTPUT -d 127.0.0.1/32 -p tcp -m tcp --dport 5000 -j DNAT --to 10.127.208.19:5000
###            #iptables -t $table -I $chain -d 127.0.0.1/32 -p $proto -m tcp --dport $host_port -j $target --to $instance_ip:$instance_port
###            iptables -t $table -I $chain 1 -o lo  -p $proto -m tcp --dport $host_port -j $target --to $instance_ip:$instance_port
###        elif [ $target == 'SNAT' ]; then
###            #-A POSTROUTING -s 127.0.0.1/32 -d 10.127.208.19/32 -p tcp -m tcp --dport 5000 -j SNAT --to 10.0.0.21
###            #iptables -t $table -I $chain -s 127.0.0.1/32 -d $instance_ip/32 -p $proto -m tcp --dport $host_port -j $target --to $LOCAL_IP
###            iptables -t $table -I $chain -i lo -d $instance_ip/32 -p $proto -m tcp --dport $host_port -j $target --to $LOCAL_IP
###        fi
###    else
###        iptables -t $table -I $chain 1 -i $host_ifc -p $proto --dport $host_port -j $target
###    fi
###}

# rules for accepting external connections
#doit 'nat' 'PREROUTING' 'DNAT' $app_host
iptables -t nat -I PREROUTING 1 -i $host_ifc -p $proto --dport $host_port -j DNAT --to-destination $instance_ip:$instance_port

#doit 'filter' 'FORWARD' 'ACCEPT' $app_host
iptables -t filter -I FORWARD 1 -i $host_ifc -p $proto --dport $host_port -j ACCEPT

# rules for accepting localhost connections
sysctl -w net.ipv4.conf.all.route_localnet=1
if [ ! -f $SYSCTL_FILE ]; then
    # make it persistent
    echo "net.ipv4.conf.all.route_localnet=1" > $SYSCTL_FILE
fi
#doit 'nat' 'OUTPUT' 'DNAT' $app_host
#iptables -t nat -A OUTPUT -p tcp -d 127.0.0.1 --dport 4242 -j DNAT --to 11.22.33.44:5353
iptables -t nat -A OUTPUT -p $proto -d 127.0.0.1 --dport $host_port -j DNAT --to $instance_ip:$instance_port

#doit 'nat' 'POSTROUTING' 'SNAT' $app_host
#iptables -t nat -A POSTROUTING -p tcp -s 127.0.0.1 -d 11.22.33.44 --dport 5353 -j SNAT --to $your-eth0-ip
iptables -t nat -A POSTROUTING -p $proto -s 127.0.0.1 -d $instance_ip --dport $host_port -j SNAT --to $LOCAL_IP

# persist the change
iptables-save > /etc/iptables/rules.v4

