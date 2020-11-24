#!/bin/bash

TIMEOUT=180

# loop until we see expected rule
start_time=$(/usr/bin/date +'%s')
while true; do
    # get target rule details
    matched_rule=$(iptables-legacy-save | grep -E -- ' FORWARD .* --ctstate (NEW,)?RELATED,ESTABLISHED ')
    if [ $? -eq 0 ]; then
        # found a matching rule
        break
    fi
    
    cur_time=$(/usr/bin/date +'%s')
    ((elapsed=$end_time - $cur_time))
    if [ $elapsed -gt $TIMEOUT ]; then
        echo "$0: timed out waiting to discover FORWARD rule target ($elapsed seconds elapsed)." >&2
        exit 1
    fi

    sleep 1
done
matches=$(echo "$matched_rule" | wc -l)
if [ $matches -gt 1 ]; then
    echo "$0: found too many matching FORWARD rule targets ($matches)" >&2
    exit 3
fi

echo $matched_rule |grep -E -- ' FORWARD .* --ctstate NEW,'
if [ $? -eq 0 ]; then
    # rule already exists, nothing to do
    exit 0
fi

new_rule=$(echo $matched_rule | cut -d' ' -f3- | sed -e 's/ RELATED/ NEW,RELATED/')

# get target rule number
output=$(iptables-legacy -t filter -L FORWARD --line-numbers| grep ' RELATED,ESTABLISHED')
rule_num=$(echo "$output" | cut -d' ' -f1)

# replace the rule
eval iptables-legacy -t filter -R FORWARD $rule_num "$new_rule"

exit 0

