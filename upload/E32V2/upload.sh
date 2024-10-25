#!/bin/bash

# Flash with the latest firmware
#
# This is intended for the initial installation of EMS-ESP. After that, use the EMS-ESP WebUI for updates, the online installer on emsesp.org or download the EMS-ESP Flash tool
#
# The first argument is the COM port (optional) otherwise, it will autodetect the port
# Second argument (optional) can be anything, as is used to determine if we are using a dev release, for example:
#  ./upload.sh /dev/ttyUSB0
#  ./upload.sh /dev/ttyUSB0 dev
#

board="E32V2"

mcu="ESP32-16MB+"
flash_freq="40m"
flash_size="16MB"
chip="esp32"
bootloader_address="0x1000"

# call upload script
source ./scripts/upload.sh $1 $2
