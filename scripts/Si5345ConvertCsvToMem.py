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

# Init the counter
cnt = 0

# Open the output file
ofd = open(args.memPath, 'w')

# Power down during the configuration load
ofd.write('001E' + '01' + ',')
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

# Execute the Page5.BW_UPDATE_PLL command
ofd.write('0514' + '01' + ',')
ofd.write('0514' + '00' + ',')
cnt = cnt + 2

# Power Up after the configuration load
ofd.write('001E' + '00' + ',')
cnt = cnt + 1

# Clear the internal error flags
ofd.write('0011' + '01' + ',')
cnt = cnt + 1

# Fill the reset of the BRAM with zeros
for i in range(1024-cnt):
    ofd.write('0000' + '00' + ',')
    cnt = cnt + 1

# Close the file
ofd.close()
