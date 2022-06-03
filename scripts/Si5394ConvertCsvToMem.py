#-----------------------------------------------------------------------------
# This function converters the ClockBuilder Pro .cvs
# into a .MEM file that can be loaded into a BRAM in FW
#-----------------------------------------------------------------------------
# This file is part of 'SLAC Firmware Standard Library'.
# It is subject to the license terms in the LICENSE.txt file found in the
# top-level directory of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of 'SLAC Firmware Standard Library', including this file,
# may be copied, modified, propagated, or distributed except according to
# the terms contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import csv
import argparse

#################################################################

# Set the argument parser
parser = argparse.ArgumentParser()

# Add arguments
parser.add_argument(
    "--csvFile",
    type     = str,
    required = True,
    help     = "path to input ClockBuilder Pro .csv file",
)

# Add arguments
parser.add_argument(
    "--memPath",
    type     = str,
    required = True,
    help     = "path to output BRAM .mem file",
)

# Get the arguments
args = parser.parse_args()

#################################################################

# Open the output file
ofd = open(args.memPath, 'w')

##############################
# Start configuration preamble
##############################
# 0x0B24,0xC0
# 0x0B25,0x00
# 0x0540,0x01
##############################
ofd.write('0B24' + 'C0' + ',')
ofd.write('0B25' + '00' + ',')
ofd.write('0540' + '01' + ',')
cnt = 3 # Init the counter

#######################################################################
# Wait 300 ms for Grade A/B/C/D/J/K/L/M, Wait 625ms for Grade P/E
#######################################################################
#    Delay is worst case time for device to complete any calibration
#    that is running due to device state change previous to this script
#    being processed.
#######################################################################
#    0xFFFFFF is special code in firmware boot ROM to wait 625 ms
#######################################################################
ofd.write('FFFFFF' + ',')
cnt = cnt + 1

# Open the .CSV file
with open(args.csvFile) as csvfile:
    reader = csv.reader(csvfile, delimiter=',', quoting=csv.QUOTE_NONE)

    # Loop through the rows in the CSV file
    for row in reader:
        if (row[0]!='Address'):
            offset = row[0]
            data   = row[1]
            ofd.write(offset[2:] + data[2:] + ',')
            cnt = cnt + 1

###############################
# Start configuration postamble
###############################
# 0x0514,0x01
# 0x001C,0x01
# 0x0540,0x00
# 0x0B24,0xC3
# 0x0B25,0x02
###############################
ofd.write('0514' + '01' + ',')
ofd.write('001C' + '01' + ',')
ofd.write('0540' + '00' + ',')
ofd.write('0B24' + 'C3' + ',')
ofd.write('0B25' + '02' + ',')
cnt = cnt + 5

# Fill the reset of the BRAM with zeros
for i in range(1024-cnt):
    ofd.write('0000' + '00' + ',')

# Close the file
ofd.close()
