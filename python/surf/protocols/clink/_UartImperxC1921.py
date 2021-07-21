#-----------------------------------------------------------------------------
# Title      : PyRogue CameraLink module
#-----------------------------------------------------------------------------
# Description:
# PyRogue CameraLink Imperx C1921 module
# https://www.imperx.com/cmos-cameras/c1921/
# https://www.imperx.com/download/335/spec-sheets/20491/cl_c1921_r2_2019_w.pdf
# https://www.imperx.com/wp-content/uploads/downloads/Cheetah_Pregius_CL_User_Manual_rev.1.3_f.pdf
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
import rogue.interfaces.stream
import surf.protocols.clink as clink

class UartImperxC1921Rx(clink.ClinkSerialRx):
    def __init__(self, path, **kwargs):
        super().__init__(path=path,**kwargs)

    def _acceptFrame(self,frame):
        ba = bytearray(frame.getPayload())
        frame.read(ba,0)

        for i in range(0,len(ba),4):
            # Check for ACK
            if ba[i] == 0x06:
                print ( self._path+': Got ACK Response' )
            # Check for ACK
            if ba[i] == 0x15:
                print ( self._path+': Got NACK Response' )

class UartImperxC1921Tx(rogue.interfaces.stream.Master):
    def __init__(self, path, **kwargs):
        super().__init__(**kwargs)
        self._path = path

    def sendCmd(self,addr,data):
        # Create the byte array to be filled
        ba = bytearray(4*7)

        # 1st byte: 0x57 (Write Command)
        ba[4*0] = 0x57

        # 2nd byte: <Register Address_High> MSB
        ba[4*1] = (int(addr) >> 8*1) & 0xFF

        # 3rd byte: <Register Address_Low> LSB
        ba[4*2] = (int(addr) >> 8*0) & 0xFF

        # 4th byte: <Register Data Byte 4> MSB
        ba[4*3] = (int(data) >> 8*3) & 0xFF

        # 5th byte: <Register Data Byte 3> …
        ba[4*4] = (int(data) >> 8*2) & 0xFF

        # 6th byte: <Register Data Byte 2> …
        ba[4*5] = (int(data) >> 8*1) & 0xFF

        # 7th byte: <Register Data Byte 1> LSB
        ba[4*6] = (int(data) >> 8*0) & 0xFF

        dbgstring = ''
        for i in range(7):
            dbgstring += '0x{0:0{1}X},'.format(ba[4*i],2)
        print ( self._path+': SendString: %s' % dbgstring[:-1] )

        # Send the byte array
        frame = self._reqFrame(len(ba),True)
        frame.write(ba,0)
        self._sendFrame(frame)

class UartImperxC1921(pr.Device):
    def __init__(self, serial=None, **kwargs):
        super().__init__(**kwargs)

        # Attach the serial devices
        self._rx = clink.UartImperxC1921Rx(self.path)
        pr.streamConnect(serial,self._rx)

        self._tx = clink.UartImperxC1921Tx(self.path)
        pr.streamConnect(self._tx,serial)

        def createCmd(addr):
            def _cmd(value):
                if value != '':
                    self._tx.sendCmd(addr=addr, data=value)
            return _cmd

        #############
        # Local Space
        #############
        self.add(pr.LocalVariable(
            name         = 'Soft_Reset',
            description  = 'Firmware reset command = 0xDEADBEEF',
            mode         = 'WO',
            value        = '',
            hidden       = True,
            localSet     = createCmd(addr=0x601C)
        ))

        self.add(pr.LocalVariable(
            name         = 'SW_Trigger',
            description  = 'Command instructs camera to generate one short trigger pulse.',
            mode         = 'WO',
            value        = '',
            hidden       = True,
            localSet     = createCmd(addr=0x6030)
        ))

        ##################################################
        # Gain, Offset, Exposure Control and MAOIRegisters
        ##################################################
        self.add(pr.LocalVariable(
            name         = 'Analog_Gain',
            description  = 'Gain setting with 0.1dB per step to 48 dB',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0000)
        ))

        self.add(pr.LocalVariable(
            name         = 'Digital_Gain',
            description  = 'Gain setting with 0.001x per step',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0160)
        ))

        self.add(pr.LocalVariable(
            name         = 'Digital_Offset',
            description  = 'Digital offset (-511 to +512)',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x015C)
        ))

        self.add(pr.LocalVariable(
            name         = 'A2D_Bits',
            description  = '0x0 - 8 bits, 0x1 - 10 bits, 0x2  - 12 bits',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0008)
        ))

        self.add(pr.LocalVariable(
            name         = 'AOI_Control',
            description  = '0x0 - MAOI disable, 0x1 - MAOI enable with frame rate increase, 0x2 - MAOI enable with constant frame rate',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0010)
        ))

        self.add(pr.LocalVariable(
            name         = 'Aoi_HwM_Ofs',
            description  = 'MAOI offset in horizontal direction',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0014)
        ))

        self.add(pr.LocalVariable(
            name         = 'Aoi_HwM_Wdt',
            description  = 'MAOI width in horizontal direction',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0018)
        ))

        self.add(pr.LocalVariable(
            name         = 'Aoi_VwM_Ofs',
            description  = 'MAOI offset in vertical direction',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x001C)
        ))

        self.add(pr.LocalVariable(
            name         = 'Aoi_VwM_Hgh',
            description  = 'MAOI height in vertical direction',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0020)
        ))

        self.add(pr.LocalVariable(
            name         = 'Hrz_Decim_En',
            description  = '0x0 - Horizontal Decimation disable, 0x1 - Horizontal Decimation enable',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0024)
        ))

        self.add(pr.LocalVariable(
            name         = 'Ver_Decim_En',
            description  = '0x0 - Vertical Decimation disable, 0x1 - Vertical Decimation enable',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0028)
        ))

        self.add(pr.LocalVariable(
            name         = 'Ver_Bin_En',
            description  = '0x0 - No Vertical Binning, 0x1 - 2x Vertical Binning',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x002C)
        ))

        self.add(pr.LocalVariable(
            name         = 'Img_Hrev_en',
            description  = '0x0 - Horizontal Flip Disable, 0x1 - Horizontal Flip enable',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0030)
        ))

        self.add(pr.LocalVariable(
            name         = 'Img_Vrev_en',
            description  = '0x0 - Vertical Flip Disable, 0x1 - Vertical Flip enable',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0034)
        ))

        self.add(pr.LocalVariable(
            name         = 'BLK_Adj_en',
            description  = '0x0 - enable user black level correction, 0x1 - Auto black level correction',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0038)
        ))

        self.add(pr.LocalVariable(
            name         = 'BLK_Adj_Value',
            description  = 'Black level value',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x003C)
        ))

        self.add(pr.LocalVariable(
            name         = 'Exp_Ctl_Mod',
            description  = '0x0 - off - no exposure control, 0x1 - pulse width - for triggering, 0x2 - internal - exposure control, 0x3 - N/A',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0040)
        ))

        self.add(pr.LocalVariable(
            name         = 'Exp_Tim_Abs',
            description  = 'actual exposure time in micro-seconds',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0044)
        ))

        self.add(pr.LocalVariable(
            name         = 'Prg_Frmt_En',
            description  = '0x0 - disable Long Integration time, 0x1 - enable Long Integration time',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0048)
        ))

        self.add(pr.LocalVariable(
            name         = 'Prg_Frm_Tim',
            description  = 'actual frame time in micro-seconds',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x004C)
        ))

        self.add(pr.LocalVariable(
            name         = 'Aec_Exp_Min',
            description  = 'minimum exposure time limit',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0058)
        ))

        self.add(pr.LocalVariable(
            name         = 'Aec_Exp_Max',
            description  = 'maximum exposure time limit',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x005C)
        ))

        ##############################################
        # Data output, Data Correction, SAOI Registers
        ##############################################

        self.add(pr.LocalVariable(
            name         = 'Bit_Dpt_Sel',
            description  = '0x0 - 8-bit, 0x1 - 10-bit, 0x2 - 12-bit, 0x3 - reserved',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0100)
        ))

        self.add(pr.LocalVariable(
            name         = 'Dat_Fmt_Sel',
            description  = '0x0 - Base (2 taps), 0x1 - Base (3 taps), 0x2 - Medium, 0x3 - Full, 0x4 -- DECA, 0x5 to 0x7 - reserved',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0104)
        ))

        self.add(pr.LocalVariable(
            name         = 'Test_Mod_Sel',
            description  = '0x0 - no test pattern, 0x1 to 0x9 - test patterns, 0xA to 0xF - reserved',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0108)
        ))

        self.add(pr.LocalVariable(
            name         = 'Test_Img_Brt',
            description  = 'image brightness',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x010C)
        ))

        self.add(pr.LocalVariable(
            name         = 'Hor_Bin_En',
            description  = '0x0 - No horizontal binning, 0x1 - 2x horizontal binning',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0110)
        ))

        self.add(pr.LocalVariable(
            name         = 'LUT_En',
            description  = '0x0 - No LUT selected, 0x1 to 0x4 - LUT[1:4], 0x5 to 0x7 - unused',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0114)
        ))

        self.add(pr.LocalVariable(
            name         = 'BPC_En',
            description  = '0x0 - BPC disable, 0x1 to 0x5 - BPC modes',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x011C)
        ))

        self.add(pr.LocalVariable(
            name         = 'Dyn_BPC_Thld',
            description  = 'Threshold value',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0120)
        ))

        self.add(pr.LocalVariable(
            name         = 'FFC_En',
            description  = '0x0 - FFC disable, 0x1 - FFC 1 enable, 0x2 - FFC 2 enable',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0124)
        ))

        self.add(pr.LocalVariable(
            name         = 'Neg_Img_En',
            description  = '0x0 - Positive image, 0x1 - Negative image',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0128)
        ))

        self.add(pr.LocalVariable(
            name         = 'Aoi_Slv1_En',
            description  = '0x0 - SAOI disable, 0x1 to 0x8 - SAOI modes',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x012C)
        ))

        self.add(pr.LocalVariable(
            name         = 'Aoi_HwS_Ofs',
            description  = 'SAOI offset in horizontal direction',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0130)
        ))

        self.add(pr.LocalVariable(
            name         = 'Aoi_HwS_Wdt',
            description  = 'SAOI width in horizontal direction',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0134)
        ))

        self.add(pr.LocalVariable(
            name         = 'Aoi_VwS_Ofs',
            description  = 'SAOI offset in vertical direction',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0138)
        ))

        self.add(pr.LocalVariable(
            name         = 'Aoi_VwS_Hgh',
            description  = 'SAOI height in vertical direction',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x013C)
        ))

        self.add(pr.LocalVariable(
            name         = 'Aec_Ctl_En',
            description  = '0x0 - disable auto exposure control, 0x1 - enable auto exposure control',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0140)
        ))

        self.add(pr.LocalVariable(
            name         = 'Agc_Ctl_En',
            description  = '0x0 - disable auto gain control, 0x1 - enable auto gain control',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0144)
        ))

        self.add(pr.LocalVariable(
            name         = 'Agc_Lum_Lev',
            description  = 'desired luminance level',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0148)
        ))

        self.add(pr.LocalVariable(
            name         = 'Avg_Peak_Sel',
            description  = '0x0 - average luminance, 0x1 - peak luminance, 0x2 or 0x3 - reserved',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x014C)
        ))

        self.add(pr.LocalVariable(
            name         = 'Agc_Agn_Min',
            description  = 'minimum AGC gain limit',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0150)
        ))

        self.add(pr.LocalVariable(
            name         = 'Agc_Agn_Max',
            description  = 'Maximum AGC gain limit',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0154)
        ))

        self.add(pr.LocalVariable(
            name         = 'Dat_Shft_Sel',
            description  = 'Selects bit shift steps for camera data output',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0158)
        ))

        self.add(pr.LocalVariable(
            name         = 'Agc_Aec_Spd_Ctl',
            description  = 'Sets the exposure correction speed during AGC.AEC',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0164)
        ))

        #########################
        # White Balance Registers
        #########################

        self.add(pr.LocalVariable(
            name         = 'WB_en',
            description  = 'Selects the white balance mode',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0200)
        ))

        self.add(pr.LocalVariable(
            name         = 'WB_Red',
            description  = 'Contains white balance correction coefficients for Red. In manual mode, user enters the coefficients',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0204)
        ))

        self.add(pr.LocalVariable(
            name         = 'WB_Green',
            description  = 'Contains white balance correction coefficients for Green. In manual mode, user enters the coefficients',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0208)
        ))

        self.add(pr.LocalVariable(
            name         = 'WB_Blue',
            description  = 'Contains white balance correction coefficients for Blue. In manual mode, user enters the coefficients',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x020C)
        ))

        ##############################################################
        # Trigger, I/O Interface, Strobe and Pulse Generator Registers
        ##############################################################

        self.add(pr.LocalVariable(
            name         = 'Trg_Mode_En',
            description  = '0x0 - trigger is disabled, free running mode, 0x1 - trigger is enabled; camera in trigger mode',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0500)
        ))

        self.add(pr.LocalVariable(
            name         = 'Trg_Inp_Sel',
            description  = 'Selects Trigger input',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0504)
        ))

        self.add(pr.LocalVariable(
            name         = 'Trg_Edg_Sel',
            description  = '0x0 - rising edge, 0x1 - falling edge',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0508)
        ))

        self.add(pr.LocalVariable(
            name         = 'Trg_Dbn_Tim',
            description  = 'Selects trigger signal de-bounce time in micro-seconds',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x050C)
        ))

        self.add(pr.LocalVariable(
            name         = 'Trg_Flt_Tim',
            description  = 'Selects Filter time in micro-seconds. Any pulse shorter than the selected time is ignored',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0510)
        ))

        self.add(pr.LocalVariable(
            name         = 'Trg_Ovr_Sel',
            description  = 'Selects trigger overlap mode. If camera receives a trigger pulse while still processing previous trigger, user has option to ignore the incoming trigger or to terminate previous process and start a new one',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0514)
        ))

        self.add(pr.LocalVariable(
            name         = 'Trg_Mod_Sel',
            description  = '0x0 - standard triggering, 0x1 - fast triggering, 0x2 to 0xF - reserved',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0518)
        ))

        self.add(pr.LocalVariable(
            name         = 'Trg_Frm_Cap',
            description  = 'Selects number of frames captured after each trigger signal',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x051C)
        ))

        self.add(pr.LocalVariable(
            name         = 'Trg_Exp_Del',
            description  = 'Selects delay in microseconds between trigger signal and beginning of exposure',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0520)
        ))

        self.add(pr.LocalVariable(
            name         = 'Trg_Str_En',
            description  = '0x0 - disable Trigger Strobe, 0x1 - enable Trigger Strobe #1, 0x2 - enable Trigger Strobe #1, 0x3 - enable both Trigger Strobe #1 and #2',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0524)
        ))

        self.add(pr.LocalVariable(
            name         = 'Trg_Str_Del',
            description  = 'Strobe delay in microseconds',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0528)
        ))

        self.add(pr.LocalVariable(
            name         = 'Str_One_En',
            description  = 'Sets Strobe 1 mode of operation',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x052C)
        ))

        self.add(pr.LocalVariable(
            name         = 'Str_One_Dur',
            description  = 'Strobe #1 Pulse width in microseconds',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0530)
        ))

        self.add(pr.LocalVariable(
            name         = 'Str_One_Pos',
            description  = 'Strobe #1 Pulse position in microseconds up to one frame time',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0534)
        ))

        self.add(pr.LocalVariable(
            name         = 'Str_Two_En',
            description  = 'Sets Strobe #2 mode of operation',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0538)
        ))

        self.add(pr.LocalVariable(
            name         = 'Str_Two_Dur',
            description  = 'Strobe #2 Pulse width in microseconds',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x053C)
        ))

        self.add(pr.LocalVariable(
            name         = 'Str_Two_Pos',
            description  = 'Strobe #2 Pulse position in microseconds up to one frame time',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0540)
        ))

        self.add(pr.LocalVariable(
            name         = 'Pls_Gen_Stp',
            description  = 'Sets pulse generator main timing resolution',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0544)
        ))

        self.add(pr.LocalVariable(
            name         = 'Pls_Gen_Wdt',
            description  = 'Sets the value of the pulse width in microseconds',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0548)
        ))

        self.add(pr.LocalVariable(
            name         = 'Pls_Gen_Per',
            description  = 'Sets the value of the pulse period in microseconds',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x054C)
        ))

        self.add(pr.LocalVariable(
            name         = 'Pls_Gen_Nmb',
            description  = 'Sets the number of the pulses generated. If Bit 16 is set, continuous mode selected',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0550)
        ))

        self.add(pr.LocalVariable(
            name         = 'Pls_Gen_En',
            description  = '0x0 - disable Pulse Gen, 0x1 - enable Pulse Gen',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0554)
        ))

        self.add(pr.LocalVariable(
            name         = 'OUT1_Pol_sel',
            description  = '0x0 - active LOW, 0x1 - active HIGH',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0558)
        ))

        self.add(pr.LocalVariable(
            name         = 'OUT1_Map_Sel',
            description  = 'Maps the various internal signals to OUTPUT # 1 (OUT 1).',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x055C)
        ))

        self.add(pr.LocalVariable(
            name         = 'OUT2_Pol_sel',
            description  = '0x0 - active LOW, 0x1 - active HIGH',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0560)
        ))

        self.add(pr.LocalVariable(
            name         = 'OUT2_Map_Sel',
            description  = 'Maps the various internal signals to OUTPUT # 2 (OUT 2).',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0564)
        ))

    def _rootAttached(self,parent,root):
        super()._rootAttached(parent,root)
        self._rx._path = self.path
        self._tx._path = self.path
