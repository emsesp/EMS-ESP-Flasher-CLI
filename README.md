# EMS-ESP flash tool

## Fist time setup

- install the GitHub CLI (gh command) (<https://github.com/cli/cli/blob/trunk/docs/install_linux.md>). On an Apple Mac you can use `brew install gh`. The first time you'll need to authenticate with `gh auth login`.
- install the latest version of Python (<https://www.python.org/downloads/>)
- install pip (<https://realpython.com/what-is-pip/#using-pip-in-a-python-virtual-environment>)
- install the python libraries: `pip install -r requirements.txt`
- install `minicom` using `apt-get install minicom` on WSL2 or Linux. This is a simple terminal program to connect to the serial port of the device so we can Telnet to EMS-ESP and check if its working.
- make sure all the shell scripts are executable: `chmod +x *.sh`. Those are firmware/firmware.sh, upload/E32V2/upload.sh and upload/S3/upload.sh.
- optional for Windows/WSL: install `udbisp` to access the Windows COM ports. `winget install usbipd`. See <https://github.com/dorssel/usbipd-win>.

## Setting up

If you're running Python in a virtual environment, you need to activate it first:

- `python3 -m venv venv` to create the virtual environment
- `source ./venv/bin/activate` to enter it
- `pip install -r requirements.txt` to install the libraries

Important! Run all shell commands from the root directory of this project. If you can't access them, check the permissions and run `chmod +x *.sh` to make them executable.

## Step 1 - Building and Preparing

Run:

```sh
./firmware/firmware.sh
```

to fetch the latest EMS-ESP stable & development firmware binaries from the GitHub release page. They are placed in the `firmware` folder. Note, you will need to have the GitHub CLI is installed for this to work. See above.

## Step 2 - Uploading to the ESP32 device

Run the command using this syntax:

 ```sh
./upload/<board>/upload.sh [<port> | auto] [dev]
 ```

`<board>` is S3 or E32V2,
`<port>` is /dev/ttyUSB0, /dev/ttyACM0 or auto
`dev` is an optional parameter, indicating to install the latest dev fimrware version

 As an example, this will use the latest development firmware for an E32 V2 Gateway and the first COM port found:

 ```sh
./upload/E32V2/upload.sh auto dev
 ```

 or

 ```sh
 ./upload/S3/upload.sh auto dev
 ```

After a successful upload, it will try and connect to the EMS-ESP via the USB/serial port and output the board profile. Make sure you verify this. If nothing is shown then perhaps the USB doesn't support Serial/UART. You can manually check this using `minicom -D <port>`.

(Note: if you're using WSL2, use `usbipd list` from a DOS/PowerShell admin window to show all the available COM ports and then connect to one using a command like `usbipd attach -a -w -b 2-3` (after first binding it with for example `usbipd bind --busid 2-3`). Check on the Linux WSL2 whether you now have a USB port in `/dev` like `/dev/ttyUSB0` or `ttyACM0`.)
