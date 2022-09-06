#!/bin/bash

# This will discover nearby active Bluetooth devices
# and return the MAC adresses of the RSK robots
function discover_rsk_devices() {
	# Start discovering bluetooth devices for n seconds
	timeout 5 bluetoothctl scan on
	# Grab MAC adresses of only RSK devices
	devices=$(bluetoothctl devices | grep RSK)
	return $devices
}

# Pairs a single BT device
# Params :
# 	device - MAC Adress of a RSK robot
function pair_robot() {
	
	device_name=$1
	device_mac=$2

	# Starts an asynchronous pairing
	coproc BTCTL (bluetoothctl pair $device_mac)

	# Grab pairing status, to guess if we need to enter PIN or just type in yes
	# We use the file descriptor of the asynchronous process
	# to achieve this (0 for output, 1 for input)
	while IFS= read -r -u "${BTCTL[0]}" line;
	do
		if [ echo $line | grep -q "Enter PIN code:" ]; then
			# Send 1234 to ${BTCTL[1]} which is like a user-input
			echo "1234" >& "${BTCTL[1]}"
			sleep 1 # wait a bit to finish pairing

		elif [ echo $line | grep -q "Confirm passkey" ]; then
			echo "y" >& "${BTCTL[1]}"

		elif [ line = "Pairing successful" ];
			paired=$(bluetoothctl paired-devices | grep $device_mac)
			if [ $paired -eq "" ]; then
				echo "Pairing of ${device_name} has failed, please pair manually"
				echo "$device_name\n" > $LOG_FILE
			else;
				echo "${device_name} paired successfully !"
			fi
			break

		fi
	done

	# After pairing, we kill the coprocess
	kill -9 BTCTL_PID

}

function main() {
	LOG_FILE="failed_pairings.log"
	new_devices=$(discover_rsk_devices)
	#alr_paired=$(bluetoothctl paired-devices)
	dev_macs=$(echo $"{new_devices}" | cut -f2 -d" ")

	# TODO : check for already paired devices
	for devi in $new_devices do
		devi_name=$(echo $devi | cut -f1 -d" ")
		devi_mac=$(echo $devi | cut -f2 -d" ")
		pair_robot $devi_name $devi_mac
	done
}

main
