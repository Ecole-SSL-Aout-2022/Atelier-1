# A note on bash colors
### ANSI color escape
To make some text appear colored in bash, there is a very precise syntax that the terminal understands, but that looks like weird characters when opened in a text editor like `gedit` for example

This might be **why** using grep with the `bluetoothctl` command (which has colouring in the terminal) made commands on its output like `grep` fail *miserably*

Here is a quick example
```bash
#!/bin/bash
echo -e "\x1b[1;33mHello"
```
This bit of code prints out Hello in bold yellow.
Let's study it a little bit
* `echo -e` tells echo to interpret special characters like '\n' for a new line. Pretty much needed for the example
* `\x1b` is the escape (ESC) character in hex, that we use to specify we're gonna give a color in this instance. You might also see `\e` and it's the same thing
* `[` The bracket starts the colouring statement
* `1` means we want a bold display. 0 for normal
* `;` is a separator, classic
* `33` is the ANSI color code the text will be displayed in, here yellow.
* `m` ends the colouring sequence


