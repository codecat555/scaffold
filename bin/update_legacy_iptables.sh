#!/bin/bash

#iptables-legacy -R FORWARD 3 -d 10.127.208.0/24 -o mpqemubr0 -m conntrack --ctstate NEW,RELATED,ESTABLISHED -m comment --comment "generated for Multipass network mpqemubr0" -j ACCEPT

# get target rule
#new_rule=$(iptables-legacy-save | grep -- ' FORWARD .* --ctstate RELATED,ESTABLISHED ' | cut -d' ' -f3- | sed -e 's/ RELATED/ NEW,RELATED/' -e 's@"@\\"@g')
new_rule=$(iptables-legacy-save | grep -- ' FORWARD .* --ctstate RELATED,ESTABLISHED ' | cut -d' ' -f3- | sed -e 's/ RELATED/ NEW,RELATED/')
matches=$(echo "$new_rule" | wc -l)
if [ $matches -lt 1 ]; then
    echo "failed to discover FORWARD rule target" >&2
    exit 2
elif [ $matches -gt 1 ]; then
    echo "found too many matching FORWARD rule targets" >&2
    exit 3
fi

# get target rule number
output=$(iptables-legacy -t filter -L FORWARD --line-numbers| grep ' RELATED,ESTABLISHED')
rule_num=$(echo "$output" | cut -d' ' -f1)

# replace the rule
eval iptables-legacy -t filter -R FORWARD $rule_num "$new_rule"

# persist the changes
iptables-legacy-save > /etc/iptables/rules-legacy.v4

