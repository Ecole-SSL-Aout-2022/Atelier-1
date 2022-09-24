#!/bin/bash

# This will discover nearby active Bluetooth devices
# and return the MAC adresses of the RSK robots
function grab_rsk_devices() {
	# Grab MAC adresses of only RSK devices
	devices=$(bluetoothctl devices | grep "Soundcore")
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

# Checks what is the current status of pairing
# from a read line of the bluetoothctl command in a coprocess
# Params:
# 	- current_line | The line we are currently reading from bluetoothctl's output
function check_pairing_status() {
	
	current_line=$1
	device_mac=$2
	status=-42

	# Possible status-es
	# 1 is Asking for pin
	# 2 is Asks for confirmation
	# 0 is Pairing successful
	# -1 is Failed pairing

	grep -q "Enter PIN code:" <<< ${current_line}
	[ $? -eq 0 ] && status="1"

	grep -q "Confirm passkey" <<< ${current_line}
	[ $? -eq 0 ] && status="2"

	bluetoothctl paired-devices | grep -q "${device_mac}"
	[ $? -eq 0 ] && status="0"
	grep -q "Pairing successful" <<< ${current_line}
	[ $? -eq 0 ] && status="0"

	grep -q "Failed to pair" <<< ${current_line}
	[ $? -eq 0 ] && status="-1"

	echo $status
}

# Another check to see if device paired correctly (is this necessary ? probably not)
function recheck_pair_success() {
	paired=$(bluetoothctl paired-devices | grep "$device_mac" --line-buffered)
	if [[ -z "$paired" ]]; then
		echo "Unknown Error : Pairing of ${device_name} has failed, please pair manually"
		echo "$device_name\n" > $FAILED_LOG_FILE
	else
		echo "${device_name} paired successfully !"
	fi
}

# Sends 1234 to ${BTCTL[1]} which is like a user-input to the coprocess
function send_pincode() {
	echo "1234" >& "${BTCTL[1]}"
	sleep 1 # wait a bit to finish pairing
}

# Replies with 'y' to the coprocess
function send_yes() {
	echo "y" >& "${BTCTL[1]}"	
}

# Pairs a single BT device
# Params :
# 	device - MAC Adress of a RSK robot
function pair_robot() {

	device_name=$1
	device_mac=$2

	printf "### %s- %s\n" "${device_name}" "${device_mac} ###" >> $BT_LOG_FILE
	echo "Currently pairing ${device_name}.."

	# Start an asynchronous command using coproc
	coproc BTCTL (bash)
	echo "bluetoothctl" >& "${BTCTL[1]}"

	# Send the 'pair' command to the coprocess
	echo "pair ${device_mac}" >& "${BTCTL[1]}"
	# This wait time is just for bluetoothctl to do its stuff, better not rush the reading
	sleep 2

	# This big block manages the pairing of a device, depending
	# of the output of bluetoothctl. It manages 2 cases :
	# 	- Waiting for the user to confirm the PIN of the devices matches
	# 	- Waiting for the user to input a PIN code (legacy pairing)
	# It also catches wheter or not a device could be paired successfully
	
	# We use the file descriptors of the asynchronous process
	# to achieve this (0 for output, 1 for input)

	while IFS="\n" read -r -u "${BTCTL[0]}" line;
	do

		# Remove color coding
		## Super sed command taken from https://www.linuxquestions.org/questions/programming-9/control-bluetoothctl-with-scripting-4175615328/#post5850529
		## Added my tr's to remove some hex colors that came from color coding
		line=$(echo $line | sed -r 's/\x1B\[[0-9;]*[JKmsu]//g; s/\r/\n/g' | tr -d $'\x01' | tr -d $'\x02')

		# Log the output
		echo "$line" >> $BT_LOG_FILE

		# Launch the tests checking current status of pairing
		status=$(check_pairing_status "$line" "$device_mac")

		# Check whether we confirm passkey or enter pin code
		if [ $status -eq "1" ]
		then
			send_pincode

	 	elif [ $status -eq "2" ]
		then
			send_yes

		# In case pairing is successful
		elif [ $status -eq "0" ]
		then
			recheck_pair_success
			break

		# If pairing failed
		elif [ $status -eq "-1" ]
		then
			printf "%s could not be paired. Reason : %s \n Check %s for more info" "${device_name}" "${line}" "${BT_LOG_FILE}"
			break
		else
			continue
		fi
	done

	# After pairing, we kill the coprocess
	ninja_kill "$BTCTL_PID"

}

# Starts discovering Bluetooth devices in a coprocess
# Apparently, if not in a coprocess it can collide with an existing one
# This is more of a safety measure more than anything
function discover_devices() {

	echo "Restarting bluetooth..."
	rfkill block bluetooth
	sleep 1
	rfkill unblock bluetooth

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
		echo -e "New devices found listed below :\n$new_devices"
		alr_paired=$(bluetoothctl paired-devices)
		while IFS="\n" read -r devi
		do
			devi_name=$(echo "$devi" | cut -f3 -d" ")
			devi_mac=$(echo "$devi" | cut -f2 -d" ")

			# Dupe check taken from RSK's github - pair.sh script
			dupe=$(echo "$alr_paired" | grep "$devi_mac")

			if [ -z "$dupe" ]; then
				pair_robot "$devi_name" "$devi_mac"
			else
				echo "$devi_name is already paired !"
			fi
		done < $NEW_DEVI_FILE
		return 0
	fi
}

main
