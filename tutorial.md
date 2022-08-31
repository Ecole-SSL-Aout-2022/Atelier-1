
# How to pair up your football Roomba

### Table of contents

1. Manually
    a. Linux
    b. Windows

#### 1. Manually
##### a. Ubuntu

This has been tested on Ubuntu 22.04.
You will require `bluetoothctl` and `rfcomm` but they should be installed by default


To pair a robot, start by opening a terminal and start `bluetoothctl`

[Screenshot of bluetoothctl interface]

Get the current devices nearby with the `devices` command.
Ensure that your robots are powered on, and that you've enabled Bluetooth.

[Screenshot of `devices` output]

**Note : If you do not see devices with the name RSK**