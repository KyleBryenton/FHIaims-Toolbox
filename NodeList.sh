#!/bin/bash

# K R Bryenton 2024-02-19
# Code by Alberto, on Erin's request to have something that expands a list of nodes from a string like "cl[020,046-049,056-058]"
# https://discord.com/channels/376844752978444289/700346999362420788/1209223405761470534

if [ -z "$1" ]; then
    echo "Usage Example: $0 cl[020,046-049,056-058]"
    exit 1
fi

input_str="$1"

eval echo $(echo "$input_str" | sed 's/^.*\[//;s/\].*$//;s/,/ /g;s/\([0-9]*\)-\([0-9]*\)/{\1..\2}/g') | sed 's/\([0-9]*\)/cl\1/g'
