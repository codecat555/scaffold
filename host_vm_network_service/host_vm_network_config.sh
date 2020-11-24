#!/bin/sh

# get target rule details
new_rule=$(iptables-legacy-save | grep -- ' FORWARD .* --ctstate RELATED,ESTABLISHED ' | cut -d' ' -f3- | sed -e 's/ RELATED/ NEW,RELATED/')
matches=$(echo "$new_rule" | wc -l)
if [ $matches -lt 1 ]; then
    echo "$0: failed to discover FORWARD rule target" >&2
    exit 2
elif [ $matches -gt 1 ]; then
    echo "$0: found too many matching FORWARD rule targets" >&2
    exit 3
fi

# get target rule number
output=$(iptables-legacy -t filter -L FORWARD --line-numbers| grep ' RELATED,ESTABLISHED')
rule_num=$(echo "$output" | cut -d' ' -f1)

# replace the rule
eval iptables-legacy -t filter -R FORWARD $rule_num "$new_rule"

exit 0

