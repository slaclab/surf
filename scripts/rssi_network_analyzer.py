#!/usr/bin/env python3
#-----------------------------------------------------------------------------
# This file is part of 'SLAC Firmware Standard Library'.
# It is subject to the license terms in the LICENSE.txt file found in the
# top-level directory of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of 'SLAC Firmware Standard Library', including this file,
# may be copied, modified, propagated, or distributed except according to
# the terms contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyshark
import sys


class RssiFrame(object):

    def __init__(self, *, packet, server):
        pdata = bytearray.fromhex(packet.udp.payload.replace(':',' '))

        self.server = server
        self.time = packet.sniff_timestamp
        self.syn = (pdata[0] & 0x80) != 0
        self.ack = (pdata[0] & 0x40) != 0
        self.rst = (pdata[0] & 0x10) != 0
        self.nul = (pdata[0] & 0x08) != 0
        self.bsy = (pdata[0] & 0x01) != 0
        self.eack = (pdata[0] & 0x20) != 0
        self.seqNum = pdata[2]
        self.ackNum = pdata[3]
        self.src = packet.ip.src
        self.dst = packet.ip.dst
        self.srcPort = int(packet.udp.srcport)
        self.dstPort = int(packet.udp.dstport)

        self.packVer = None
        self.frame = None
        self.pack = None
        self.tdest = None
        self.tid = None
        self.user = None
        self.id = None
        self.addr = None
        self.opcode = None

        if len(pdata) > 24:
            self.packVer  = pdata[8] & 0xF
            self.frame = int.from_bytes(pdata[8:10],byteorder='little') >> 4
            self.pack = int.from_bytes(pdata[10:13],byteorder='little')
            self.tdest = pdata[13]
            self.tid   = pdata[14]
            self.user  = pdata[15]

            self.id   = int.from_bytes(pdata[16:20],byteorder='little')
            self.addr = (int.from_bytes(pdata[20:24],byteorder='little') & 0x3FFFFFFF) << 2
            self.opcode = (pdata[23] >> 2) & 0x3

        self.good = True

        if pdata[1] != 8:
            print(f"Got bad header length: {pdata[1]}")
            self.good = False

        else:
            csum = sum([int.from_bytes(pdata[i:i+2], byteorder='big') for i in range(0,6,2)])
            csum = int((csum % 0x10000) + (csum / 0x10000)) ^ 0xFFFF

            esum = int.from_bytes(pdata[6:8], byteorder='big')

            if esum != csum:
                print(f"Got bad checksum. Exp={esum:#}, Got={csum:#}")
                self.good = False

        # subtract udp header + ssi header
        self.length = int(packet.udp.length) - 16

        #print(packet.udp.payload)
        #if self.srcPort == 8193 or self.dstPort == 8193:
            #print(self)


    def __str__(self):
        ret = f"Time = {self.time}, "
        ret += f"Src={self.src}:{self.srcPort}, "
        ret += f"Dst={self.dst}:{self.dstPort}, "
        ret += f"Server = {self.server}, "
        ret += f"Syn = {self.syn}, "
        ret += f"Ack = {self.ack}, "
        ret += f"Rst = {self.rst}, "
        ret += f"Nul = {self.nul}, "
        ret += f"Bsy = {self.bsy}, "
        ret += f"EAck = {self.eack}, "
        ret += f"Length = {self.length}, "
        ret += f"SeqNum = {self.seqNum}, "
        ret += f"AckNum = {self.ackNum}, "


        if self.srcPort == 8193 or self.dstPort == 8193:
            #ret += f"PackVer = {self.packVer}, "
            #ret += f"Frame = {self.frame}, "
            ret += f"Packet = {self.pack}, "
            ret += f"TDest = {self.tdest}, "
            #ret += f"TId = {self.tid}, "

            if self.pack == 0:
                ret += f"ID = {self.id:#x}, "
                ret += f"Addr = {self.addr:#x}, "
                ret += f"Op = {self.opcode}"

        return ret


class RssiLink(object):

    def __init__(self, *, server, port):
        self.server = server
        self.port = int(port)

        self._lastSeq = [None] * 2
        self._lastAck = [None] * 2

        self._lastFrames = []
        self._postDump = 0
        self._count = [0] * 2

    def rxPacket(self, *, packet, log=None, printAll=False):

        if 'ip' not in packet or 'udp' not in packet:
            return

        src = packet.ip.src
        dst = packet.ip.dst
        srcport = int(packet.udp.srcport)
        dstport = int(packet.udp.dstport)

        # Packet is from server
        if src == self.server and srcport == self.port:
            idx = 1

        # Packet is to Server
        elif dst == self.server and dstport == self.port:
            idx = 0

        # Not meant for us
        else:
            return

        frame = RssiFrame(packet=packet, server=idx)

        if not frame.good:
            return

        self._count[idx] += 1

        # Keep a ring buffer of the last 200 frames incase an error is found
        if len(self._lastFrames) == 200:
            self._lastFrames = self._lastFrames[1:]
        self._lastFrames.append(frame)

        # Lets wait until we get a few bi-directional frames
        if self._lastAck[0] is not None and self._lastSeq[0] is not None and self._lastAck[1] is not None and self._lastSeq[1] is not None:
            seqErr = False
            ackErr = False

            nxtSeq = int((self._lastSeq[idx] + 1) & 0xFF)

            # Sequence Number Error
            if (frame.length > 0 or frame.nul) and frame.seqNum != nxtSeq:
                seqErr = True

            # Create window of acceptable ack numbers, this is between the last ack sent and the last sequence received
            lastAck = self._lastAck[idx]
            lastSeq = self._lastSeq[idx ^ 0x1]

            ackList = [lastAck]

            while lastAck != lastSeq:
                lastAck = int((lastAck + 1) & 0xFF)
                ackList.append(lastAck)

            # Ack number error
            if frame.ackNum not in ackList:
                ackErr = True

            if seqErr or ackErr or frame.syn or frame.rst or frame.eack:
                msg = f"Error Unexepcted Frame. Server={self.server}, Port={self.port}. Dumping last frames.\n"
                self._postDump = 20

                for f in self._lastFrames:
                    msg += f"    {f}\n"

                if seqErr:
                    msg += f"    Got SeqNum={frame.seqNum}, Expected={nxtSeq}\n"

                if ackErr:
                    msg += f"    Got AckNum={frame.ackNum}, Expected={ackList}\n"

                if frame.syn:
                    msg += "    Got Syn\n"

                if frame.rst:
                    msg += "    Got Rst\n"

                if frame.eack:
                    msg += "    Got Eack\n"

                print(msg[:-1])

                if log is not None:
                    log.write(msg)
                    log.flush()

            elif self._postDump > 0:
                self._postDump -= 1
                msg = f"    {frame}\n"

                print(msg[:-1])

                if log is not None:
                    log.write(msg)
                    log.flush()

            elif printAll:
                msg = f"Got Frame. Server={self.server}, Port={self.port}. {frame}\n"
                print(msg[:-1])

                if log is not None:
                    log.write(msg)
                    log.flush()

        if frame.length > 0 or frame.nul:
            self._lastSeq[idx] = frame.seqNum

        if frame.ack:
            self._lastAck[idx] = frame.ackNum

    def __str__(self):
        return f"Server = {self.server}, Port = {self.port}, Server Count = {self._count[1]}, Client Count = {self._count[0]}"


def analyzeRssiDump(pcapFile, links, printAll):

    print(f"Opening {pcapFile}")
    print(f"Logging to {pcapFile}.txt")
    print("Monitoring Links:")
    for link in links:
        print(f"   {link}")

    with open(pcapFile + '.txt', 'w') as f:
        for c in pyshark.FileCapture(sys.argv[1]):
            for link in links:
                link.rxPacket(packet=c, log=f, printAll=printAll)

    print("Link Counts:")
    for link in links:
        print(f"   {link}")


if __name__ == "__main__":

    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} file.pcap")
        exit(1)

    links = [RssiLink(server='10.0.1.102', port=8193),
             RssiLink(server='10.0.1.102', port=8194),
             RssiLink(server='10.0.1.103', port=8193),
             RssiLink(server='10.0.1.103', port=8194),
             RssiLink(server='10.0.1.104', port=8193),
             RssiLink(server='10.0.1.104', port=8194),
             RssiLink(server='10.0.1.105', port=8193),
             RssiLink(server='10.0.1.105', port=8194),
             RssiLink(server='10.0.1.106', port=8193),
             RssiLink(server='10.0.1.106', port=8194),
             RssiLink(server='10.1.1.102', port=8193),
             RssiLink(server='10.1.1.102', port=8194),
             RssiLink(server='10.1.1.103', port=8193),
             RssiLink(server='10.1.1.103', port=8194),
             RssiLink(server='10.1.1.104', port=8193),
             RssiLink(server='10.1.1.104', port=8194),
             RssiLink(server='10.1.1.105', port=8193),
             RssiLink(server='10.1.1.105', port=8194),
             RssiLink(server='10.1.1.106', port=8193),
             RssiLink(server='10.1.1.106', port=8194)]

    analyzeRssiDump(sys.argv[1], links, False)

