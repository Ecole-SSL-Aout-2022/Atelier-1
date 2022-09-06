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

# Pairs a single BT device
function pair_robot() {

	# Starts an asynchronous pairing
	coproc BTCTL (bluetoothctl pair $device)

	# Grab pairing status, to guess if we need to enter PIN or just type in yes
	# We use the file descriptor of the asynchronous process
	# to achieve this (0 for output, 1 for input)
	while IFS= read -r -u "${BTCTL[0]}" line;
	do
		if [ echo $line | grep -q "Enter PIN code:" ]; then
			# Send 1234 to ${BTCTL[1]} which is like a user-input
			echo "1234" >& "${BTCTL[1]}"
			sleep 1 # wait a bit to finish pairing
			break #todo : check if paired correctly ? if not increase sleep time ?

		elif [ echo $line | grep -q "Confirm passkey" ]; then
			echo "y" >& "${BTCTL[1]}"
		elif [ line = "Pairing successful" ];
			break
		fi
	done

	# After pairing, we kill the coprocess
	kill -9 BTCTL_PID

}

function main() {
	devices=$(discover_rsk_devices)
}

main
