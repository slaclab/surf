#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue as pr
import time

class Bootstrap(pr.Device):
    def __init__(self, GenDc=False, CoaXPressAxiL=None, **kwargs):
        super().__init__(**kwargs)
        self.CoaXPressAxiL = CoaXPressAxiL

        self.add(pr.RemoteVariable(
            name         = 'Standard',
            description  = 'This register shall provide a magic number indicating the Device implements the CoaXPress standard. The magic number shall be 0xC0A79AE5.',
            offset       = 0x00000000,
            base         = pr.UIntBE,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'Revision',
            description  = 'This register shall provide the version of the CoaXPress standard implemented by this Device.',
            offset       = 0x00000004,
            base         = pr.UIntBE,
            mode         = 'RO',
            hidden       = True,
        ))

        self.add(pr.LinkVariable(
            name         = 'DeviceRevisionUsed',
            linkedGet    = lambda: f'v{(self.Revision.value()>>16)&0xFFFF}.{self.Revision.value()&0xFFFF}',
            dependencies = [self.Revision],
        ))

        self.add(pr.RemoteVariable(
            name         = 'XmlManifestSize',
            description  = 'This register shall provide the number of XML manifests available. At least one manifest shall be available.',
            offset       = 0x00000008,
            base         = pr.UIntBE,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'XmlManifestSelector',
            description  = 'This register shall select the required XML manifest registers. It shall hold a number between 0 and XmlManifestSize – 1. A connection reset sets the value 0x00000000.',
            offset       = 0x0000000C,
            base         = pr.UIntBE,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'XMLMajorVersion',
            description  = 'The major version number of the XML file with respect to XmlManifestSelector',
            offset       = 0x00000010,
            base         = pr.UIntBE,
            bitSize      = 8,
            # bitOffset    = 16,
            bitOffset    = 8,
            mode         = 'RO',
            hidden       = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'XMLMinorVersion',
            description  = 'The minor version number of the XML file with respect to XmlManifestSelector',
            offset       = 0x00000010,
            base         = pr.UIntBE,
            bitSize      = 8,
            # bitOffset    = 8,
            bitOffset    = 16,
            mode         = 'RO',
            hidden       = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'XMLSubMinorVersion',
            description  = 'The sub-minor version number of the XML file with respect to XmlManifestSelector',
            offset       = 0x00000010,
            base         = pr.UIntBE,
            bitSize      = 8,
            # bitOffset    = 0,
            bitOffset    = 24,
            mode         = 'RO',
            hidden       = True,
        ))

        self.add(pr.LinkVariable(
            name         = 'XMLVersion',
            linkedGet    = lambda: f'v{self.XMLMajorVersion.value()}.{self.XMLMinorVersion.value()}.{self.XMLSubMinorVersion.value()}',
            dependencies = [self.XMLMajorVersion,self.XMLMinorVersion,self.XMLSubMinorVersion],
        ))

        self.add(pr.RemoteVariable(
            name         = 'SchemaMajorVersion',
            description  = 'The major version number of the schema used by the XML file with respect to XmlManifestSelector',
            offset       = 0x00000014,
            base         = pr.UIntBE,
            bitSize      = 8,
            # bitOffset    = 16,
            bitOffset    = 8,
            mode         = 'RO',
            hidden       = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'SchemaMinorVersion',
            description  = 'The minor version number of the schema used by the XML file with respect to XmlManifestSelector',
            offset       = 0x00000014,
            base         = pr.UIntBE,
            bitSize      = 8,
            # bitOffset    = 8,
            bitOffset    = 16,
            mode         = 'RO',
            hidden       = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'SchemaSubMinorVersion',
            description  = 'The sub-minor version number of the schema used by the XML file with respect to XmlManifestSelector',
            offset       = 0x00000014,
            base         = pr.UIntBE,
            bitSize      = 8,
            # bitOffset    = 0,
            bitOffset    = 24,
            mode         = 'RO',
            hidden       = True,
        ))

        self.add(pr.LinkVariable(
            name         = 'SchemaVersion',
            linkedGet    = lambda: f'v{self.SchemaMajorVersion.value()}.{self.SchemaMinorVersion.value()}.{self.SchemaSubMinorVersion.value()}',
            dependencies = [self.SchemaMajorVersion,self.SchemaMinorVersion,self.SchemaSubMinorVersion],
        ))

        self.add(pr.RemoteVariable(
            name         = 'XmlUrlAddress',
            description  = 'This register shall provide the address of the start of the URL string referenced by register XmlManifestSelector.',
            offset       = 0x00000018,
            base         = pr.UIntBE,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'Iidc2Address',
            description  = 'For Devices that support the IIDC2 protocol (section 2.2 ref 4), this register shall provide the address of the start of the IIDC2 register space.',
            offset       = 0x0000001C,
            base         = pr.UIntBE,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'DeviceVendorName',
            description  = 'This register shall provide the name of the manufacturer of the Device as a string.',
            offset       = 0x00002000,
            base         = pr.String,
            bitSize      = 8*32,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'DeviceModelName',
            description  = 'This register shall provide the model name of the Device as a string.',
            offset       = 0x00002020,
            base         = pr.String,
            bitSize      = 8*32,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'DeviceManufacturerInfo',
            description  = 'This register shall provide extended manufacturer-specific information about the Device as a string.',
            offset       = 0x00002040,
            base         = pr.String,
            bitSize      = 8*48,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'DeviceVersion',
            description  = 'This register shall provide the version of the Device as a string.',
            offset       = 0x00002070,
            base         = pr.String,
            bitSize      = 8*32,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'DeviceSerialNumber',
            description  = 'This register shall provide the serial number for the Device as a NULL-terminated string.',
            offset       = 0x000020B0,
            base         = pr.String,
            bitSize      = 8*16,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'DeviceUserID',
            description  = 'This register shall provide a user-programmable identifier for the Device as a string. The Device shall provide persistent storage for this register so the value is maintained when power is switched off.',
            offset       = 0x000020C0,
            base         = pr.String,
            bitSize      = 8*16,
            mode         = 'RW',
        ))

        # These registers shall only be supported if GenDC is supported, as indicated by CapabilityRegister bit GenDcSupported.
        if GenDc:
            self.add(pr.RemoteVariable(
                name         = 'GenDcPrefetchDescriptorAddress',
                description  = 'This register shall provide the address of the start of the GenDC prefetch descriptor, as defined by the GenDC specification.',
                offset       = 0x000020D0,
                base         = pr.UIntBE,
                mode         = 'RO',
            ))

            self.add(pr.RemoteVariable(
                name         = 'GenDcPrefetchDescriptorSize',
                description  = 'This register shall provide the size in bytes of the GenDC prefetch descriptor.',
                offset       = 0x000020D4,
                base         = pr.UIntBE,
                mode         = 'RO',
            ))

            self.add(pr.RemoteVariable(
                name         = 'GenDcFlowTableAddress',
                description  = 'This register shall provide the address of the start of the GenDC flow table, as defined by the GenDC specification.',
                offset       = 0x000020D8,
                base         = pr.UIntBE,
                mode         = 'RO',
            ))

            self.add(pr.RemoteVariable(
                name         = 'GenDcFlowTableSize',
                description  = 'This register shall provide the size in bytes of the GenDC flow table.',
                offset       = 0x000020DC,
                base         = pr.UIntBE,
                mode         = 'RO',
            ))

            self.add(pr.RemoteVariable(
                name         = 'GenDcContainerSize',
                description  = 'This register shall provide the size in bytes of the complete GenDC Container.',
                offset       = 0x000020E0,
                base         = pr.UIntBE,
                mode         = 'RO',
            ))

        self.add(pr.RemoteVariable(
            name         = 'WidthAddress',
            description  = '',
            offset       = 0x00003000,
            base         = pr.UIntBE,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'HeightAddress',
            description  = '',
            offset       = 0x00003004,
            base         = pr.UIntBE,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'AcquisitionModeAddress',
            description  = '',
            offset       = 0x00003008,
            base         = pr.UIntBE,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'AcquistionStartAddress',
            description  = '',
            offset       = 0x0000300C,
            base         = pr.UIntBE,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'AcquistionStopAddress',
            description  = '',
            offset       = 0x00003010,
            base         = pr.UIntBE,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'PixelFormatAddress',
            description  = '',
            offset       = 0x00003014,
            base         = pr.UIntBE,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'DeviceTapGeometryAddress',
            description  = '',
            offset       = 0x00003018,
            base         = pr.UIntBE,
            mode         = 'RO',
        ))

        self.add(pr.RemoteCommand(
            name         = 'ConnectionReset',
            description  = 'Writing the value 0x00000001 to this register shall provide Device connection reset. The Device shall also execute a connection reset after power-up.',
            offset       = 0x00004000,
            base         = pr.UIntBE,
            function     = lambda cmd: cmd.post(1),
        ))

        self.add(pr.RemoteVariable(
            name         = 'DeviceConnectionID',
            description  = 'This register shall provide the ID of the Device connection via which this register is read',
            offset       = 0x00004004,
            base         = pr.UIntBE,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'MasterHostConnectionID',
            description  = 'This register shall hold the Host Connection ID of the Host connection connected to the Device Master connection. The value 0x00000000 is reserved to indicate an unknown Host ID.',
            offset       = 0x00004008,
            base         = pr.UIntBE,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'ControlPacketSizeMax',
            description  = 'This register shall provide the maximum control packet size the Host can read from the Device, or write to the Device. The size is defined in bytes, and shall be a multiple of 4 bytes. The defined size is that of the entire packet, not just the payload.',
            offset       = 0x0000400C,
            base         = pr.UIntBE,
            mode         = 'RO',
            disp         = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name         = 'StreamPacketSizeMax',
            description  = 'This register shall hold the maximum stream packet size the Host can accept. The size is defined in bytes, and shall be a multiple of 4 bytes. The Device can use any packet size it wants to up to this size. The defined size is that of the entire packet, not just the payload.',
            offset       = 0x00004010,
            base         = pr.UIntBE,
            mode         = 'RW',
            disp         = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name         = 'ConnectionConfig',
            description  = 'This register shall hold a valid combination of the Device connection speed and number of active downconnections. Writing to this register shall set the connection speeds on the specified connections. It may also result in a corresponding speed change of the low speed upconnection.',
            offset       = 0x00004014,
            base         = pr.UIntBE,
            mode         = 'WO',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'NumberOfConnections',
            description  = 'This register shall hold a valid combination of the Device connection speed and number of active downconnections. Writing to this register shall set the connection speeds on the specified connections. It may also result in a corresponding speed change of the low speed upconnection.',
            offset       = 0x00004014,
            base         = pr.UIntBE,
            bitSize      = 16,
            # bitOffset    = 16,
            bitOffset    = 0,
            mode         = 'RO',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'ConnectionSpeed',
            description  = 'This register shall hold a valid combination of the Device connection speed and number of active downconnections. Writing to this register shall set the connection speeds on the specified connections. It may also result in a corresponding speed change of the low speed upconnection.',
            offset       = 0x00004014,
            base         = pr.UIntBE,
            bitSize      = 16,
            # bitOffset    = 0,
            bitOffset    = 16,
            mode         = 'RO',
            overlapEn    = True,
            enum         = {
                0x00: 'undefined',
                0x28: 'CXP_1',
                0x30: 'CXP_2',
                0x38: 'CXP_3',
                0x40: 'CXP_5',
                0x48: 'CXP_6',
                0x50: 'CXP_10',
                0x58: 'CXP_12',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'ConnectionConfigDefault',
            description  = 'This register shall provide the value of the ConnectionConfig register that allows the Device to operate in its recommended mode.',
            offset       = 0x00004018,
            base         = pr.UIntBE,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'TestMode',
            description  = 'Writing the value 0x00000001 to this register shall enable test packets transmission from Device to Host. The value 0x00000000 shall allow normal operation. When the value is changed from 0x00000001 to 0x00000000 the Device shall complete the packet of 1024 test words currently being transmitted.',
            offset       = 0x0000401C,
            base         = pr.UIntBE,
            mode         = 'RW',
            hidden       = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'TestErrorCountSelector',
            description  = 'This register shall select the required test count [TestErrorCountSelector] register',
            offset       = 0x00004020,
            base         = pr.UIntBE,
            mode         = 'RW',
            hidden       = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'TestErrorCount',
            description  = 'This register shall provide the current connection error count for the connection referred to by register TestErrorCountSelector.',
            offset       = 0x00004024,
            base         = pr.UIntBE,
            mode         = 'RO',
            hidden       = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'TestPacketCountTx',
            description  = 'This register shall provide the current transmitted connection test packet count for the connection referred to by register TestErrorCountSelector.',
            offset       = 0x00004028,
            base         = pr.UIntBE,
            bitSize      = 8*8,
            mode         = 'RO',
            hidden       = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'TestPacketCountRx',
            description  = 'This register shall provide the current received connection test packet count for the connection referred to by register TestErrorCountSelector.',
            offset       = 0x00004030,
            base         = pr.UIntBE,
            bitSize      = 8*8,
            mode         = 'RO',
            hidden       = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'ElectricalComplianceTest',
            description  = 'If implemented, this shall be a non-volatile register to support formal compliance testing of the Device. It shall not be used at any other time. Writing the value 0x00000000 shall allow normal operation.',
            offset       = 0x00004038,
            base         = pr.UIntBE,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'GenDcSupported',
            description  = 'Shall be 1 if the Device supports GenDC streaming (see section 10.5), otherwise shall be 0',
            offset       = 0x0000403C,
            base         = pr.UIntBE,
            bitSize      = 1,
            # bitOffset    = 3,
            bitOffset    = 3+24,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'ExtraLsTriggerSupported',
            description  = 'Shall be 1 if the Device supports additional LinkTrigger modes on the low speed upconnection (see Table 16), otherwise shall be 0',
            offset       = 0x0000403C,
            base         = pr.UIntBE,
            bitSize      = 1,
            # bitOffset    = 2,
            bitOffset    = 2+24,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LinkSharingSupported',
            description  = 'Shall be 1 if the Device supports link sharing (see section 11), otherwise shall be 0',
            offset       = 0x0000403C,
            base         = pr.UIntBE,
            bitSize      = 1,
            # bitOffset    = 1,
            bitOffset    = 1+24,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'HsUpConnectionSupported',
            description  = 'Shall be 1 if the Device supports a high speed upconnection, otherwise shall be 0',
            offset       = 0x0000403C,
            base         = pr.UIntBE,
            bitSize      = 1,
            # bitOffset    = 0,
            bitOffset    = 0+24,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'GenDcEnable',
            description  = 'Shall be 1 to enable GenDC streaming (see section 10.5), otherwise shall be 0. When this register is set to 1, all image streaming shall use GenDC.',
            offset       = 0x00004040,
            base         = pr.UIntBE,
            bitSize      = 1,
            # bitOffset    = 3,
            bitOffset    = 3+24,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'ExtraLsTriggerEnable',
            description  = 'Shall be 1 to enable additional LinkTrigger modes on the low speed upconnection (see Table 16), otherwise shall be 0',
            offset       = 0x00004040,
            base         = pr.UIntBE,
            bitSize      = 1,
            # bitOffset    = 2,
            bitOffset    = 2+24,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LinkSharingEnable',
            description  = 'Shall be 1 to enable link sharing (see section 11), otherwise shall be 0',
            offset       = 0x00004040,
            base         = pr.UIntBE,
            bitSize      = 1,
            # bitOffset    = 1,
            bitOffset    = 1+24,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'HsUpConnectionEnable',
            description  = 'Shall be 1 to enable to high speed upconnection (via the discovery process defined in section 12.1.5), otherwise shall be 0',
            offset       = 0x00004040,
            base         = pr.UIntBE,
            bitSize      = 1,
            # bitOffset    = 0,
            bitOffset    = 0+24,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'Version2p1Supported',
            description  = 'Shall be 1 if the Device supports CXP v2.1',
            offset       = 0x00004044,
            base         = pr.UIntBE,
            bitSize      = 1,
            # bitOffset    = 3,
            bitOffset    = 3+24,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'Version2p0Supported',
            description  = 'Shall be 1 if the Device supports CXP v2.0',
            offset       = 0x00004044,
            base         = pr.UIntBE,
            bitSize      = 1,
            # bitOffset    = 2,
            bitOffset    = 2+24,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'Version1p1Supported',
            description  = 'Shall be 1 if the Device supports CXP v1.1. Note that v1.1 support is mandatory to allow backwards compatibility – see section 12.1.4.',
            offset       = 0x00004044,
            base         = pr.UIntBE,
            bitSize      = 1,
            # bitOffset    = 1,
            bitOffset    = 1+24,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'Version1p0Supported',
            description  = 'Shall be 1 if the Device supports CXP v1.0',
            offset       = 0x00004044,
            base         = pr.UIntBE,
            bitSize      = 1,
            # bitOffset    = 0,
            bitOffset    = 0+24,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'VersionUsedCmd',
            description  = 'This register shall hold a valid combination of the Device connection speed and number of active downconnections. Writing to this register shall set the connection speeds on the specified connections. It may also result in a corresponding speed change of the low speed upconnection.',
            offset       = 0x00004048,
            base         = pr.UIntBE,
            mode         = 'WO',
            hidden       = True,
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'MajorVersionUsed',
            description  = 'This register shall provide the version of the CoaXPress standard used to communicate between the Device and Host. The register is set during Discovery (see section 12.1.4).',
            offset       = 0x00004048,
            base         = pr.UIntBE,
            bitSize      = 16,
            # bitOffset    = 16,
            bitOffset    = 0,
            mode         = 'RO',
            hidden       = True,
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'MinorVersionUsed',
            description  = 'This register shall provide the version of the CoaXPress standard used to communicate between the Device and Host. The register is set during Discovery (see section 12.1.4).',
            offset       = 0x00004048,
            base         = pr.UIntBE,
            bitSize      = 16,
            # bitOffset    = 0,
            bitOffset    = 16,
            mode         = 'RO',
            hidden       = True,
            overlapEn    = True,
        ))

        self.add(pr.LinkVariable(
            name         = 'VersionUsed',
            linkedGet    = lambda: f'v{self.MajorVersionUsed.value()}.{self.MinorVersionUsed.value()}',
            dependencies = [self.MajorVersionUsed,self.MinorVersionUsed],
        ))

    def DeviceDiscovery(self, arg=None):
        # Updates all the local device register values
        self.CoaXPressAxiL.readBlocks(recurse=True)
        self.CoaXPressAxiL.checkBlocks(recurse=True)

        # Switch to 20.83 Mb/s mode without tags and give device 1 second to downgrade speed
        self.CoaXPressAxiL.TxLsRate.set(0)
        self.CoaXPressAxiL.ConfigPktTag.set(0)
        self.CoaXPressAxiL.TxLsLaneEnable.set(1)
        time.sleep(1.0)

        # Execute a connection reset
        self.ConnectionReset()

        # Host shall wait 200ms to allow for the Device to complete connection configuration
        time.sleep(0.2)

        # Update local device register values with error handling
        try:
            self.readBlocks(recurse=True)
            self.checkBlocks(recurse=True)
        except Exception as e:
            raise RuntimeError(
                "Failed to communicate with the camera after ConnectionReset().\n"
                "This may indicate the camera is in a bad state or there's a hardware issue\n"
                "(e.g., faulty or loose cabling).\n"
                "Try power cycling the camera and verifying all connections before restarting the software."
            ) from e

        # Match the device revision to host revision
        self.VersionUsedCmd.set(self.Revision.value())

        # The Host shall read the ConnectionConfigDefault register to find the required bit rate
        # and number of connections operating at this bit rate
        ConnectionConfigDefault = arg if arg is not None else self.ConnectionConfigDefault.value()
        self.ConnectionConfig.set(ConnectionConfigDefault)

        # If the new high speed connection bit rate requires a change in low speed connection bit rate,
        # it shall also change the low speed upconnection speed to the value defined in Table 6.
        if (ConnectionConfigDefault & 0xFF) >= 0x50:
            # Switch to 41.66 Mb/s mode
            self.CoaXPressAxiL.TxLsRate.set(1)

        # After it is sending a stable low speed upconnection at the defined rate the Host
        # shall wait 200ms to allow the Device to complete connection re-configuration.
        time.sleep(0.5)

        # Updates all the local device register values
        self.readBlocks(recurse=True)
        self.checkBlocks(recurse=True)

        # Reset the RX lane index pointer and flush the elastic buffers
        self.CoaXPressAxiL.RxFsmRst()

        # Setup for 4KB packets
        self.StreamPacketSizeMax.set(4096)
