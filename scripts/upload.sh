#!/bin/bash

# Flash with the latest firmware.
#
# This is for initial installs of EMS-ESP. After that use thw WebUI for updates or the online installer or Flash tool
#
# First argument is the COM port (mandatory), Otherwise it will autodetect the port. Use "auto" to force autodetect.
# Second argument (optional) can be anything, as is used to determine if we are using a dev release, for example:
#  ./upload.sh /dev/ttyUSB0
#  ./upload.sh auto dev
#
# The mandatory arguments are: mcu, board, flash_freq, flash_size, chip, bootloader_address
#

function yes_or_no {
  while true; do
    read -p "$* [y/n]: " yn
    case $yn in
    [Yy]*) return 0 ;;
    [Nn]*)
      echo ""
      echo "Exiting."
      return 1
      ;;
    esac
  done
}

# show welcome message
echo ""
echo -e "\e[32m"
echo "EMS-ESP firmware flash tool"
echo -e "\e[0m"

# if argument exists and is auto then we will autodetect the port
port_arg=""
if [ "$1" ]; then
  if [ "$1" != "auto" ]; then
    port_arg="--port $1"
  fi
fi

# Check if we can connect to the ESP32 on the COM port
# and get the PORT and MAC address
# Uses https://github.com/espressif/esp-idf/blob/master/components/esptool_py/esptool/esptool.py
echo "* Checking if an ESP32 is connected to the COM port..."

# Check the version of esptool.py and call the appropriate function
esptool_version=$(python ./scripts/local_esptool.py version | cut -d ' ' -f 2)
echo "* Using esptool.py version $esptool_version"

# Flash ID argument changes in esptool.py v5.x
# In v4.x it is `flash_id`, in v5.x it is `flash-id`
arg_flash_id="flash_id"
if [[ $esptool_version == 5.* ]]; then
  arg_flash_id="flash-id"
fi

# connect using esptool, and replace all newlines with a pipe
connect_info=$(python ./scripts/local_esptool.py $port_arg $arg_flash_id)
connect_error=$?
connect_info=$(echo "$connect_info" | tr -d '\r')
connect_info=${connect_info//[$'\r\n']/| }

# check for errors
if [[ $connect_error -ne 0 ]]; then
  echo ""
  echo "Failed to connect to ESP32. Exiting."
  echo ""
  exit 1
fi

function parse_esptool_pre_v5 {
  # Function to handle pre-v5 versions of esptool.py
  # Side-effect: sets the global variables `mac` and `port`

  # Input looks like this
  #
  # esptool.py v4.9.0
  # Serial port /dev/ttyCH341USB0
  # Connecting...
  # Failed to get PID of a device on /dev/ttyCH341USB0, using standard reset sequence.
  # ..
  # Detecting chip type... Unsupported detection protocol, switching and trying again...
  # Connecting...
  # Failed to get PID of a device on /dev/ttyCH341USB0, using standard reset sequence.
  # .
  # Detecting chip type... ESP32
  # Chip is ESP32-D0WD-V3 (revision v3.1)
  # Features: WiFi, BT, Dual Core, 240MHz, VRef calibration in efuse, Coding Scheme None
  # Crystal is 40MHz
  # MAC: <stripped>
  # Uploading stub...
  # Running stub...
  # Stub running...
  # Manufacturer: 5e
  # Device: 4016
  # Detected flash size: 4MB
  # Flash voltage set by a strapping pin to 3.3V
  # Hard resetting via RTS pin...

  # find MAC address
  mac=${connect_info##*MAC: }
  mac=${mac%%|*}
  mac=$(echo $mac | tr -d '[:space:]')

  if [[ $mac == *"esptool"* ]]; then
    echo ""
    echo "Can't find MAC address. Exiting."
    echo ""
    exit 1
  fi

  # find USB port
  port=${connect_info##*Serial port }
  port=${port%%|*}

  if [[ $port == *"esptool"* ]]; then
    echo ""
    echo "Can't find COM port. Exiting."
    echo ""
    exit 1
  fi
}

function parse_esptool_v5 {
  # Input looks like this
  #
  # esptool v5.0.0
  # Connected to ESP32 on /dev/ttyCH341USB0:
  # Chip type:          ESP32-D0WD-V3 (revision v3.1)
  # Features:           Wi-Fi, BT, Dual Core + LP Core, 240MHz, Vref calibration in eFuse, Coding Scheme None
  # Crystal frequency:  40MHz
  # MAC:                <stripped>
  # 
  # Stub flasher running.
  # 
  # Flash Memory Information:
  # =========================
  # Manufacturer: 5e
  # Device: 4016
  # Detected flash size: 4MB
  # Flash voltage set by a strapping pin: 3.3V
  # 
  # Hard resetting via RTS pin...

  # find MAC address
  mac=${connect_info##*MAC: }
  mac=${mac%%|*}
  mac=$(echo $mac | tr -d '[:space:]')
  if [[ $mac == *"esptool"* ]]; then
    echo ""
    echo "Can't find MAC address. Exiting."
    echo ""
    exit 1
  fi

  # find USB port
  port=${connect_info##*Connected to ESP32 on }
  port=${port%%:*}
  if [[ $port == *"esptool"* ]]; then
    echo ""
    echo "Can't find COM port. Exiting."
    echo ""
    exit 1
  fi
}

mac=""
port=""

if [[ $esptool_version == 5.* ]]; then
  parse_esptool_v5
else
  parse_esptool_pre_v5
fi

# Check if the required values are set
REQD_VALUES=("mcu" "board" "flash_freq" "flash_size" "chip" "bootloader_address")
(
  i=0
  for var_name in ${REQD_VALUES[@]}; do
    VALUE=${!var_name}
    i=$((i + 1))
    : ${VALUE:?$var_name is missing}
  done
) || exit 1

echo "* Fetching latest EMS-ESP firmware version from GitHub..."

# get the latest version from GH
if [ "$2" ]; then
  latest_version=$(gh release view latest -R emsesp/EMS-ESP32 --json name --jq '.name' | tr -d '"' | sed 's/Development Build v//')
else
  latest_version=$(gh release view -R emsesp/EMS-ESP32 --json name --jq '.name' | tr -d '"' | cut -c 2-)
fi

# replace periods with underscores
latest_version_underscore=$(echo $latest_version | tr '.' '_')

# build the firmware path
firmware_file="./firmware/EMS-ESP-$latest_version_underscore-$mcu.bin"

# verify we can find all the files
echo "* Verifying we have all the necessary build files..."

if [ ! -f $firmware_file ]; then
  echo "firmware_file $firmware_file not found!"
  exit 1
fi

# get current date
current_date=$(date)

# filename of firmware used
firmware_filename=$(basename $firmware_file)

echo ""
echo "The ESP32 will be flashed to port $port with the following:"
echo -e "\e[36m"
echo "  Firmware version: $latest_version"
echo "  Firmware filename: $firmware_filename"
echo "  Date/Time: $current_date"
echo "  MCU: $mcu"
echo "  MAC address: $mac"
echo -e "\e[0m"

yes_or_no "Continue?" || exit 1

# !! next line is for debugging !!
# if false; then

# erase flash
# echo ""
# echo "* Erasing all data on the ESP32...(please wait)"
# python ./scripts/local_esptool.py \
#   --port $port \
#   --chip $chip \
#   erase_flash
# ret=$?
# if [ $ret -ne 0 ]; then
#   echo "Failed to erase ESP32. Exiting."
#   echo ""
#   exit 1
# fi

# upload firmware
echo "* Installing firmware on the ESP32..."
python ./scripts/local_esptool.py \
  --port $port \
  --chip $chip \
  --baud 921600 \
  --before default_reset \
  --after hard_reset \
  write_flash \
  -z \
  --flash_mode dio \
  --flash_freq $flash_freq \
  --flash_size $flash_size \
  $bootloader_address \
  ./upload/$board/bootloader.bin \
  0x8000 \
  ./upload/$board/partitions.bin \
  0xe000 \
  ./upload/$board/boot_app0.bin \
  0x10000 \
  $firmware_file | grep 'Writing'

ret=$?
if [ $ret -ne 0 ]; then
  echo "Failed to install firmware. Exiting."
  echo ""
  exit 1
fi

# don't telnet if we don't know the port
# Connect using minicom. Note Alt-X or CTRL-A X is used to exit is running manually
# We'll wait a few seconds to allow the ESP32 to reboot
echo "* Connecting to the EMS-ESP via USB on port $port to fetch settings (this will take a few seconds)..."
sleep 3
MINICOM='-c on'
export MINICOM
/bin/rm -f console_capture.txt
(
  echo "show system"
  sleep 3
) | minicom -D $port -C console_capture.txt >/dev/null
echo -e "\e[36m"
grep " Version:" console_capture.txt
grep " Board profile:" console_capture.txt
grep " Model:" console_capture.txt
echo -e "\e[0m"
echo "Please verify that these above values are correct. If nothing is displayed, it could be the USB port doesn't allow i/o."

# if we got this far, everything went well

echo -e "\e[32m"
echo "ESP32 successfully flashed to v$latest_version."
echo -e "\e[0m"
echo ""
