
# How to pair up your football Roomba

## Table of contents

#TODO

#### 1. Manually
##### a. Ubuntu

This has been tested on Ubuntu 22.04.  
You will require `bluetoothctl` and `rfcomm` but they should be installed by default

To pair a robot, start by opening a terminal and start `bluetoothctl`

[Screenshot of bluetoothctl interface]

Start discovering nearby devices by entering `scan on`.  
Wait a few seconds, then you can disable active scanning with `scan off`

Get the current devices nearby with the `devices` command.  
Ensure that your robots are powered on, and that you've enabled Bluetooth.

[Screenshot of `devices` output]

**Note : If you do not see devices with the name RSK, try disconnecting your Bluetooth adapter and reconnecting it**

Now for each RSK device shown, grab its MAC address, the second field of each output, then execute `pair ` followed by the MAC address.  
The robots shouldn't be asking for any PIN code, if they do, just enter 1234. If that PIN is wrong, check the robot-soccer-kit wiki  

[Screenshot of asking for pin]

Most of the time, it is just waiting for you to confirm if a certain PIN code matches. Just enter `yes`

[Screenshot of asking for matching confirmation]

Once you've done this, your RSK device should be successfully paired !  
But wait, this doesn't mean it is useable just yet. You still need to mount it.
