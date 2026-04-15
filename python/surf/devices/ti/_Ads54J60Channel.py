#-----------------------------------------------------------------------------
# Description:
# PyRogue Ads54J60Channel Module
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

class Ads54J60Channel(pr.Device):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        #######################
        # Paging base addresses
        #######################
        mainDigital = (0x1 << 14)
        jesdDigital = (0x2 << 14)
        jesdAnalog  = (0x3 << 14)

        ###################
        # Main Digital Page
        ###################

        # self.add(pr.RemoteVariable(
            # name         = "PULSE_RESET",
            # description  = "Pulse reset for main digital page",
            # offset       = (mainDigital + (4*0x000)),
            # bitSize      = 1,
            # bitOffset    = 0,
            # base         = pr.UInt,
            # mode         = "RW",
        # ))

        self.add(pr.RemoteVariable(
            name        = "DECFIL_MODE3",
            description = "Decimation filter mode bit 3 extension",
            offset      = (mainDigital + (4*0x041)),
            bitSize     = 1,
            bitOffset   = 5,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "DECFIL_EN",
            description = "Decimation filter enable",
            offset      = (mainDigital + (4*0x041)),
            bitSize     = 1,
            bitOffset   = 4,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "DECFIL_MODE_2_0",
            description = "Decimation filter mode bits [2:0]",
            offset      = (mainDigital + (4*0x041)),
            bitSize     = 3,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "NYQUIST_ZONE",
            description = "Nyquist zone selection for DDC frequency planning",
            offset      = (mainDigital + (4*0x042)),
            bitSize     = 3,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "FORMAT_SEL",
            description = "Output data format selection (twos complement or offset binary)",
            offset      = (mainDigital + (4*0x043)),
            bitSize     = 1,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "DIGITAL_GAIN",
            description = "Digital gain value applied to ADC output data",
            offset      = (mainDigital + (4*0x044)),
            bitSize     = 7,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "FORMAT_EN",
            description = "Enable output data format conversion",
            offset      = (mainDigital + (4*0x04B)),
            bitSize     = 1,
            bitOffset   = 5,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "DEC_MOD_EN",
            description = "Decimation modulator enable",
            offset      = (mainDigital + (4*0x04D)),
            bitSize     = 1,
            bitOffset   = 3,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CTRL_NYQUIST",
            description = "Control Nyquist zone imaging correction",
            offset      = (mainDigital + (4*0x04E)),
            bitSize     = 1,
            bitOffset   = 7,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "BUS_REORDER_EN1",
            description = "Bus reorder enable for JESD lane 1",
            offset      = (mainDigital + (4*0x052)),
            bitSize     = 1,
            bitOffset   = 7,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "DIG_GAIN_EN",
            description = "Digital gain enable",
            offset      = (mainDigital + (4*0x052)),
            bitSize     = 1,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "BUS_REORDER_EN2",
            description = "Bus reorder enable for JESD lane 2",
            offset      = (mainDigital + (4*0x072)),
            bitSize     = 1,
            bitOffset   = 3,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "LSB_SEL_EN",
            description = "LSB selection enable for output data alignment",
            offset      = (mainDigital + (4*0x0AB)),
            bitSize     = 1,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "LSB_SELECT",
            description = "LSB position selection for output data width",
            offset      = (mainDigital + (4*0x0AD)),
            bitSize     = 2,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        # self.add(pr.RemoteVariable(
            # name         = "DIG_RESET",
            # description  = "Digital reset for main digital page registers",
            # offset       = (mainDigital + (4*0x0F7)),
            # bitSize      = 1,
            # bitOffset    = 0,
            # base         = pr.UInt,
            # mode         = "RW",
        # ))

        ###################
        # JESD DIGITAL PAGE
        ###################

        self.add(pr.RemoteVariable(
            name        = "CTRL_K",
            description = "JESD K parameter (frames per multiframe) control",
            offset      = (jesdDigital + (4*0x000)),
            bitSize     = 1,
            bitOffset   = 7,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TESTMODE_EN",
            description = "JESD test mode enable",
            offset      = (jesdDigital + (4*0x000)),
            bitSize     = 1,
            bitOffset   = 4,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "FLIP_ADC_DATA",
            description = "Invert ADC output data polarity",
            offset      = (jesdDigital + (4*0x000)),
            bitSize     = 1,
            bitOffset   = 3,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "LANE_ALIGN",
            description = "JESD lane alignment enable",
            offset      = (jesdDigital + (4*0x000)),
            bitSize     = 1,
            bitOffset   = 2,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "FRAME_ALIGN",
            description = "JESD frame alignment enable",
            offset      = (jesdDigital + (4*0x000)),
            bitSize     = 1,
            bitOffset   = 1,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_LINK_DIS",
            description = "Disable JESD TX link",
            offset      = (jesdDigital + (4*0x000)),
            bitSize     = 1,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "SYNC_REG",
            description = "JESD SYNC~ signal register value",
            offset      = (jesdDigital + (4*0x001)),
            bitSize     = 1,
            bitOffset   = 7,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "SYNC_REG_EN",
            description = "Enable register-based SYNC~ control",
            offset      = (jesdDigital + (4*0x001)),
            bitSize     = 1,
            bitOffset   = 6,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "JESD_FILTER",
            description = "JESD output digital filter mode selection",
            offset      = (jesdDigital + (4*0x001)),
            bitSize     = 3,
            bitOffset   = 3,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "JESD_MODE",
            description = "JESD204B operating mode selection",
            offset      = (jesdDigital + (4*0x001)),
            bitSize     = 3,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "LINK_LAYER_TESTMODE",
            description = "JESD link layer test pattern mode",
            offset      = (jesdDigital + (4*0x002)),
            bitSize     = 3,
            bitOffset   = 5,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "LINK_LAYER_RPAT",
            description = "JESD link layer repeated pattern test enable",
            offset      = (jesdDigital + (4*0x002)),
            bitSize     = 1,
            bitOffset   = 4,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "LMFC_MASK_RESET",
            description = "Reset LMFC mask counter",
            offset      = (jesdDigital + (4*0x002)),
            bitSize     = 1,
            bitOffset   = 3,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "FORCE_LMFC_COUNT",
            description = "Force LMFC count to LMFC_COUNT_INIT value",
            offset      = (jesdDigital + (4*0x003)),
            bitSize     = 1,
            bitOffset   = 7,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "LMFC_COUNT_INIT",
            description = "Initial LMFC counter value when forced",
            offset      = (jesdDigital + (4*0x003)),
            bitSize     = 5,
            bitOffset   = 2,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RELEASE_ILANE_SEQ",
            description = "Release ILA sequence for JESD lane initialization",
            offset      = (jesdDigital + (4*0x003)),
            bitSize     = 2,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "SCRAMBLE_EN",
            description = "JESD data scrambling enable",
            offset      = (jesdDigital + (4*0x005)),
            bitSize     = 1,
            bitOffset   = 7,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "FRAMES_PER_MULTI_FRAME",
            description = "Number of frames per JESD multiframe (K parameter)",
            offset      = (jesdDigital + (4*0x006)),
            bitSize     = 5,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "SUBCLASS",
            description = "JESD204B subclass selection (0=subclass 0, 1=subclass 1)",
            offset      = (jesdDigital + (4*0x007)),
            bitSize     = 1,
            bitOffset   = 3,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "AlwaysWrite0x1_A",
            description = "Always set this bit to 1",
            offset      = (jesdDigital + (4*0x016)),
            bitSize     = 1,
            bitOffset   = 7,
            base        = pr.UInt,
            mode        = "WO",
            value       = 0x1,
            hidden      = True,
            verify      = False,
        ))

        self.add(pr.RemoteVariable(
            name        = "LANE_SHARE",
            description = "Enable lane sharing between channels",
            offset      = (jesdDigital + (4*0x016)),
            bitSize     = 1,
            bitOffset   = 4,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "DA_BUS_REORDER",
            description = "Digital bus reorder mapping for data path A",
            offset      = (jesdDigital + (4*0x031)),
            bitSize     = 8,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "DB_BUS_REORDER",
            description = "Digital bus reorder mapping for data path B",
            offset      = (jesdDigital + (4*0x032)),
            bitSize     = 8,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        ##################
        # JESD ANALOG PAGE
        ##################

        self.add(pr.RemoteVariable(
            name        = "SE_EMP_LANE_1",
            description = "Serializer output emphasis level for JESD lane 1",
            offset      = (jesdAnalog + (4*0x012)),
            bitSize     = 6,
            bitOffset   = 2,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "AlwaysWrite0x1_B",
            description = "Always set this bit to 1",
            offset      = (jesdAnalog + (4*0x012)),
            bitSize     = 1,
            bitOffset   = 1,
            base        = pr.UInt,
            mode        = "WO",
            value       = 0x1,
            hidden      = True,
            verify      = False,
        ))

        self.add(pr.RemoteVariable(
            name        = "SE_EMP_LANE_0",
            description = "Serializer output emphasis level for JESD lane 0",
            offset      = (jesdAnalog + (4*0x013)),
            bitSize     = 6,
            bitOffset   = 2,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "SE_EMP_LANE_2",
            description = "Serializer output emphasis level for JESD lane 2",
            offset      = (jesdAnalog + (4*0x014)),
            bitSize     = 6,
            bitOffset   = 2,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "SE_EMP_LANE_3",
            description = "Serializer output emphasis level for JESD lane 3",
            offset      = (jesdAnalog + (4*0x015)),
            bitSize     = 6,
            bitOffset   = 2,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "JESD_PLL_MODE",
            description = "JESD serializer PLL mode selection",
            offset      = (jesdAnalog + (4*0x016)),
            bitSize     = 2,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "PLL_RESET",
            description = "JESD serializer PLL reset",
            offset      = (jesdAnalog + (4*0x017)),
            bitSize     = 1,
            bitOffset   = 6,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "FOVR_CHA",
            description = "Fast overrange detection for channel A",
            offset      = (jesdAnalog + (4*0x01A)),
            bitSize     = 1,
            bitOffset   = 1,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "JESD_SWING",
            description = "JESD output swing amplitude level",
            offset      = (jesdAnalog + (4*0x01B)),
            bitSize     = 3,
            bitOffset   = 5,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "FOVR_CHA_EN",
            description = "Fast overrange detection enable for channel A",
            offset      = (jesdAnalog + (4*0x01B)),
            bitSize     = 1,
            bitOffset   = 3,
            base        = pr.UInt,
            mode        = "RW",
        ))
