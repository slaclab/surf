#-----------------------------------------------------------------------------
# Title      : PyRogue AXI-Lite Micron N25Q and Micron MT25Q PROM
#-----------------------------------------------------------------------------
# Description:
# PyRogue AXI-Lite Micron N25Q and Micron MT25Q PROM
#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue   as pr
import surf.misc
import click
import time
import datetime
import math

class AxiMicronN25Q(pr.Device):
    def __init__(self,
            description = "AXI-Lite Micron N25Q and Micron MT25Q PROM",
            addrMode    = True, # False = 24-bit Address mode, True = 32-bit Address Mode
            tryCount    = 5,
            hidden      = True,
            **kwargs):

        super().__init__(
            description = description,
            hidden      = hidden,
            **kwargs)

        self._mcs      = surf.misc.McsReader()
        self._addrMode = addrMode
        self._progDone = False
        self._tryCount = tryCount

        ##############################
        # Setup variables
        ##############################
        self.add(pr.RemoteVariable(
            name        = 'PasswordLock',
            offset      = 0x00,
            base        = pr.UInt,
            bitSize     = 32,
            bitOffset   = 0,
            retryCount  = tryCount,
            updateNotify= False,
            bulkOpEn    = False,
            hidden      = True,
            verify      = False,
        ))

        self.add(pr.RemoteVariable(
            name        = 'ModeReg',
            offset      = 0x04,
            base        = pr.UInt,
            bitSize     = 32,
            bitOffset   = 0,
            retryCount  = tryCount,
            updateNotify= False,
            bulkOpEn    = False,
            hidden      = True,
            verify      = False,
        ))

        self.add(pr.RemoteVariable(
            name        = 'AddrReg',
            offset      = 0x08,
            base        = pr.UInt,
            bitSize     = 32,
            bitOffset   = 0,
            retryCount  = tryCount,
            updateNotify= False,
            bulkOpEn    = False,
            hidden      = True,
            verify      = False,
        ))

        self.add(pr.RemoteVariable(
            name        = 'CmdReg',
            offset      = 0x0C,
            base        = pr.UInt,
            bitSize     = 32,
            bitOffset   = 0,
            retryCount  = tryCount,
            updateNotify= False,
            bulkOpEn    = False,
            hidden      = True,
            verify      = False,
        ))

        self.add(pr.RemoteVariable(
            name        = 'DataReg',
            offset      = 0x200,
            base        = pr.UInt,
            bitSize     = 32*64,
            bitOffset   = 0,
            numValues   = 64,
            valueBits   = 32,
            valueStride = 32,
            retryCount  = tryCount,
            updateNotify= False,
            bulkOpEn    = False,
            hidden      = True,
            verify      = False,
            groups      = ['NoStream','NoState','NoConfig'], # Not saving config/state to YAML
        ))

        ##############################
        # Constants
        ##############################

        self.READ_3BYTE_CMD  = (0x03 << 16)
        self.READ_4BYTE_CMD  = (0x13 << 16)

        self.FLAG_STATUS_REG = (0x70 << 16)
        self.FLAG_STATUS_RDY = (0x80)

        self.WRITE_ENABLE_CMD  = (0x06 << 16)
        self.WRITE_DISABLE_CMD = (0x04 << 16)

        self.ADDR_ENTER_CMD = (0xB7 << 16)
        self.ADDR_EXIT_CMD  = (0xE9 << 16)

        self.ERASE_3BYTE_CMD  = (0xD8 << 16)
        self.ERASE_4BYTE_CMD  = self.ERASE_3BYTE_CMD

        self.WRITE_3BYTE_CMD  = (0x02 << 16)
        self.WRITE_4BYTE_CMD  = self.WRITE_3BYTE_CMD

        self.STATUS_REG_WR_CMD = (0x01 << 16)
        self.STATUS_REG_RD_CMD = (0x05 << 16)

        self.DEV_ID_RD_CMD = (0x9F << 16)

        self.WRITE_NONVOLATILE_CONFIG = (0xB1 << 16)
        self.WRITE_VOLATILE_CONFIG    = (0x81 << 16)
        self.READ_NONVOLATILE_CONFIG  = (0xB5 << 16)
        self.READ_VOLATILE_CONFIG     = (0x85 << 16)

        ##########################
        ## Configuration Register:
        ##########################
        ## BIT[15:12] Number of dummy clock cycles = 0xF    (default)
        ## BIT[11:09] XIP mode at power-on reset = 0x7      (default)
        ## BIT[08:06] Output driver strength = x7           (default)
        ## BIT[05:05] Double transfer rate protocol = 0x1   (default)
        ## BIT[04:04] Reset/hold = 0x1                      (default)
        ## BIT[03:03] Quad I/O protocol = 0x1               (default)
        ## BIT[02:02] Dual I/O protocol = 0x1               (default)
        ## BIT[01:01] 128Mb segment select = 0x1            (default)
        ## BIT[00:00] 1 = Enable 3-byte address mode        (default)
        ## BIT[00:00] 0 = Enable 4-byte address mode
        self.DEFAULT_3BYTE_CONFIG = 0xFFFF
        self.DEFAULT_4BYTE_CONFIG = 0xFFFE

        self.READ_MASK   = 0x00000000
        self.WRITE_MASK  = 0x80000000
        self.VERIFY_MASK = 0x40000000

        self.add(pr.LocalCommand(
            name        = 'LoadMcsFile',
            function    = self._LoadMcsFile,
            description = 'Load the .MCS into PROM',
            value       = '',
        ))

    def _LoadMcsFile(self,arg,iprogPrint=True):
        # arg = value

        click.secho( f'{self.path}.LoadMcsFile: {arg}', fg='green')
        self._progDone = False

        # Start time measurement for profiling
        start = time.time()

        # Reset the SPI interface
        self.resetFlash()

        # Print the status registers
        print("PROM Manufacturer ID Code  = {}".format(hex(self.getManufacturerId())))
        print("PROM Manufacturer Type     = {}".format(hex(self.getManufacturerType())))
        print("PROM Manufacturer Capacity = {}".format(hex(self.getManufacturerCapacity())))
        print("PROM Status Register       = {}".format(hex(self.getPromStatusReg())))
        print("PROM Volatile Config Reg   = {}".format(hex(self.getPromConfigReg())))

        # Open the MCS file
        self._mcs.open(arg)

        # Erase the PROM
        self.eraseProm()

        # Write to the PROM
        self.writeProm()

        # Verify the PROM
        self.verifyProm()

        # End time measurement for profiling
        end = time.time()
        elapsed = end - start
        click.secho( f'LoadMcsFile() took {datetime.timedelta(seconds=int(elapsed))} to program the PROM', fg='green')

        # Add a power cycle reminder
        self._progDone = True
        if iprogPrint:
            click.secho(
                "\n\n\
                ***************************************************\n\
                ***************************************************\n\
                The MCS data has been written into the PROM.       \n\
                To reprogram the FPGA with the new PROM data,      \n\
                a IPROG CMD or power cycle is be required.\n\
                ***************************************************\n\
                ***************************************************\n\n"
                , bg='green',
            )

    def eraseProm(self):
        # Set the starting address index
        address    = self._mcs.startAddr
        # 64kB per sector
        ERASE_SIZE = 0x10000
        # Setup the status bar
        with click.progressbar(
            iterable = range(math.ceil(self._mcs.size/ERASE_SIZE)),
            label    = click.style('Erasing PROM:  ', fg='green'),
        ) as bar:
            for i in bar:
                # Execute the erase command
                self.eraseCmd(address)
                # Increment by one block
                address += ERASE_SIZE
        # Check the corner case
        if ( address<=self._mcs.endAddr ):
            self.eraseCmd(address)

    def writeProm(self):
        # Initialize the variables
        wordCnt = 0
        byteCnt = 0
        # Create a burst data array
        dataArray = self.getDataReg(read=False)
        # Setup the status bar
        with click.progressbar(
            length   = self._mcs.size,
            label    = click.style('Writing PROM:  ', fg='green'),
        ) as bar:
            for i in range(self._mcs.size):
                # Check for first byte of burst transfer
                if ( (i&0xFFF) == 0):
                    # Throttle down printf rate
                    bar.update(0xFFF)
                # Get the start bursting address
                if ( (byteCnt==0) and (wordCnt==0) ):
                    addr = int(self._mcs.entry[i][0])
                # Pack the bytes into a 32-bit word
                if ( byteCnt==0 ):
                    wrd = (int(self._mcs.entry[i][1]) & 0xFF) << (8*(3-byteCnt))
                else:
                    wrd |= (int(self._mcs.entry[i][1]) & 0xFF) << (8*(3-byteCnt))
                # Increment the counter
                byteCnt += 1
                # Check the byte counter
                if ( byteCnt==4 ):
                    byteCnt = 0
                    dataArray[wordCnt] = wrd
                    wordCnt += 1
                    if ( wordCnt==64 ):
                        wordCnt = 0
                        self.setDataReg(dataArray)
                        self.writeCmd(addr)
            # Close the status bar
            bar.update(self._mcs.size)

        # Check for leftover data
        if ( (wordCnt != 0) or (byteCnt != 0) ):
            while (wordCnt != 64):
                # Pack the bytes into a 32-bit word
                if ( byteCnt==0 ):
                    wrd = (0xFF) << (8*(3-byteCnt))
                else:
                    wrd |= (0xFF) << (8*(3-byteCnt))
                # Increment the counter
                byteCnt += 1
                # Check the byte counter
                if ( byteCnt==4 ):
                    byteCnt = 0
                    dataArray[wordCnt] = wrd
                    wordCnt += 1
                    if ( wordCnt==64 ):
                        self.setDataReg(dataArray)
                        self.writeCmd(addr)
                        break

    def verifyProm(self):
        # Wait for last transaction to finish
        self.waitForFlashReady()
        # Initialize the variables
        wordCnt = 0
        byteCnt = 0
        # Setup the status bar
        with click.progressbar(
            length  = self._mcs.size,
            label   = click.style('Verifying PROM:', fg='green'),
        ) as bar:
            for i in range(self._mcs.size):
                # Check for first byte of burst transfer
                if ( (i&0xFFF) == 0):
                    # Throttle down printf rate
                    bar.update(0xFFF)
                # Get the start bursting address
                if ( (byteCnt==0) and (wordCnt==0) ):
                    # Start address of a burst transfer
                    self.readCmd(int(self._mcs.entry[i][0]))
                    # Get the data
                    dataArray = self.getDataReg()
                # Get the data/addr for MCS file
                data = int(self._mcs.entry[i][1])
                addr = int(self._mcs.entry[i][0])
                # Get the prom data from data array
                prom = ((dataArray[wordCnt] >> 8*(3-byteCnt)) & 0xFF)
                # Compare PROM to file
                if (data != prom):
                    click.secho(f'\nAddr = 0x{addr:x}: MCS = 0x{data:x} != PROM = 0x{prom:x}', fg='red')
                    raise surf.misc.McsException('verifyProm() Failed\n\n')
                # Increment the counter
                byteCnt += 1
                # Check the byte counter
                if ( byteCnt==4 ):
                    byteCnt = 0
                    wordCnt += 1
                    if ( wordCnt==64 ):
                        wordCnt = 0
            # Close the status bar
            bar.update(self._mcs.size)

    def eraseCmd(self, address):
        self.setAddrReg(address)
        if (self._addrMode):
            self.setCmd(self.WRITE_MASK|self.ERASE_4BYTE_CMD|0x4)
        else:
            self.setCmd(self.WRITE_MASK|self.ERASE_3BYTE_CMD|0x3)

    def writeCmd(self, address):
        self.setAddrReg(address)
        if (self._addrMode):
            self.setCmd(self.WRITE_MASK|self.WRITE_4BYTE_CMD|0x104)
        else:
            self.setCmd(self.WRITE_MASK|self.WRITE_3BYTE_CMD|0x103)

    def readCmd(self, address):
        self.setAddrReg(address)
        if (self._addrMode):
            self.setCmd(self.READ_MASK|self.READ_4BYTE_CMD|0x104)
        else:
            self.setCmd(self.READ_MASK|self.READ_3BYTE_CMD|0x103)

    def setPromStatusReg(self, value):
        if (self._addrMode):
            self.setAddrReg((value&0xFF)<<24)
            self.setCmd(self.WRITE_MASK|self.STATUS_REG_WR_CMD|0x1)
        else:
            self.setAddrReg((value&0xFF)<<16)
            self.setCmd(self.WRITE_MASK|self.STATUS_REG_WR_CMD|0x1)

    def getPromStatusReg(self):
        self.setCmd(self.READ_MASK|self.STATUS_REG_RD_CMD|0x1)
        return (self.getCmdReg()&0xFF)

    def getPromConfigReg(self):
        self.setCmd(self.READ_MASK|self.READ_VOLATILE_CONFIG|0x1)
        return (self.getCmdReg()&0xFF)

    def getManufacturerId(self):
        self.setCmd(self.READ_MASK|self.DEV_ID_RD_CMD|0x1)
        return (self.getCmdReg()&0xFF)

    def getManufacturerType(self):
        self.setCmd(self.READ_MASK|self.DEV_ID_RD_CMD|0x2)
        return (self.getCmdReg()&0xFF)

    def getManufacturerCapacity(self):
        self.setCmd(self.READ_MASK|self.DEV_ID_RD_CMD|0x3)
        return (self.getCmdReg()&0xFF)

    def resetFlash(self):
        # Send the enable reset command
        self.setCmdReg(self.WRITE_MASK|(0x66 << 16))
        time.sleep(0.001)
        # Send the reset command
        self.setCmdReg(self.WRITE_MASK|(0x99 << 16))
        time.sleep(0.001)
        # Set the addressing mode
        self.setModeReg()
        # Check the address mode
        if (self._addrMode):
            self.setCmd(self.WRITE_MASK|self.ADDR_ENTER_CMD)
            self.setAddrReg(self.DEFAULT_4BYTE_CONFIG<<16)
            time.sleep(0.001)
            self.setCmd(self.WRITE_MASK|self.WRITE_NONVOLATILE_CONFIG|0x2)
            self.setCmd(self.WRITE_MASK|self.WRITE_VOLATILE_CONFIG|0x2)
        else:
            self.setCmd(self.WRITE_MASK|self.ADDR_EXIT_CMD)
            self.setAddrReg(self.DEFAULT_3BYTE_CONFIG<<8)
            time.sleep(0.001)
            self.setCmd(self.WRITE_MASK|self.WRITE_NONVOLATILE_CONFIG|0x2)
            self.setCmd(self.WRITE_MASK|self.WRITE_VOLATILE_CONFIG|0x2)

    def setCmd(self,value):
        if ( value&self.WRITE_MASK ):
            self.waitForFlashReady()
            self.setCmdReg(self.WRITE_MASK|self.WRITE_ENABLE_CMD)
            self.setCmdReg(value)
        else:
            self.setCmdReg(value)

    def waitForFlashReady(self):
        while True:
            # Get the status register
            self.setCmdReg(self.READ_MASK|self.FLAG_STATUS_REG|0x1)
            status = (self.getCmdReg()&0xFF)
            # Check if not busy
            if ( (status & self.FLAG_STATUS_RDY) != 0 ):
                break

    #########################################
    # Command wrappers
    #########################################
    def setModeReg(self):
        if (self._addrMode):
            self.ModeReg.set(value=0x1)
        else:
            self.ModeReg.set(value=0x0)

    def setAddrReg(self,value):
        self.AddrReg.set(value=value)

    def setCmdReg(self,value):
        self.CmdReg.set(value=value)

    def getCmdReg(self):
        return self.CmdReg.get()

    def setDataReg(self,values):
        self.DataReg.set(values)

    def getDataReg(self,read=True):
        return self.DataReg.get(read=read)
