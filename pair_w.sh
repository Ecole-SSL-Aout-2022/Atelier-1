#!/bin/bash

# This will discover nearby active Bluetooth devices
# and return the MAC adresses of the RSK robots
function grab_rsk_devices() {
	# Grab MAC adresses of only RSK devices
	devices=$(bluetoothctl devices | grep "RSK")
	echo "$devices"
}

# Kills a process silently, without
# a warning message in STDOUT
function ninja_kill() {
	kill -9 $1
	wait $! 2>/dev/null
}

# Initializes any log files
# that we might need later on
function log_setup() {
	FAILED_LOG_FILE="failed_pairings.log"
	echo " " > $FAILED_LOG_FILE
	BT_LOG_FILE="bluetoothctl_pairing.log"
	echo " " > $BT_LOG_FILE
	NEW_DEVI_FILE="new_devices.log"
	echo " " > $NEW_DEVI_FILE
}

# Initializes some test aliases
# just to make the code more readable
function test_aliases() {
	alias asksForPin='[[ $(echo "$line" | grep -q "Enter PIN code:") ]]'
	alias asksConfirm='[[ "$(echo "$line" | grep -q "Confirm passkey")" ]]'
	alias pairSuccess='[[ "$($line -eq "Pairing successful")" ]]'
	alias failedToPair='[[ "$(echo "$line" | grep -q "Failed to pair")" ]]'
}

# Pairs a single BT device
# Params :
# 	device - MAC Adress of a RSK robot
function pair_robot() {

	device_name=$1
	device_mac=$2

	printf "%s- %s\n" "${device_name}" "${device_mac}" >> $BT_LOG_FILE

	# Starts an asynchronous pairing
	coproc BTCTL (bluetoothctl)

	echo "pair ${device_mac}" >& "${BTCTL[1]}"
	sleep 1

	# Grab pairing status, to guess if we need to enter PIN or just type in yes
	# We use the file descriptor of the asynchronous process
	# to achieve this (0 for output, 1 for input)
	while IFS="\n" read -r -u "${BTCTL[0]}" line;
	do
		# Remove color coding
		## Super sed command taken from https://stackoverflow.com/a/18000433
		line=$(echo $line | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2})?)?[mGK]//g")

		# Log the output
		echo "$line" >> $BT_LOG_FILE
		
		# Check whether we confirm passkey or enter pin code
		if asksForPin
		then
			# Send 1234 to ${BTCTL[1]} which is like a user-input
			echo "1234" >& "${BTCTL[1]}"
			sleep 1 # wait a bit to finish pairing

	 	elif asksConfirm
		then
			# Just reply yes to pair device
			echo "y" >& "${BTCTL[1]}"

		# In case pairing is successful
		elif pairSuccess
		then
			# Another check to see if device paired correctly (is this necessary ? probably not)
			paired=$(bluetoothctl paired-devices | grep "$device_mac")
			if [ "$("$paired" -eq "")" ]; then
				echo "Unknown Error : Pairing of ${device_name} has failed, please pair manually"
				echo "$device_name\n" > $FAILED_LOG_FILE
			else
				echo "${device_name} paired successfully !"
			fi

		elif failedToPair
		then
			printf "%s could not be paired. Reason : %s \n Check %s for more info" "${device_name}" "${line}" "${BT_LOG_FILE}"
		fi
	done

	# After pairing, we kill the coprocess
	ninja_kill "$BTCTL_PID"

}

# Starts discovering Bluetooth devices in a coprocess
# Apparently, if not in a coprocess it can collide with an existing one
# This is more of a safety measure more than anything
function discover_devices() {

	echo "Starting discovery..."

	# Start discovering bluetooth devices in the background
	coproc BT_SCAN (bluetoothctl)
	echo "scan on" >& "${BT_SCAN[1]}"

	# Wait for devices to be discovered
	sleep 5
	
	# Stop the discovery process
	echo "scan off" >& "${BT_SCAN[1]}"
	ninja_kill "$BT_SCAN_PID"

	echo "Discovery ended"
}

function main() {
	
	log_setup
	discover_devices

	new_devices=$(grab_rsk_devices)

	echo "$new_devices" > $NEW_DEVI_FILE

	if [[ -z "$new_devices" ]]
	then
		echo "No devices found..."
		return 0
	else
		printf "New devices found listed below :\n%s" "$new_devices"
		alr_paired=$(bluetoothctl paired-devices)
		while IFS="\n" read -r devi
		do
			echo "$devi"
			devi_name=$(echo "$devi" | cut -f3 -d" ")
			devi_mac=$(echo "$devi" | cut -f2 -d" ")

			echo "$devi_name"
			echo "$devi_mac"

			# Dupe check taken from RSK's github - pair.sh script
			dupe=$(echo "$alr_paired" | grep "$devi_mac")
			echo "Dupe is $dupe"
			if [ -z "$dupe" ]; then
				pair_robot "$devi_name" "$devi_mac"
			fi
			break
		done < $NEW_DEVI_FILE
	fi
}

main
