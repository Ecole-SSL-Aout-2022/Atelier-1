#!/bin/bash

# This will discover nearby active Bluetooth devices
# and return the MAC adresses of the RSK robots
function discover_rsk_devices() {
	# Start discovering bluetooth devices for 5 seconds
	### Note that timeout will halt the program until 5 seconds has passed
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

	echo "${device_name} - ${device_mac}\n" >> $BT_LOG_FILE

	# Starts an asynchronous pairing
	coproc BTCTL (bluetoothctl pair $device_mac)

	# Grab pairing status, to guess if we need to enter PIN or just type in yes
	# We use the file descriptor of the asynchronous process
	# to achieve this (0 for output, 1 for input)
	while IFS= read -r -u "${BTCTL[0]}" line;
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
	done

	# After pairing, we kill the coprocess
	kill -9 $BTCTL_PID

}

function main() {
	FAILED_LOG_FILE="failed_pairings.log"
	echo "" > $FAILED_LOG_FILE
	BT_LOG_FILE="bluetoothctl_pairing.log"
	echo "" > $BT_LOG_FILE

	new_devices=$(discover_rsk_devices)
	alr_paired=$(bluetoothctl paired-devices)

	for devi in $new_devices;
	do
		devi_name=$(echo $devi | cut -f1 -d" ")
		devi_mac=$(echo $devi | cut -f2 -d" ")

		# Dupe check taken from RSK's github - pair.sh script
		dupe=$(echo $alr_paired | grep $devi_mac)
		echo "$dupe"
		if [ "$dupe" -eq "" ]; then
			pair_robot $devi_name $devi_mac
		fi
	done
}

main
