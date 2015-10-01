#!/bin/bash
if which nmap > /dev/null; then
	nmap -sP "$1"
else
	exit 1
fi

if which arp > /dev/null; then
	arp -n | grep -v "incomplete" | awk '/^[0-9]{1,3}/ { print $1, $3, "(Unknown)" }' > /tmp/arp_scan
elif which ip > /dev/null; then
	ip neigh | grep -v "FAILED" | awk '{ print $1, $5, "(Unknown)" }' > /tmp/arp_scan
else
	exit 1
fi
