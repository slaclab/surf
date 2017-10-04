#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue Gtpe2Channel
#-----------------------------------------------------------------------------
# File       : Gtpe2Channel.py
# Created    : 2017-04-12
#-----------------------------------------------------------------------------
# Description:
# PyRogue Gtpe2Channel
#-----------------------------------------------------------------------------
# This file is part of the rogue software platform. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the rogue software platform, including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue as pr

class Gtpe2Channel(pr.Device):
    def __init__(   self,       
            name        = "Gtpe2Channel",
            description = "Gtpe2Channel",
            **kwargs):
        super().__init__(name=name, description=description, **kwargs) 

        ##############################
        # Variables
        ##############################

        self.add(pr.RemoteVariable(   
            name         = "ACJTAG_RESET",
            description  = "",
            offset       =  (0x0000<<2),
            bitSize      =  1,
            bitOffset    =  15,
            base         = pr.UInt,
            mode         = "RW",
        ))
        
        self.add(pr.RemoteVariable(   
            name         = "ACJTAG_DEBUG_MODE",
            description  = "",
            offset       =  (0x0000<<2),
            bitSize      =  1,
            bitOffset    =  14,
            base         = pr.UInt,
            mode         = "RW",
        )) 

        self.add(pr.RemoteVariable(   
            name         = "ACJTAG_MODE",
            description  = "",
            offset       =  (0x0000<<2),
            bitSize      =  1,
            bitOffset    =  13,
            base         = pr.UInt,
            mode         = "RW",
        ))  

        self.add(pr.RemoteVariable(   
            name         = "UCODEER_CLR",
            description  = "",
            offset       =  (0x0000<<2),
            bitSize      =  1,
            bitOffset    =  1,
            base         = pr.UInt,
            mode         = "RW",
        )) 

        self.add(pr.RemoteVariable(   
            name         = "RXBUFRESET_TIME",
            description  = "",
            offset       =  (0x000C<<2),
            bitSize      =  5,
            bitOffset    =  11,
            base         = pr.UInt,
            mode         = "RW",
        )) 
        
        self.add(pr.RemoteVariable(   
            name         = "RXCDRPHRESET_TIME",
            description  = "",
            offset       =  (0x000D<<2),
            bitSize      =  5,
            bitOffset    =  10,
            base         = pr.UInt,
            mode         = "RW",
        ))     

        self.add(pr.RemoteVariable(   
            name         = "RXCDRFREQRESET_TIME",
            description  = "",
            offset       =  (0x000D<<2),
            bitSize      =  5,
            bitOffset    =  5,
            base         = pr.UInt,
            mode         = "RW",
        ))  

        self.add(pr.RemoteVariable(   
            name         = "RXPMARESET_TIME",
            description  = "",
            offset       =  (0x000D<<2),
            bitSize      =  5,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))   

        self.add(pr.RemoteVariable(   
            name         = "RXPCSRESET_TIME",
            description  = "",
            offset       =  (0x000E<<2),
            bitSize      =  5,
            bitOffset    =  7,
            base         = pr.UInt,
            mode         = "RW",
        ))  

        self.add(pr.RemoteVariable(   
            name         = "RXLPMRESET_TIME",
            description  = "",
            offset       =  (0x000E<<2),
            bitSize      =  7,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))  

        self.add(pr.RemoteVariable(   
            name         = "RXISCANRESET_TIME",
            description  = "",
            offset       =  (0x000F<<2),
            bitSize      =  5,
            bitOffset    =  7,
            base         = pr.UInt,
            mode         = "RW",
        ))    

        self.add(pr.RemoteVariable(   
            name         = "RXSYNC_OVRD",
            description  = "",
            offset       =  (0x0010<<2),
            bitSize      =  1,
            bitOffset    =  15,
            base         = pr.UInt,
            mode         = "RW",
        ))      

        self.add(pr.RemoteVariable(   
            name         = "TXSYNC_OVRD",
            description  = "",
            offset       =  (0x0010<<2),
            bitSize      =  1,
            bitOffset    =  14,
            base         = pr.UInt,
            mode         = "RW",
        ))     

        self.add(pr.RemoteVariable(   
            name         = "RXSYNC_SKIP_DA",
            description  = "",
            offset       =  (0x0010<<2),
            bitSize      =  1,
            bitOffset    =  13,
            base         = pr.UInt,
            mode         = "RW",
        )) 

        self.add(pr.RemoteVariable(   
            name         = "TXSYNC_SKIP_DA",
            description  = "",
            offset       =  (0x0010<<2),
            bitSize      =  1,
            bitOffset    =  12,
            base         = pr.UInt,
            mode         = "RW",
        )) 

        self.add(pr.RemoteVariable(   
            name         = "TXSYNC_MULTILANE",
            description  = "",
            offset       =  (0x0010<<2),
            bitSize      =  1,
            bitOffset    =  11,
            base         = pr.UInt,
            mode         = "RW",
        ))       

        self.add(pr.RemoteVariable(   
            name         = "RXSYNC_MULTILANE",
            description  = "",
            offset       =  (0x0010<<2),
            bitSize      =  1,
            bitOffset    =  10,
            base         = pr.UInt,
            mode         = "RW",
        ))        

        self.add(pr.RemoteVariable(   
            name         = "TXPCSRESET_TIME",
            description  = "",
            offset       =  (0x0010<<2),
            bitSize      =  5,
            bitOffset    =  5,
            base         = pr.UInt,
            mode         = "RW",
        ))          

        self.add(pr.RemoteVariable(   
            name         = "TXPMARESET_TIME",
            description  = "",
            offset       =  (0x0010<<2),
            bitSize      =  5,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        )) 

        self.add(pr.RemoteVariable(   
            name         = "RX_XCLK_SEL",
            description  = "",
            offset       =  (0x0011<<2),
            bitSize      =  1,
            bitOffset    =  14,
            base         = pr.UInt,
            mode         = "RW",
        ))   

        self.add(pr.RemoteVariable(   
            name         = "RX_DATA_WIDTH",
            description  = "",
            offset       =  (0x0011<<2),
            bitSize      =  3,
            bitOffset    =  11,
            base         = pr.UInt,
            mode         = "RW",
        ))       

        self.add(pr.RemoteVariable(   
            name         = "RX_CLK25_DIV",
            description  = "",
            offset       =  (0x0011<<2),
            bitSize      =  5,
            bitOffset    =  6,
            base         = pr.UInt,
            mode         = "RW",
        ))    

        self.add(pr.RemoteVariable(   
            name         = "RX_CM_SEL",
            description  = "",
            offset       =  (0x0011<<2),
            bitSize      =  2,
            bitOffset    =  4,
            base         = pr.UInt,
            mode         = "RW",
        ))                 

        self.add(pr.RemoteVariable(   
            name         = "RXPRBS_ERR_LOOPBACK",
            description  = "",
            offset       =  (0x0011<<2),
            bitSize      =  1,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))     

        self.add(pr.RemoteVariable(   
            name         = "SATA_BURST_SEQ_LEN",
            description  = "",
            offset       =  (0x0012<<2),
            bitSize      =  4,
            bitOffset    =  12,
            base         = pr.UInt,
            mode         = "RW",
        )) 

        self.add(pr.RemoteVariable(   
            name         = "OUTREFCLK_SEL_INV",
            description  = "",
            offset       =  (0x0012<<2),
            bitSize      =  2,
            bitOffset    =  10,
            base         = pr.UInt,
            mode         = "RW",
        ))   

        self.add(pr.RemoteVariable(   
            name         = "SATA_BURST_VAL",
            description  = "",
            offset       =  (0x0012<<2),
            bitSize      =  3,
            bitOffset    =  7,
            base         = pr.UInt,
            mode         = "RW",
        ))    

        self.add(pr.RemoteVariable(   
            name         = "RXOOB_CFG",
            description  = "",
            offset       =  (0x0012<<2),
            bitSize      =  7,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        )) 

        self.add(pr.RemoteVariable(   
            name         = "SAS_MIN_COM",
            description  = "",
            offset       =  (0x0013<<2),
            bitSize      =  6,
            bitOffset    =  9,
            base         = pr.UInt,
            mode         = "RW",
        ))  

        self.add(pr.RemoteVariable(   
            name         = "SATA_MIN_BURST",
            description  = "",
            offset       =  (0x0013<<2),
            bitSize      =  6,
            bitOffset    =  3,
            base         = pr.UInt,
            mode         = "RW",
        )) 

        self.add(pr.RemoteVariable(   
            name         = "SATA_EIDLE_VAL",
            description  = "",
            offset       =  (0x0013<<2),
            bitSize      =  3,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))   

        self.add(pr.RemoteVariable(   
            name         = "SATA_MIN_WAKE",
            description  = "",
            offset       =  (0x0014<<2),
            bitSize      =  6,
            bitOffset    =  6,
            base         = pr.UInt,
            mode         = "RW",
        ))   

        self.add(pr.RemoteVariable(   
            name         = "SATA_MIN_INIT",
            description  = "",
            offset       =  (0x0014<<2),
            bitSize      =  6,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))   

        self.add(pr.RemoteVariable(   
            name         = "SAS_MAX_COM",
            description  = "",
            offset       =  (0x0015<<2),
            bitSize      =  7,
            bitOffset    =  6,
            base         = pr.UInt,
            mode         = "RW",
        ))           

        self.add(pr.RemoteVariable(   
            name         = "SATA_MAX_BURST",
            description  = "",
            offset       =  (0x0015<<2),
            bitSize      =  6,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))         
        
        self.add(pr.RemoteVariable(   
            name         = "SATA_MAX_WAKE",
            description  = "",
            offset       =  (0x0016<<2),
            bitSize      =  6,
            bitOffset    =  6,
            base         = pr.UInt,
            mode         = "RW",
        ))      

        self.add(pr.RemoteVariable(   
            name         = "SATA_MAX_INIT",
            description  = "",
            offset       =  (0x0016<<2),
            bitSize      =  6,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))       

        self.add(pr.RemoteVariable(   
            name         = "RXOSCALRESET_TIMEOUT",
            description  = "",
            offset       =  (0x0017<<2),
            bitSize      =  5,
            bitOffset    =  11,
            base         = pr.UInt,
            mode         = "RW",
        ))    

        self.add(pr.RemoteVariable(   
            name         = "RXOSCALRESET_TIME",
            description  = "",
            offset       =  (0x0017<<2),
            bitSize      =  5,
            bitOffset    =  6,
            base         = pr.UInt,
            mode         = "RW",
        ))  

        self.add(pr.RemoteVariable(   
            name         = "TRANS_TIME_RATE",
            description  = "",
            offset       =  (0x0018<<2),
            bitSize      =  8,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))          

        self.add(pr.RemoteVariable(   
            name         = "PMA_LOOPBACK_CFG",
            description  = "",
            offset       =  (0x0019<<2),
            bitSize      =  1,
            bitOffset    =  15,
            base         = pr.UInt,
            mode         = "RW",
        ))      

        self.add(pr.RemoteVariable(   
            name         = "TX_PREDRIVER_MODE",
            description  = "",
            offset       =  (0x0019<<2),
            bitSize      =  1,
            bitOffset    =  12,
            base         = pr.UInt,
            mode         = "RW",
        )) 

        self.add(pr.RemoteVariable(   
            name         = "TX_EIDLE_DEASSERT_DELAY",
            description  = "",
            offset       =  (0x0019<<2),
            bitSize      =  3,
            bitOffset    =  9,
            base         = pr.UInt,
            mode         = "RW",
        ))         
        
        self.add(pr.RemoteVariable(   
            name         = "TX_EIDLE_ASSERT_DELAY",
            description  = "",
            offset       =  (0x0019<<2),
            bitSize      =  3,
            bitOffset    =  6,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(   
            name         = "TX_LOOPBACK_DRIVE_HIZ",
            description  = "",
            offset       =  (0x0019<<2),
            bitSize      =  1,
            bitOffset    =  5,
            base         = pr.UInt,
            mode         = "RW",
        ))   

        self.add(pr.RemoteVariable(   
            name         = "TX_DRIVE_MODE",
            description  = "",
            offset       =  (0x0019<<2),
            bitSize      =  5,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        )) 

        self.add(pr.RemoteVariable(   
            name         = "PD_TRANS_TIME_TO_P2",
            description  = "",
            offset       =  (0x001A<<2),
            bitSize      =  8,
            bitOffset    =  8,
            base         = pr.UInt,
            mode         = "RW",
        )) 

        self.add(pr.RemoteVariable(   
            name         = "PD_TRANS_TIME_NONE_P2",
            description  = "",
            offset       =  (0x001A<<2),
            bitSize      =  8,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))  

        self.add(pr.RemoteVariable(   
            name         = "PD_TRANS_TIME_FROM_P2",
            description  = "",
            offset       =  (0x001B<<2),
            bitSize      =  12,
            bitOffset    =  1,
            base         = pr.UInt,
            mode         = "RW",
        ))     

        self.add(pr.RemoteVariable(   
            name         = "PCS_PCIE_EN",
            description  = "",
            offset       =  (0x001B<<2),
            bitSize      =  1,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))  

        self.add(pr.RemoteVariable(  
            name         = "TXBUF_RESET_ON_RATE_CHANGE",
            description  = "",
            offset       =  (0x001C<<2),
            bitSize      =  1,
            bitOffset    =  15,
            base         = pr.UInt,
            mode         = "RW",
        ))      

        self.add(pr.RemoteVariable(   
            name         = "TXBUF_EN",
            description  = "",
            offset       =  (0x001C<<2),
            bitSize      =  1,
            bitOffset    =  14,
            base         = pr.UInt,
            mode         = "RW",
        ))   

        self.add(pr.RemoteVariable(   
            name         = "TXGEARBOX_EN",
            description  = "",
            offset       =  (0x001C<<2),
            bitSize      =  1,
            bitOffset    =  5,
            base         = pr.UInt,
            mode         = "RW",
        )) 

        self.add(pr.RemoteVariable(   
            name         = "GEARBOX_MODE",
            description  = "",
            offset       =  (0x001C<<2),
            bitSize      =  3,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))     

        self.add(pr.RemoteVariable(   
            name         = "RXLPM_HOLD_DURING_EIDLE",
            description  = "",
            offset       =  (0x001E<<2),
            bitSize      =  1,
            bitOffset    =  14,
            base         = pr.UInt,
            mode         = "RW",
        ))     

        self.add(pr.RemoteVariable(   
            name         = "RX_OS_CFG",
            description  = "",
            offset       =  (0x0024<<2),
            bitSize      =  13,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))   

        self.add(pr.RemoteVariable(   
            name         = "RXLPM_LF_CFG_WRD1",
            description  = "",
            offset       =  (0x002A<<2),
            bitSize      =  2,
            bitOffset    =  14,
            base         = pr.UInt,
            mode         = "RW",
        )) 

        self.add(pr.RemoteVariable(   
            name         = "RXLPM_HF_CFG",
            description  = "",
            offset       =  (0x002A<<2),
            bitSize      =  14,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        )) 

        self.add(pr.RemoteVariable(   
            name         = "RXLPM_LF_CFG_WRD0",
            description  = "",
            offset       =  (0x002B<<2),
            bitSize      =  16,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))  

        self.add(pr.RemoteVariable(   
            name         = "ES_QUALIFIER_WRD0",
            description  = "",
            offset       =  (0x002C<<2),
            bitSize      =  16,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        )) 

        self.add(pr.RemoteVariable(   
            name         = "ES_QUALIFIER_WRD1",
            description  = "",
            offset       =  (0x002D<<2),
            bitSize      =  16,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))        

        self.add(pr.RemoteVariable(   
            name         = "ES_QUALIFIER_WRD2",
            description  = "",
            offset       =  (0x002E<<2),
            bitSize      =  16,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))      

        self.add(pr.RemoteVariable(   
            name         = "ES_QUALIFIER_WRD3",
            description  = "",
            offset       =  (0x002F<<2),
            bitSize      =  16,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))              

        self.add(pr.RemoteVariable(   
            name         = "ES_QUALIFIER_WRD4",
            description  = "",
            offset       =  (0x0030<<2),
            bitSize      =  16,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))              

        self.add(pr.RemoteVariable(   
            name         = "ES_SDATA_MASK_WRD0",
            description  = "",
            offset       =  (0x0036<<2),
            bitSize      =  16,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        )) 

        self.add(pr.RemoteVariable(   
            name         = "ES_SDATA_MASK_WRD1",
            description  = "",
            offset       =  (0x0037<<2),
            bitSize      =  16,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))        

        self.add(pr.RemoteVariable(   
            name         = "ES_SDATA_MASK_WRD2",
            description  = "",
            offset       =  (0x0038<<2),
            bitSize      =  16,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))      

        self.add(pr.RemoteVariable(   
            name         = "ES_SDATA_MASK_WRD3",
            description  = "",
            offset       =  (0x0039<<2),
            bitSize      =  16,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))              

        self.add(pr.RemoteVariable(   
            name         = "ES_SDATA_MASK_WRD4",
            description  = "",
            offset       =  (0x003A<<2),
            bitSize      =  16,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        )) 
        
        self.add(pr.RemoteVariable(   
            name         = "ES_PRESCALE",
            description  = "",
            offset       =  (0x003B<<2),
            bitSize      =  5,
            bitOffset    =  11,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(   
            name         = "ES_VERT_OFFSET",
            description  = "",
            offset       =  (0x003B<<2),
            bitSize      =  9,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))    

        self.add(pr.RemoteVariable(   
            name         = "ES_HORZ_OFFSET",
            description  = "",
            offset       =  (0x003C<<2),
            bitSize      =  12,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))  

        self.add(pr.RemoteVariable(   
            name         = "RX_DISPERR_SEQ_MATCH",
            description  = "",
            offset       =  (0x003D<<2),
            bitSize      =  1,
            bitOffset    =  15,
            base         = pr.UInt,
            mode         = "RW",
        ))   

        self.add(pr.RemoteVariable(   
            name         = "DEC_PCOMMA_DETECT",
            description  = "",
            offset       =  (0x003D<<2),
            bitSize      =  1,
            bitOffset    =  14,
            base         = pr.UInt,
            mode         = "RW",
        ))      

        self.add(pr.RemoteVariable(   
            name         = "DEC_MCOMMA_DETECT",
            description  = "",
            offset       =  (0x003D<<2),
            bitSize      =  1,
            bitOffset    =  13,
            base         = pr.UInt,
            mode         = "RW",
        ))  

        self.add(pr.RemoteVariable(   
            name         = "DEC_VALID_COMMA_ONLY",
            description  = "",
            offset       =  (0x003D<<2),
            bitSize      =  1,
            bitOffset    =  12,
            base         = pr.UInt,
            mode         = "RW",
        ))   

        self.add(pr.RemoteVariable(   
            name         = "ES_ERRDET_EN",
            description  = "",
            offset       =  (0x003D<<2),
            bitSize      =  1,
            bitOffset    =  9,
            base         = pr.UInt,
            mode         = "RW",
        )) 

        self.add(pr.RemoteVariable(   
            name         = "ES_EYE_SCAN_EN",
            description  = "",
            offset       =  (0x003D<<2),
            bitSize      =  1,
            bitOffset    =  8,
            base         = pr.UInt,
            mode         = "RW",
        ))        

        self.add(pr.RemoteVariable(   
            name         = "ES_CONTROL",
            description  = "",
            offset       =  (0x003D<<2),
            bitSize      =  6,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))     

        self.add(pr.RemoteVariable(   
            name         = "ALIGN_COMMA_ENABLE",
            description  = "",
            offset       =  (0x003E<<2),
            bitSize      =  9,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))    

        self.add(pr.RemoteVariable(   
            name         = "ALIGN_MCOMMA_VALUE",
            description  = "",
            offset       =  (0x003F<<2),
            bitSize      =  9,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))   

        self.add(pr.RemoteVariable(   
            name         = "RXSLIDE_MODE",
            description  = "",
            offset       =  (0x0040<<2),
            bitSize      =  2,
            bitOffset    =  14,
            base         = pr.UInt,
            mode         = "RW",
        ))   

        self.add(pr.RemoteVariable(   
            name         = "ALIGN_PCOMMA_VALUE",
            description  = "",
            offset       =  (0x0040<<2),
            bitSize      =  10,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))         

        self.add(pr.RemoteVariable(   
            name         = "ALIGN_COMMA_WORD",
            description  = "",
            offset       =  (0x0041<<2),
            bitSize      =  2,
            bitOffset    =  13,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(   
            name         = "RX_SIG_VALID_DLY",
            description  = "",
            offset       =  (0x0041<<2),
            bitSize      =  5,
            bitOffset    =  8,
            base         = pr.UInt,
            mode         = "RW",
        ))     

        self.add(pr.RemoteVariable(   
            name         = "ALIGN_PCOMMA_DET",
            description  = "",
            offset       =  (0x0041<<2),
            bitSize      =  1,
            bitOffset    =  7,
            base         = pr.UInt,
            mode         = "RW",
        ))  

        self.add(pr.RemoteVariable(   
            name         = "ALIGN_MCOMMA_DET",
            description  = "",
            offset       =  (0x0041<<2),
            bitSize      =  1,
            bitOffset    =  6,
            base         = pr.UInt,
            mode         = "RW",
        )) 

        self.add(pr.RemoteVariable(   
            name         = "SHOW_REALIGN_COMMA",
            description  = "",
            offset       =  (0x0041<<2),
            bitSize      =  1,
            bitOffset    =  5,
            base         = pr.UInt,
            mode         = "RW",
        ))   

        self.add(pr.RemoteVariable(   
            name         = "ALIGN_COMMA_DOUBLE",
            description  = "",
            offset       =  (0x0041<<2),
            bitSize      =  1,
            bitOffset    =  4,
            base         = pr.UInt,
            mode         = "RW",
        ))    

        self.add(pr.RemoteVariable(   
            name         = "RXSLIDE_AUTO_WAIT",
            description  = "",
            offset       =  (0x0041<<2),
            bitSize      =  4,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))       

        self.add(pr.RemoteVariable(   
            name         = "CLK_CORRECT_USE",
            description  = "",
            offset       =  (0x0044<<2),
            bitSize      =  1,
            bitOffset    =  14,
            base         = pr.UInt,
            mode         = "RW",
        ))               

        self.add(pr.RemoteVariable(   
            name         = "CLK_COR_SEQ_1_ENABLE",
            description  = "",
            offset       =  (0x0044<<2),
            bitSize      =  4,
            bitOffset    =  10,
            base         = pr.UInt,
            mode         = "RW",
        )) 

        self.add(pr.RemoteVariable(   
            name         = "CLK_COR_SEQ_1_1",
            description  = "",
            offset       =  (0x0044<<2),
            bitSize      =  10,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))  

        self.add(pr.RemoteVariable(   
            name         = "CLK_COR_MAX_LAT",
            description  = "",
            offset       =  (0x0045<<2),
            bitSize      =  6,
            bitOffset    =  10,
            base         = pr.UInt,
            mode         = "RW",
        ))     

        self.add(pr.RemoteVariable(   
            name         = "CLK_COR_SEQ_1_2",
            description  = "",
            offset       =  (0x0045<<2),
            bitSize      =  10,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))  
        
        self.add(pr.RemoteVariable(   
            name         = "CLK_COR_MIN_LAT",
            description  = "",
            offset       =  (0x0046<<2),
            bitSize      =  6,
            bitOffset    =  10,
            base         = pr.UInt,
            mode         = "RW",
        ))     

        self.add(pr.RemoteVariable(   
            name         = "CLK_COR_SEQ_1_3",
            description  = "",
            offset       =  (0x0046<<2),
            bitSize      =  10,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))     

        self.add(pr.RemoteVariable(   
            name         = "CLK_COR_REPEAT_WAIT",
            description  = "",
            offset       =  (0x0047<<2),
            bitSize      =  5,
            bitOffset    =  10,
            base         = pr.UInt,
            mode         = "RW",
        ))             
        
        self.add(pr.RemoteVariable(   
            name         = "CLK_COR_SEQ_1_4",
            description  = "",
            offset       =  (0x0047<<2),
            bitSize      =  10,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))     

        self.add(pr.RemoteVariable(   
            name         = "CLK_COR_SEQ_2_USE",
            description  = "",
            offset       =  (0x0048<<2),
            bitSize      =  1,
            bitOffset    =  14,
            base         = pr.UInt,
            mode         = "RW",
        ))     

        self.add(pr.RemoteVariable(   
            name         = "CLK_COR_SEQ_2_ENABLE",
            description  = "",
            offset       =  (0x0048<<2),
            bitSize      =  4,
            bitOffset    =  10,
            base         = pr.UInt,
            mode         = "RW",
        ))  

        self.add(pr.RemoteVariable(   
            name         = "CLK_COR_SEQ_2_1",
            description  = "",
            offset       =  (0x0048<<2),
            bitSize      =  10,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))          

        self.add(pr.RemoteVariable(   
            name         = "CLK_COR_KEEP_IDLE",
            description  = "",
            offset       =  (0x0049<<2),
            bitSize      =  1,
            bitOffset    =  14,
            base         = pr.UInt,
            mode         = "RW",
        ))      

        self.add(pr.RemoteVariable(   
            name         = "CLK_COR_PRECEDENCE",
            description  = "",
            offset       =  (0x0049<<2),
            bitSize      =  1,
            bitOffset    =  12,
            base         = pr.UInt,
            mode         = "RW",
        ))      

        self.add(pr.RemoteVariable(   
            name         = "CLK_COR_SEQ_LEN",
            description  = "",
            offset       =  (0x0049<<2),
            bitSize      =  2,
            bitOffset    =  10,
            base         = pr.UInt,
            mode         = "RW",
        ))  

        self.add(pr.RemoteVariable(   
            name         = "CLK_COR_SEQ_2_2",
            description  = "",
            offset       =  (0x0049<<2),
            bitSize      =  10,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))      

        self.add(pr.RemoteVariable(   
            name         = "CLK_COR_SEQ_2_3",
            description  = "",
            offset       =  (0x004A<<2),
            bitSize      =  10,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        )) 

        self.add(pr.RemoteVariable(   
            name         = "RXGEARBOX_EN",
            description  = "",
            offset       =  (0x004B<<2),
            bitSize      =  1,
            bitOffset    =  15,
            base         = pr.UInt,
            mode         = "RW",
        ))         
        
        self.add(pr.RemoteVariable(   
            name         = "CLK_COR_SEQ_2_4",
            description  = "",
            offset       =  (0x004B<<2),
            bitSize      =  10,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))   

        self.add(pr.RemoteVariable(   
            name         = "CHAN_BOND_SEQ_1_ENABLE",
            description  = "",
            offset       =  (0x004C<<2),
            bitSize      =  4,
            bitOffset    =  12,
            base         = pr.UInt,
            mode         = "RW",
        ))  

        self.add(pr.RemoteVariable(   
            name         = "CHAN_BOND_SEQ_1_1",
            description  = "",
            offset       =  (0x004C<<2),
            bitSize      =  10,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))       

        self.add(pr.RemoteVariable(   
            name         = "CHAN_BOND_SEQ_LEN",
            description  = "",
            offset       =  (0x004D<<2),
            bitSize      =  2,
            bitOffset    =  14,
            base         = pr.UInt,
            mode         = "RW",
        )) 

        self.add(pr.RemoteVariable(   
            name         = "CHAN_BOND_SEQ_1_2",
            description  = "",
            offset       =  (0x004D<<2),
            bitSize      =  10,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))   

        self.add(pr.RemoteVariable(   
            name         = "CHAN_BOND_KEEP_ALIGN",
            description  = "",
            offset       =  (0x004E<<2),
            bitSize      =  1,
            bitOffset    =  15,
            base         = pr.UInt,
            mode         = "RW",
        ))  

        self.add(pr.RemoteVariable(   
            name         = "CHAN_BOND_SEQ_1_3",
            description  = "",
            offset       =  (0x004E<<2),
            bitSize      =  10,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))  

        self.add(pr.RemoteVariable(   
            name         = "CHAN_BOND_SEQ_1_4",
            description  = "",
            offset       =  (0x004F<<2),
            bitSize      =  10,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))     

        self.add(pr.RemoteVariable(   
            name         = "CHAN_BOND_SEQ_2_ENABLE",
            description  = "",
            offset       =  (0x0050<<2),
            bitSize      =  4,
            bitOffset    =  12,
            base         = pr.UInt,
            mode         = "RW",
        ))      

        self.add(pr.RemoteVariable(   
            name         = "CHAN_BOND_SEQ_2_USE",
            description  = "",
            offset       =  (0x0050<<2),
            bitSize      =  1,
            bitOffset    =  11,
            base         = pr.UInt,
            mode         = "RW",
        ))    

        self.add(pr.RemoteVariable(   
            name         = "CHAN_BOND_SEQ_2_1",
            description  = "",
            offset       =  (0x0050<<2),
            bitSize      =  10,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))         

        self.add(pr.RemoteVariable(   
            name         = "FTS_LANE_DESKEW_CFG",
            description  = "",
            offset       =  (0x0051<<2),
            bitSize      =  4,
            bitOffset    =  12,
            base         = pr.UInt,
            mode         = "RW",
        )) 

        self.add(pr.RemoteVariable(   
            name         = "FTS_LANE_DESKEW_EN",
            description  = "",
            offset       =  (0x0051<<2),
            bitSize      =  1,
            bitOffset    =  11,
            base         = pr.UInt,
            mode         = "RW",
        )) 

        self.add(pr.RemoteVariable(   
            name         = "CHAN_BOND_SEQ_2_2",
            description  = "",
            offset       =  (0x0051<<2),
            bitSize      =  10,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))         
        
        self.add(pr.RemoteVariable(   
            name         = "FTS_DESKEW_SEQ_ENABLE",
            description  = "",
            offset       =  (0x0052<<2),
            bitSize      =  4,
            bitOffset    =  12,
            base         = pr.UInt,
            mode         = "RW",
        )) 

        self.add(pr.RemoteVariable(   
            name         = "CBCC_DATA_SOURCE_SEL",
            description  = "",
            offset       =  (0x0052<<2),
            bitSize      =  1,
            bitOffset    =  11,
            base         = pr.UInt,
            mode         = "RW",
        )) 

        self.add(pr.RemoteVariable(   
            name         = "CHAN_BOND_SEQ_2_3",
            description  = "",
            offset       =  (0x0052<<2),
            bitSize      =  10,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))            
        
        self.add(pr.RemoteVariable(   
            name         = "CHAN_BOND_MAX_SKEW",
            description  = "",
            offset       =  (0x0053<<2),
            bitSize      =  4,
            bitOffset    =  12,
            base         = pr.UInt,
            mode         = "RW",
        )) 

        self.add(pr.RemoteVariable(   
            name         = "CHAN_BOND_SEQ_2_4",
            description  = "",
            offset       =  (0x0053<<2),
            bitSize      =  10,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))     

        self.add(pr.RemoteVariable(   
            name         = "RXDLY_TAP_CFG",
            description  = "",
            offset       =  (0x0054<<2),
            bitSize      =  16,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))    

        self.add(pr.RemoteVariable(   
            name         = "RXDLY_CFG",
            description  = "",
            offset       =  (0x0055<<2),
            bitSize      =  16,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))      

        self.add(pr.RemoteVariable(   
            name         = "RXPH_MONITOR_SEL",
            description  = "",
            offset       =  (0x0057<<2),
            bitSize      =  5,
            bitOffset    =  8,
            base         = pr.UInt,
            mode         = "RW",
        ))         

        self.add(pr.RemoteVariable(   
            name         = "RX_DDI_SEL",
            description  = "",
            offset       =  (0x0057<<2),
            bitSize      =  6,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))  

        self.add(pr.RemoteVariable(   
            name         = "TX_XCLK_SEL",
            description  = "",
            offset       =  (0x0059<<2),
            bitSize      =  1,
            bitOffset    =  7,
            base         = pr.UInt,
            mode         = "RW",
        )) 

        self.add(pr.RemoteVariable(   
            name         = "RXBUF_EN",
            description  = "",
            offset       =  (0x0059<<2),
            bitSize      =  1,
            bitOffset    =  6,
            base         = pr.UInt,
            mode         = "RW",
        ))    

        self.add(pr.RemoteVariable(   
            name         = "TXOOB_CFG",
            description  = "",
            offset       =  (0x005A<<2),
            bitSize      =  1,
            bitOffset    =  9,
            base         = pr.UInt,
            mode         = "RW",
        ))  

        self.add(pr.RemoteVariable(   
            name         = "LOOPBACK_CFG",
            description  = "",
            offset       =  (0x005A<<2),
            bitSize      =  1,
            bitOffset    =  8,
            base         = pr.UInt,
            mode         = "RW",
        ))        

        self.add(pr.RemoteVariable(   
            name         = "TXPI_CFG5",
            description  = "",
            offset       =  (0x005D<<2),
            bitSize      =  3,
            bitOffset    =  8,
            base         = pr.UInt,
            mode         = "RW",
        )) 

        self.add(pr.RemoteVariable(   
            name         = "TXPI_CFG4",
            description  = "",
            offset       =  (0x005D<<2),
            bitSize      =  1,
            bitOffset    =  7,
            base         = pr.UInt,
            mode         = "RW",
        ))    

        self.add(pr.RemoteVariable(   
            name         = "TXPI_CFG3",
            description  = "",
            offset       =  (0x005D<<2),
            bitSize      =  1,
            bitOffset    =  6,
            base         = pr.UInt,
            mode         = "RW",
        ))  

        self.add(pr.RemoteVariable(   
            name         = "TXPI_CFG2",
            description  = "",
            offset       =  (0x005D<<2),
            bitSize      =  2,
            bitOffset    =  4,
            base         = pr.UInt,
            mode         = "RW",
        )) 

        self.add(pr.RemoteVariable(   
            name         = "TXPI_CFG1",
            description  = "",
            offset       =  (0x005D<<2),
            bitSize      =  2,
            bitOffset    =  2,
            base         = pr.UInt,
            mode         = "RW",
        ))        

        self.add(pr.RemoteVariable(   
            name         = "TXPI_CFG0",
            description  = "",
            offset       =  (0x005D<<2),
            bitSize      =  2,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))     

        self.add(pr.RemoteVariable(   
            name         = "SATA_PLL_CFG",
            description  = "",
            offset       =  (0x005E<<2),
            bitSize      =  2,
            bitOffset    =  14,
            base         = pr.UInt,
            mode         = "RW",
        ))   

        self.add(pr.RemoteVariable(   
            name         = "TXPHDLY_CFG_WRD0",
            description  = "",
            offset       =  (0x0060<<2),
            bitSize      =  16,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))   

        self.add(pr.RemoteVariable(   
            name         = "TXPHDLY_CFG_WRD1",
            description  = "",
            offset       =  (0x0061<<2),
            bitSize      =  8,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))           
        
        self.add(pr.RemoteVariable(   
            name         = "TXDLY_CFG",
            description  = "",
            offset       =  (0x0062<<2),
            bitSize      =  16,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(   
            name         = "TXDLY_TAP_CFG",
            description  = "",
            offset       =  (0x0063<<2),
            bitSize      =  16,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))   

        self.add(pr.RemoteVariable(   
            name         = "TXPH_CFG",
            description  = "",
            offset       =  (0x0064<<2),
            bitSize      =  16,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))     

        self.add(pr.RemoteVariable(   
            name         = "TXPH_MONITOR_SEL",
            description  = "",
            offset       =  (0x0065<<2),
            bitSize      =  5,
            bitOffset    =  8,
            base         = pr.UInt,
            mode         = "RW",
        ))      

        self.add(pr.RemoteVariable(   
            name         = "RX_BIAS_CFG",
            description  = "",
            offset       =  (0x0066<<2),
            bitSize      =  16,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))     

        self.add(pr.RemoteVariable(   
            name         = "RXOOB_CLK_CFG",
            description  = "",
            offset       =  (0x0068<<2),
            bitSize      =  1,
            bitOffset    =  3,
            base         = pr.UInt,
            mode         = "RW",
        ))     

        self.add(pr.RemoteVariable(   
            name         = "TX_CLKMUX_EN",
            description  = "",
            offset       =  (0x0068<<2),
            bitSize      =  1,
            bitOffset    =  1,
            base         = pr.UInt,
            mode         = "RW",
        )) 

        self.add(pr.RemoteVariable(   
            name         = "RX_CLKMUX_EN",
            description  = "",
            offset       =  (0x0068<<2),
            bitSize      =  1,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))  

        self.add(pr.RemoteVariable(   
            name         = "TERM_RCAL_CFG",
            description  = "",
            offset       =  (0x0069<<2),
            bitSize      =  15,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))   

        # "This feature is intended for internal use only." (UG482)
        # self.add(pr.RemoteVariable(   
            # name         = "TERM_RCAL_OVRD",
            # description  = "",
            # offset       =  (0x006A<<2),
            # bitSize      =  3,
            # bitOffset    =  13,
            # base         = pr.UInt,
            # mode         = "RW",
        # ))
                
        self.add(pr.RemoteVariable(   
            name         = "TX_CLK25_DIV",
            description  = "",
            offset       =  (0x006A<<2),
            bitSize      =  5,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))   

        self.add(pr.RemoteVariable(   
            name         = "PMA_RSV5",
            description  = "",
            offset       =  (0x006B<<2),
            bitSize      =  1,
            bitOffset    =  15,
            base         = pr.UInt,
            mode         = "RW",
        ))        

        self.add(pr.RemoteVariable(   
            name         = "PMA_RSV4",
            description  = "",
            offset       =  (0x006B<<2),
            bitSize      =  4,
            bitOffset    =  8,
            base         = pr.UInt,
            mode         = "RW",
        ))      

        self.add(pr.RemoteVariable(   
            name         = "TX_DATA_WIDTH",
            description  = "",
            offset       =  (0x006B<<2),
            bitSize      =  3,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))    

        self.add(pr.RemoteVariable(   
            name         = "PCS_RSVD_ATTR_WRD0",
            description  = "",
            offset       =  (0x006F<<2),
            bitSize      =  16,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))     

        self.add(pr.RemoteVariable(   
            name         = "PCS_RSVD_ATTR_WRD1",
            description  = "",
            offset       =  (0x0070<<2),
            bitSize      =  16,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))        

        self.add(pr.RemoteVariable(   
            name         = "PCS_RSVD_ATTR_WRD2",
            description  = "",
            offset       =  (0x0071<<2),
            bitSize      =  16,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        )) 

        self.add(pr.RemoteVariable(   
            name         = "TX_MARGIN_FULL_1",
            description  = "",
            offset       =  (0x0075<<2),
            bitSize      =  7,
            bitOffset    =  8,
            base         = pr.UInt,
            mode         = "RW",
        ))  

        self.add(pr.RemoteVariable(   
            name         = "TX_MARGIN_FULL_0",
            description  = "",
            offset       =  (0x0075<<2),
            bitSize      =  7,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))          
        
        self.add(pr.RemoteVariable(   
            name         = "TX_MARGIN_FULL_3",
            description  = "",
            offset       =  (0x0076<<2),
            bitSize      =  7,
            bitOffset    =  8,
            base         = pr.UInt,
            mode         = "RW",
        ))  

        self.add(pr.RemoteVariable(   
            name         = "TX_MARGIN_FULL_2",
            description  = "",
            offset       =  (0x0076<<2),
            bitSize      =  7,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))       

        self.add(pr.RemoteVariable(   
            name         = "TX_MARGIN_LOW_0",
            description  = "",
            offset       =  (0x0077<<2),
            bitSize      =  7,
            bitOffset    =  8,
            base         = pr.UInt,
            mode         = "RW",
        ))  

        self.add(pr.RemoteVariable(   
            name         = "TX_MARGIN_FULL_4",
            description  = "",
            offset       =  (0x0077<<2),
            bitSize      =  7,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        )) 

        self.add(pr.RemoteVariable(   
            name         = "TX_MARGIN_LOW_2",
            description  = "",
            offset       =  (0x0078<<2),
            bitSize      =  7,
            bitOffset    =  8,
            base         = pr.UInt,
            mode         = "RW",
        ))  

        self.add(pr.RemoteVariable(   
            name         = "TX_MARGIN_LOW_1",
            description  = "",
            offset       =  (0x0078<<2),
            bitSize      =  7,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))         
                
        self.add(pr.RemoteVariable(   
            name         = "TX_MARGIN_LOW_4",
            description  = "",
            offset       =  (0x0079<<2),
            bitSize      =  7,
            bitOffset    =  8,
            base         = pr.UInt,
            mode         = "RW",
        ))  

        self.add(pr.RemoteVariable(   
            name         = "TX_MARGIN_LOW_3",
            description  = "",
            offset       =  (0x0079<<2),
            bitSize      =  7,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))        

        self.add(pr.RemoteVariable(   
            name         = "TX_DEEMPH1",
            description  = "",
            offset       =  (0x007A<<2),
            bitSize      =  6,
            bitOffset    =  8,
            base         = pr.UInt,
            mode         = "RW",
        ))           

        self.add(pr.RemoteVariable(   
            name         = "TX_DEEMPH0",
            description  = "",
            offset       =  (0x007A<<2),
            bitSize      =  6,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))    

        self.add(pr.RemoteVariable(   
            name         = "TX_RXDETECT_REF",
            description  = "",
            offset       =  (0x007C<<2),
            bitSize      =  3,
            bitOffset    =  8,
            base         = pr.UInt,
            mode         = "RW",
        ))    

        self.add(pr.RemoteVariable(   
            name         = "TX_MAINCURSOR_SEL",
            description  = "",
            offset       =  (0x007C<<2),
            bitSize      =  1,
            bitOffset    =  3,
            base         = pr.UInt,
            mode         = "RW",
        ))     

        self.add(pr.RemoteVariable(   
            name         = "PMA_RSV3",
            description  = "",
            offset       =  (0x007C<<2),
            bitSize      =  2,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))             
        
        self.add(pr.RemoteVariable(   
            name         = "PMA_RSV7",
            description  = "",
            offset       =  (0x007D<<2),
            bitSize      =  1,
            bitOffset    =  15,
            base         = pr.UInt,
            mode         = "RW",
        ))         

        self.add(pr.RemoteVariable(   
            name         = "PMA_RSV6",
            description  = "",
            offset       =  (0x007D<<2),
            bitSize      =  1,
            bitOffset    =  14,
            base         = pr.UInt,
            mode         = "RW",
        ))       

        self.add(pr.RemoteVariable(   
            name         = "TX_RXDETECT_CFG",
            description  = "",
            offset       =  (0x007D<<2),
            bitSize      =  14,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))  

        self.add(pr.RemoteVariable(   
            name         = "CLK_COMMON_SWING",
            description  = "",
            offset       =  (0x007E<<2),
            bitSize      =  1,
            bitOffset    =  15,
            base         = pr.UInt,
            mode         = "RW",
        )) 

        self.add(pr.RemoteVariable(   
            name         = "RX_CM_TRIM",
            description  = "",
            offset       =  (0x007E<<2),
            bitSize      =  4,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))   

        self.add(pr.RemoteVariable(   
            name         = "RXLPM_CFG1",
            description  = "",
            offset       =  (0x0081<<2),
            bitSize      =  1,
            bitOffset    =  4,
            base         = pr.UInt,
            mode         = "RW",
        ))    

        self.add(pr.RemoteVariable(   
            name         = "RXLPM_CFG",
            description  = "",
            offset       =  (0x0081<<2),
            bitSize      =  4,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))      

        self.add(pr.RemoteVariable(   
            name         = "PMA_RSV2_WRD0",
            description  = "",
            offset       =  (0x0082<<2),
            bitSize      =  16,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))      

        self.add(pr.RemoteVariable(   
            name         = "PMA_RSV2_WRD1",
            description  = "",
            offset       =  (0x0083<<2),
            bitSize      =  16,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))      

        self.add(pr.RemoteVariable(   
            name         = "DMONITOR_CFG_WRD0",
            description  = "",
            offset       =  (0x0086<<2),
            bitSize      =  16,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))      

        self.add(pr.RemoteVariable(   
            name         = "DMONITOR_CFG_WRD1",
            description  = "",
            offset       =  (0x0087<<2),
            bitSize      =  8,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))          

        self.add(pr.RemoteVariable(   
            name         = "RXLPM_BIAS_STARTUP_DISABLE",
            description  = "",
            offset       =  (0x0088<<2),
            bitSize      =  1,
            bitOffset    =  15,
            base         = pr.UInt,
            mode         = "RW",
        ))    
        
        self.add(pr.RemoteVariable(   
            name         = "RXLPM_HF_CFG3",
            description  = "",
            offset       =  (0x0088<<2),
            bitSize      =  4,
            bitOffset    =  11,
            base         = pr.UInt,
            mode         = "RW",
        ))    

        self.add(pr.RemoteVariable(   
            name         = "TXOUT_DIV",
            description  = "",
            offset       =  (0x0088<<2),
            bitSize      =  3,
            bitOffset    =  4,
            base         = pr.UInt,
            mode         = "RW",
        ))           
        
        self.add(pr.RemoteVariable(   
            name         = "RXOUT_DIV",
            description  = "",
            offset       =  (0x0088<<2),
            bitSize      =  3,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))
        
        self.add(pr.RemoteVariable(   
            name         = "CFOK_CFG_WRD0",
            description  = "",
            offset       =  (0x0089<<2),
            bitSize      =  16,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))
        
        self.add(pr.RemoteVariable(   
            name         = "CFOK_CFG_WRD1",
            description  = "",
            offset       =  (0x008A<<2),
            bitSize      =  16,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))
        
        self.add(pr.RemoteVariable(   
            name         = "CFOK_CFG_WRD2",
            description  = "",
            offset       =  (0x008B<<2),
            bitSize      =  11,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))
        
        self.add(pr.RemoteVariable(   
            name         = "CFOK_CFG3",
            description  = "",
            offset       =  (0x008C<<2),
            bitSize      =  7,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))
        
        self.add(pr.RemoteVariable(   
            name         = "RXPI_CFG0",
            description  = "",
            offset       =  (0x008D<<2),
            bitSize      =  3,
            bitOffset    =  13,
            base         = pr.UInt,
            mode         = "RW",
        ))
        
        self.add(pr.RemoteVariable(   
            name         = "RXLPM_CM_CFG",
            description  = "",
            offset       =  (0x008D<<2),
            bitSize      =  1,
            bitOffset    =  12,
            base         = pr.UInt,
            mode         = "RW",
        ))
        
        self.add(pr.RemoteVariable(   
            name         = "CFOK_CFG5",
            description  = "",
            offset       =  (0x008D<<2),
            bitSize      =  2,
            bitOffset    =  10,
            base         = pr.UInt,
            mode         = "RW",
        ))
        
        self.add(pr.RemoteVariable(   
            name         = "RXLPM_LF_CFG2",
            description  = "",
            offset       =  (0x008D<<2),
            bitSize      =  5,
            bitOffset    =  5,
            base         = pr.UInt,
            mode         = "RW",
        ))       

        self.add(pr.RemoteVariable(   
            name         = "RXLPM_HF_CFG2",
            description  = "",
            offset       =  (0x008D<<2),
            bitSize      =  5,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))      

        self.add(pr.RemoteVariable(   
            name         = "RXLPM_IPCM_CFG",
            description  = "",
            offset       =  (0x008E<<2),
            bitSize      =  1,
            bitOffset    =  15,
            base         = pr.UInt,
            mode         = "RW",
        ))  

        self.add(pr.RemoteVariable(   
            name         = "RXLPM_INCM_CFG",
            description  = "",
            offset       =  (0x008E<<2),
            bitSize      =  1,
            bitOffset    =  14,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(   
            name         = "CFOK_CFG4",
            description  = "",
            offset       =  (0x008E<<2),
            bitSize      =  1,
            bitOffset    =  13,
            base         = pr.UInt,
            mode         = "RW",
        )) 

        self.add(pr.RemoteVariable(   
            name         = "CFOK_CFG6",
            description  = "",
            offset       =  (0x008E<<2),
            bitSize      =  4,
            bitOffset    =  9,
            base         = pr.UInt,
            mode         = "RW",
        ))   

        self.add(pr.RemoteVariable(   
            name         = "RXLPM_GC_CFG",
            description  = "",
            offset       =  (0x008E<<2),
            bitSize      =  9,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        )) 

        self.add(pr.RemoteVariable(   
            name         = "RXLPM_GC_CFG2",
            description  = "",
            offset       =  (0x008F<<2),
            bitSize      =  3,
            bitOffset    =  5,
            base         = pr.UInt,
            mode         = "RW",
        )) 

        self.add(pr.RemoteVariable(   
            name         = "RXPI_CFG1",
            description  = "",
            offset       =  (0x008F<<2),
            bitSize      =  1,
            bitOffset    =  4,
            base         = pr.UInt,
            mode         = "RW",
        ))  

        self.add(pr.RemoteVariable(   
            name         = "RXPI_CFG2",
            description  = "",
            offset       =  (0x008F<<2),
            bitSize      =  1,
            bitOffset    =  3,
            base         = pr.UInt,
            mode         = "RW",
        ))   

        self.add(pr.RemoteVariable(   
            name         = "RXLPM_OSINT_CFG",
            description  = "",
            offset       =  (0x008F<<2),
            bitSize      =  3,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))     

        self.add(pr.RemoteVariable(   
            name         = "ES_CLK_PHASE_SEL",
            description  = "",
            offset       =  (0x0091<<2),
            bitSize      =  1,
            bitOffset    =  15,
            base         = pr.UInt,
            mode         = "RW",
        ))        

        self.add(pr.RemoteVariable(   
            name         = "USE_PCS_CLK_PHASE_SEL",
            description  = "",
            offset       =  (0x0091<<2),
            bitSize      =  1,
            bitOffset    =  14,
            base         = pr.UInt,
            mode         = "RW",
        ))               

        self.add(pr.RemoteVariable(   
            name         = "CFOK_CFG2",
            description  = "",
            offset       =  (0x0091<<2),
            bitSize      =  7,
            bitOffset    =  6,
            base         = pr.UInt,
            mode         = "RW",
        ))  

        self.add(pr.RemoteVariable(   
            name         = "ADAPT_CFG0_WRD0",
            description  = "",
            offset       =  (0x0092<<2),
            bitSize      =  16,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))   

        self.add(pr.RemoteVariable(   
            name         = "ADAPT_CFG0_WRD1",
            description  = "",
            offset       =  (0x0093<<2),
            bitSize      =  4,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))      

        self.add(pr.RemoteVariable(   
            name         = "TXPI_PPM_CFG",
            description  = "",
            offset       =  (0x0095<<2),
            bitSize      =  8,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        )) 

        self.add(pr.RemoteVariable(   
            name         = "TXPI_GREY_SEL",
            description  = "",
            offset       =  (0x0096<<2),
            bitSize      =  1,
            bitOffset    =  5,
            base         = pr.UInt,
            mode         = "RW",
        ))     

        self.add(pr.RemoteVariable(   
            name         = "TXPI_INVSTROBE_SEL",
            description  = "",
            offset       =  (0x0096<<2),
            bitSize      =  1,
            bitOffset    =  4,
            base         = pr.UInt,
            mode         = "RW",
        ))    

        self.add(pr.RemoteVariable(   
            name         = "TXPI_PPMCLK_SEL",
            description  = "",
            offset       =  (0x0096<<2),
            bitSize      =  1,
            bitOffset    =  3,
            base         = pr.UInt,
            mode         = "RW",
        ))      

        self.add(pr.RemoteVariable(   
            name         = "TXPI_SYNFREQ_PPM",
            description  = "",
            offset       =  (0x0096<<2),
            bitSize      =  3,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))     

        self.add(pr.RemoteVariable(   
            name         = "TST_RSV_WRD0",
            description  = "",
            offset       =  (0x0097<<2),
            bitSize      =  16,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))             
        
        self.add(pr.RemoteVariable(   
            name         = "TST_RSV_WRD1",
            description  = "",
            offset       =  (0x0098<<2),
            bitSize      =  16,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))      

        self.add(pr.RemoteVariable(   
            name         = "PMA_RSV_WRD0",
            description  = "",
            offset       =  (0x0099<<2),
            bitSize      =  16,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))             
        
        self.add(pr.RemoteVariable(   
            name         = "PMA_RSV_WRD1",
            description  = "",
            offset       =  (0x009A<<2),
            bitSize      =  16,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))         

        self.add(pr.RemoteVariable(   
            name         = "RX_BUFFER_CFG",
            description  = "",
            offset       =  (0x009B<<2),
            bitSize      =  6,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))   

        self.add(pr.RemoteVariable(   
            name         = "RXBUF_THRESH_OVRD",
            description  = "",
            offset       =  (0x009C<<2),
            bitSize      =  1,
            bitOffset    =  8,
            base         = pr.UInt,
            mode         = "RW",
        )) 

        self.add(pr.RemoteVariable(   
            name         = "RXBUF_RESET_ON_EIDLE",
            description  = "",
            offset       =  (0x009C<<2),
            bitSize      =  1,
            bitOffset    =  6,
            base         = pr.UInt,
            mode         = "RW",
        ))   

        self.add(pr.RemoteVariable(   
            name         = "RXBUF_THRESH_UNDFLW",
            description  = "",
            offset       =  (0x009C<<2),
            bitSize      =  6,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))      

        self.add(pr.RemoteVariable(   
            name         = "RXBUF_EIDLE_HI_CNT",
            description  = "",
            offset       =  (0x009D<<2),
            bitSize      =  4,
            bitOffset    =  12,
            base         = pr.UInt,
            mode         = "RW",
        ))     

        self.add(pr.RemoteVariable(   
            name         = "RXBUF_EIDLE_LO_CNT",
            description  = "",
            offset       =  (0x009D<<2),
            bitSize      =  4,
            bitOffset    =  8,
            base         = pr.UInt,
            mode         = "RW",
        )) 

        self.add(pr.RemoteVariable(   
            name         = "RXBUF_ADDR_MODE",
            description  = "",
            offset       =  (0x009D<<2),
            bitSize      =  1,
            bitOffset    =  7,
            base         = pr.UInt,
            mode         = "RW",
        ))   

        self.add(pr.RemoteVariable(   
            name         = "RXBUF_THRESH_OVFLW",
            description  = "",
            offset       =  (0x009D<<2),
            bitSize      =  6,
            bitOffset    =  1,
            base         = pr.UInt,
            mode         = "RW",
        ))           
        
        self.add(pr.RemoteVariable(   
            name         = "RX_DEFER_RESET_BUF_EN",
            description  = "",
            offset       =  (0x009D<<2),
            bitSize      =  1,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        )) 

        self.add(pr.RemoteVariable(   
            name         = "RXBUF_RESET_ON_COMMAALIGN",
            description  = "",
            offset       =  (0x009E<<2),
            bitSize      =  1,
            bitOffset    =  2,
            base         = pr.UInt,
            mode         = "RW",
        ))  

        self.add(pr.RemoteVariable(   
            name         = "RXBUF_RESET_ON_RATE_CHANGE",
            description  = "",
            offset       =  (0x009E<<2),
            bitSize      =  1,
            bitOffset    =  1,
            base         = pr.UInt,
            mode         = "RW",
        ))   

        self.add(pr.RemoteVariable(   
            name         = "RXBUF_RESET_ON_CB_CHANGE",
            description  = "",
            offset       =  (0x009E<<2),
            bitSize      =  1,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        )) 

        self.add(pr.RemoteVariable(   
            name         = "TXDLY_LCFG",
            description  = "",
            offset       =  (0x009F<<2),
            bitSize      =  9,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))         
        
        self.add(pr.RemoteVariable(   
            name         = "RXDLY_LCFG",
            description  = "",
            offset       =  (0x00A0<<2),
            bitSize      =  9,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        )) 

        self.add(pr.RemoteVariable(   
            name         = "RXPH_CFG_WRD0",
            description  = "",
            offset       =  (0x00A1<<2),
            bitSize      =  16,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))  

        self.add(pr.RemoteVariable(   
            name         = "RXPH_CFG_WRD1",
            description  = "",
            offset       =  (0x00A2<<2),
            bitSize      =  8,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))  

        self.add(pr.RemoteVariable(   
            name         = "RXPHDLY_CFG_WRD0",
            description  = "",
            offset       =  (0x00A3<<2),
            bitSize      =  16,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))  

        self.add(pr.RemoteVariable(   
            name         = "RXPHDLY_CFG_WRD1",
            description  = "",
            offset       =  (0x00A4<<2),
            bitSize      =  8,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))  
        
        self.add(pr.RemoteVariable(   
            name         = "RX_DEBUG_CFG",
            description  = "",
            offset       =  (0x00A5<<2),
            bitSize      =  14,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))    

        self.add(pr.RemoteVariable(   
            name         = "ES_PMA_CFG",
            description  = "",
            offset       =  (0x00A6<<2),
            bitSize      =  10,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))    

        self.add(pr.RemoteVariable(   
            name         = "RXCDR_PH_RESET_ON_EIDLE",
            description  = "",
            offset       =  (0x00A7<<2),
            bitSize      =  1,
            bitOffset    =  13,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(   
            name         = "RXCDR_FR_RESET_ON_EIDLE",
            description  = "",
            offset       =  (0x00A7<<2),
            bitSize      =  1,
            bitOffset    =  12,
            base         = pr.UInt,
            mode         = "RW",
        ))    

        self.add(pr.RemoteVariable(   
            name         = "RXCDR_HOLD_DURING_EIDLE",
            description  = "",
            offset       =  (0x00A7<<2),
            bitSize      =  1,
            bitOffset    =  11,
            base         = pr.UInt,
            mode         = "RW",
        ))   

        self.add(pr.RemoteVariable(   
            name         = "RXCDR_LOCK_CFG",
            description  = "",
            offset       =  (0x00A7<<2),
            bitSize      =  6,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))     

        self.add(pr.RemoteVariable(   
            name         = "RXCDR_CFG_WRD0",
            description  = "",
            offset       =  (0x00A8<<2),
            bitSize      =  16,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))    

        self.add(pr.RemoteVariable(   
            name         = "RXCDR_CFG_WRD1",
            description  = "",
            offset       =  (0x00A9<<2),
            bitSize      =  16,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))     

        self.add(pr.RemoteVariable(   
            name         = "RXCDR_CFG_WRD2",
            description  = "",
            offset       =  (0x00AA<<2),
            bitSize      =  16,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))  

        self.add(pr.RemoteVariable(   
            name         = "RXCDR_CFG_WRD3",
            description  = "",
            offset       =  (0x00AB<<2),
            bitSize      =  16,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))   

        self.add(pr.RemoteVariable(   
            name         = "RXCDR_CFG_WRD4",
            description  = "",
            offset       =  (0x00AC<<2),
            bitSize      =  16,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(   
            name         = "RXCDR_CFG_WRD5",
            description  = "",
            offset       =  (0x00AD<<2),
            bitSize      =  3,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))
