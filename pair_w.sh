#!/bin/bash

# This will discover nearby active Bluetooth devices
# and return the MAC adresses of the RSK robots
function grab_rsk_devices() {
	# Grab MAC adresses of only RSK devices
	devices=$(bluetoothctl devices | grep SHIELD)
	echo $devices
}

# Pairs a single BT device
# Params :
# 	device - MAC Adress of a RSK robot
function pair_robot() {

	device_name=$1
	device_mac=$2

	echo "${device_name} - ${device_mac}\n" >> $BT_LOG_FILE

	# Starts an asynchronous pairing
	coproc BTCTL (bluetoothctl pair $device_mac)

	# Grab pairing status, to guess if we need to enter PIN or just type in yes
	# We use the file descriptor of the asynchronous process
	# to achieve this (0 for output, 1 for input)
	while IFS= read -r -u line;
	do
		# Log the output
		echo $line >> $BT_LOG_FILE

		# Check whether we confirm passkey or enter pin code
		if [ echo $line | grep -q "Enter PIN code:" ]; then
			# Send 1234 to ${BTCTL[1]} which is like a user-input
			echo "1234" >& "${BTCTL[1]}"
			sleep 1 # wait a bit to finish pairing

		elif [ echo $line | grep -q "Confirm passkey" ]; then
			# Just reply yes to pair device
			echo "y" >& "${BTCTL[1]}"

		# In case pairing is successful
		elif [ $line -eq "Pairing successful" ]; then
			# Another check to see if device paired correctly (is this necessary ? probably not)
			paired=$(bluetoothctl paired-devices | grep $device_mac)
			if [ $paired -eq "" ]; then
				echo "Unknown Error : Pairing of ${device_name} has failed, please pair manually"
				echo "$device_name\n" > $FAILED_LOG_FILE
			else
				echo "${device_name} paired successfully !"
			fi
			break

		elif [ echo $line | grep -q "Failed to pair" ]; then
			echo "${device_name} could not be paired. Reason : ${line} \n Check ${BT_LOG_FILE} for more info"
			break
		fi
	done < "${BTCTL[0]}"

	# After pairing, we kill the coprocess
	kill -9 $BTCTL_PID

}

function log_setup() {
	FAILED_LOG_FILE="failed_pairings.log"
	echo "" > $FAILED_LOG_FILE
	BT_LOG_FILE="bluetoothctl_pairing.log"
	echo "" > $BT_LOG_FILE
	SCAN_LOG_FILE="bluetoothctl_scan_on.log"
	echo "" > $SCAN_LOG_FILE
}

function main() {
	log_setup
	echo "Starting discovery..."
	# Start discovering bluetooth devices in the background
	bluetoothctl scan on & >>$SCAN_LOG_FILE 2>>$SCAN_LOG_FILE
	scanpid=$!
	# Wait for devices to be discovered
	sleep 3

	new_devices=$(grab_rsk_devices)
	alr_paired=$(bluetoothctl paired-devices)

	# Stop the discovery process
	kill -9 $scanpid

	for devi in $new_devices;
	do
		devi_name=$(echo $devi | cut -f1 -d" ")
		devi_mac=$(echo $devi | cut -f2 -d" ")

		# Dupe check taken from RSK's github - pair.sh script
		dupe=$(echo $alr_paired | grep $devi_mac)
		echo "Current dupe is : ${dupe}"
		if [ -z "$dupe" ]; then
			pair_robot $devi_name $devi_mac
		fi
	done
}

main
