##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

import os
import sys
import shutil

# Read in a file into a string
def readFile(src):
    with open (src,"r") as myfile:
        data = myfile.read().splitlines(True)
        myfile.close()
        return data

# Write out a file
def writeFile(src,data):
    with open (src,"w") as myfile:
        myfile.write(data)
        myfile.close()

# Add license text to a string
def genLicense(module,comment):
    data  = "%s This file is part of '%s'.\n" % (comment,module)
    data += "%s It is subject to the license terms in the LICENSE.txt file found in the \n" % (comment)
    data += "%s top-level directory of this distribution and at: \n" % (comment)
    data += "%s    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. \n" % (comment)
    data += "%s No part of '%s', including this file, \n" % (comment,module)
    data += "%s may be copied, modified, propagated, or distributed except according to \n" % (comment)
    data += "%s the terms contained in the LICENSE.txt file.\n" % (comment)
    return data

# Update a file
def updateFile(path,module,comment,log,script):
    old = readFile(path)
    new = ""
    found = False

    # Process each line
    for line in old:

        # File is already updated, stop
        if line.find("LICENSE.txt") > 0:
            log.write("Skipped:  %s\n" % (src))
            return

        # Look for existing copyright line
        elif line.find("Copyright") > 0:
            new += genLicense(module,comment)
            found = True

        # Pass on all other lines, convert newline
        else:
            new += line.replace('\r\n','\n')

    # Not found, add to start of file
    if not found:
        new = ""

        # need to preserve first line for scripts
        if script:
            new += old[0]
            st = 1
        else :
            st = 0

        # Add license wrapped with comment lines
        new += (comment * 39) + "\n"
        new += genLicense(module,comment)
        new += (comment * 39) + "\n"

        # Copy the rest of the file, convert newline
        for line in old[st:]:
            new += line.replace('\r\n','\n')

    # Show update file to user and ask if we should write
    idx = 0
    print ("\n" * 10)
    for line in new.splitlines(True):
        print (line),
        idx += 1

        if idx > 40:
            break

    print ( "\n\nFile: %s\n" % (path) )
    resp = str(input("Update File (y/n): "))

    if resp == "y":
        log.write("Updated:  %s\n" % (src))
        writeFile(src,new)
    else:
        log.write("Deferred: %s\n" % (src))

# Check args
if len(sys.argv) < 3:
    print ("Usage: apply_license.py root_dir module_name")
    exit()

module = sys.argv[2]
path   = sys.argv[1]

logFile = open (path + "/apply_license_log.txt","w")

# Copy license file
baseDir = os.path.realpath(__file__).split('surf')[0]
shutil.copy(baseDir+"surf/LICENSE.txt",path + "/LICENSE.txt")

# Walk directories recursively
for root,dirs,files in os.walk(path):
    for f in files:
        src = "%s/%s" % (root,f)
        ret = None

        # Skip .svn sub-directories
        if f.find(".svn") > 0:
            logFile.write("Ignored:  %s\n" % (src))

        # VHDL
        elif f.endswith(".vhd"):
            updateFile(src,module,"--",logFile,False)

        # C files
        elif f.endswith(".h") or f.endswith(".hh") or f.endswith(".c") or f.endswith(".cc") or f.endswith(".cpp"):
            updateFile(src,module,"//",logFile,False)

        # Verilog, Verilog, or System Verilog
        elif f.endswith(".v") or f.endswith(".vh") or f.endswith(".sv"):
            updateFile(src,module,"//",logFile,False)

        # TCL / XDC
        elif f.endswith(".tcl") or f.endswith(".xdc"):
            updateFile(src,module,"##",logFile,False)

        # Python
        elif f.endswith(".py"):
            updateFile(src,module,"##",logFile,True)

        # Unknown
        else:
            logFile.write("Unknown:  %s\n" % (src))
