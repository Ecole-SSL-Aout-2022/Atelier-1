#!/bin/bash


# This will discover nearby active Bluetooth devices
# and return the MAC adresses of the RSK robots
function discover_rsk_devices() {
	# Start discovering bluetooth devices for n seconds
	timeout 5 bluetoothctl scan on
	# Grab MAC adresses of only RSK devices
	devices=$(bluetoothctl devices | grep RSK | cut -f2 -d" ")
	return $devices
}

function main() {
	devices=$(discover_rsk_devices)
	echo "$devices" >
}

main
