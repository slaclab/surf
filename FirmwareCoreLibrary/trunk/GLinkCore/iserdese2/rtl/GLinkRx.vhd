-------------------------------------------------------------------------------
-- Title         : 
-------------------------------------------------------------------------------
-- File          : GLinkRx.vhd
-- Author        : Maciej Kwiatkowski, mkwiatko@slac.stanford.edu
-- Created       : 11/15/2016
-------------------------------------------------------------------------------
-- Description: Source synchronous deserializer of the the CIMT frames 
-- for 7 series Xilinx devices.
-------------------------------------------------------------------------------
-- This file is part of 'SLAC G-Link Core'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC G-Link Core', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
-- Modification history:
-- 11/15/2016: created.
-------------------------------------------------------------------------------

LIBRARY ieee;
use work.all;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.StdRtlPkg.all;
use work.GLinkPkg.all;
use work.AxiLitePkg.all;
use work.GlinkPkg.all;

library UNISIM;
use UNISIM.vcomponents.all;

entity GLinkRx is 
   generic (
      TPD_G             : time      := 1 ns;
      IDELAYCTRL_FREQ_G : real      := 200.0;
      IODELAY_GROUP_G   : string    := "DEFAULT_GROUP";
      INVERT_SDATA_G    : boolean   := false
   );
   port ( 
      -- global signals
      bitClk            : in  sl;   -- serial bit DDR clock
      byteClk           : in  sl;   -- serial bit clock div by 5
      byteRst           : in  sl;
      
      -- serial data in
      serDinP           : in  sl;
      serDinM           : in  sl;
      
      -- optional AXI Lite (byteClk domain)
      axilReadMaster    : in  AxiLiteReadMasterType;
      axilReadSlave     : out AxiLiteReadSlaveType;
      axilWriteMaster   : in  AxiLiteWriteMasterType;
      axilWriteSlave    : out AxiLiteWriteSlaveType;
      
      -- Deserialized output (byteClk domain)
      rxData            : out slv(19 downto 0);
      rxReady           : out sl;   -- every 2nd rxData is valid
      
      -- Debug
      testEn            : out sl;
      testAddr          : out slv(4 downto 0)
      
   );
end GLinkRx;


-- Define architecture
architecture RTL of GLinkRx is
   
   type StateType is (BIT_SLIP_S, SLIP_WAIT_S, PT0_CHECK_S, INSYNC_S);
   
   type RegType is record
      axilWriteSlave : AxiLiteWriteSlaveType;
      axilReadSlave  : AxiLiteReadSlaveType;
      state          : StateType;
      resync         : sl;
      slip           : sl;
      locked         : sl;
      delay          : slv(4 downto 0);
      delayEn        : sl;
      waitCnt        : integer range 0 to 15;
      tryCnt         : integer range 0 to 31;
      lockErrCnt     : integer range 0 to 2**16-1;
      iserdeseOutD1  : slv(9 downto 0);
      iserdeseOutD2  : slv(9 downto 0);
      cimtWord       : slv(19 downto 0);
      valid          : sl;
      rxData         : slv(19 downto 0);
      rxReady        : sl;
      testEn         : sl;
      testAddr       : slv(4 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      state          => BIT_SLIP_S,
      resync         => '0',
      slip           => '0',
      locked         => '0',
      delay          => (others=>'0'),
      delayEn        => '0',
      waitCnt        => 0,
      tryCnt         => 0,
      lockErrCnt     => 0,
      iserdeseOutD1  => (others=>'0'),
      iserdeseOutD2  => (others=>'0'),
      cimtWord       => (others=>'0'),
      valid          => '0',
      rxData         => (others=>'0'),
      rxReady        => '0',
      testEn         => '0',
      testAddr       => (others=>'0')
   );

   signal axilR   : RegType := REG_INIT_C;
   signal axilRin : RegType;
   
   signal bitClkInv     : sl;
   signal serDataBuf    : sl;
   signal serDin        : sl;
   signal serDinDly     : sl;
   signal idleWord      : sl;
   
   --signal cimtWord      : slv(19 downto 0);
   signal delayCurr     : slv(4 downto 0);
   signal iserdeseOut   : slv(9 downto 0);
   signal shift1        : sl;
   signal shift2        : sl;
   
   attribute keep : string;                              -- for chipscope
   attribute keep of iserdeseOut : signal is "true";     -- for chipscope
   attribute keep of idleWord : signal is "true";        -- for chipscope
   
   attribute IODELAY_GROUP : string;
   attribute IODELAY_GROUP of U_IDELAYE2 : label is IODELAY_GROUP_G;
   
begin

   -- Input differential buffer
   U_IBUFDS : IBUFDS
   port map (
      I    => serDinP,
      IB   => serDinM,
      O    => serDataBuf
   );
   
   serDin <= not serDataBuf when INVERT_SDATA_G = true else serDataBuf;
   
   -- input delay taps
   U_IDELAYE2 : IDELAYE2
   generic map (
      DELAY_SRC             => "IDATAIN",
      HIGH_PERFORMANCE_MODE => "TRUE",
      IDELAY_TYPE           => "VAR_LOAD",
      IDELAY_VALUE          => 0,
      REFCLK_FREQUENCY      => IDELAYCTRL_FREQ_G,
      SIGNAL_PATTERN        => "DATA"
   )
   port map (
      C           => byteClk,
      REGRST      => '0',
      LD          => axilR.delayEn,
      CE          => '0',
      INC         => '1',
      CINVCTRL    => '0',
      CNTVALUEIN  => axilR.delay,
      IDATAIN     => serDin,
      DATAIN      => '0',
      LDPIPEEN    => '0',
      DATAOUT     => serDinDly,
      CNTVALUEOUT => delayCurr
   );
   
   bitClkInv <= not bitClk;
   
   U_MasterISERDESE2 : ISERDESE2
   generic map (
      DATA_RATE         => "DDR",
      DATA_WIDTH        => 10,
      INTERFACE_TYPE    => "NETWORKING",
      DYN_CLKDIV_INV_EN => "FALSE",
      DYN_CLK_INV_EN    => "FALSE",
      NUM_CE            => 1,
      OFB_USED          => "FALSE",
      IOBDELAY          => "IFD",    -- Use input at DDLY to output the data on Q1-Q6
      SERDES_MODE       => "MASTER"
   )
   port map (
      Q1           => iserdeseOut(0),
      Q2           => iserdeseOut(1),
      Q3           => iserdeseOut(2),
      Q4           => iserdeseOut(3),
      Q5           => iserdeseOut(4),
      Q6           => iserdeseOut(5),
      Q7           => iserdeseOut(6),
      Q8           => iserdeseOut(7),
      SHIFTOUT1    => shift1,        -- Cascade connection to Slave ISERDES
      SHIFTOUT2    => shift2,        -- Cascade connection to Slave ISERDES
      BITSLIP      => axilR.slip,    -- 1-bit Invoke Bitslip. This can be used with any 
                                     -- DATA_WIDTH, cascaded or not.
      CE1          => '1',           -- 1-bit Clock enable input
      CE2          => '1',           -- 1-bit Clock enable input
      CLK          => bitClk,     -- Fast Source Synchronous SERDES clock from BUFIO
      CLKB         => bitClkInv,  -- Locally inverted clock
      CLKDIV       => byteClk,       -- Slow clock driven by BUFR
      CLKDIVP      => '0',
      D            => '0',
      DDLY         => serDinDly,   -- 1-bit Input signal from IODELAYE1.
      RST          => byteRst,         -- 1-bit Asynchronous reset only.
      SHIFTIN1     => '0',
      SHIFTIN2     => '0',
      -- unused connections
      DYNCLKDIVSEL => '0',
      DYNCLKSEL    => '0',
      OFB          => '0',
      OCLK         => '0',
      OCLKB        => '0',
      O            => open            -- unregistered output of ISERDESE1
   );         

   U_SlaveISERDESE2 : ISERDESE2
   generic map (
      DATA_RATE         => "DDR",
      DATA_WIDTH        => 10,
      INTERFACE_TYPE    => "NETWORKING",
      DYN_CLKDIV_INV_EN => "FALSE",
      DYN_CLK_INV_EN    => "FALSE",
      NUM_CE            => 1,
      OFB_USED          => "FALSE",
      IOBDELAY          => "IFD",    -- Use input at DDLY to output the data on Q1-Q6
      SERDES_MODE       => "SLAVE"
   )
   port map (
      Q1           => open,
      Q2           => open,
      Q3           => iserdeseOut(8),
      Q4           => iserdeseOut(9),
      Q5           => open,
      Q6           => open,
      Q7           => open,
      Q8           => open,
      SHIFTOUT1    => open,
      SHIFTOUT2    => open,
      SHIFTIN1     => shift1,        -- Cascade connections from Master ISERDES
      SHIFTIN2     => shift2,        -- Cascade connections from Master ISERDES
      BITSLIP      => axilR.slip,    -- 1-bit Invoke Bitslip. This can be used with any 
                                     -- DATA_WIDTH, cascaded or not.
      CE1          => '1',           -- 1-bit Clock enable input
      CE2          => '1',           -- 1-bit Clock enable input
      CLK          => bitClk,     -- Fast Source Synchronous SERDES clock from BUFIO
      CLKB         => bitClkInv,  -- Locally inverted clock
      CLKDIV       => byteClk,       -- Slow clock driven by BUFR.
      CLKDIVP      => '0',
      D            => '0',           -- Slave ISERDES module. No need to connect D, DDLY
      DDLY         => '0',
      RST          => byteRst,         -- 1-bit Asynchronous reset only.
      -- unused connections
      DYNCLKDIVSEL => '0',
      DYNCLKSEL    => '0',
      OFB          => '0',
      OCLK         => '0',
      OCLKB        => '0',
      O            => open            -- unregistered output of ISERDESE1
   );
   
   -- look for TEM idle data word
   idleWord <= '1' when
      std_match(axilR.cimtWord, "010101010101000-1101") or std_match(axilR.cimtWord, "010101010101000-1011") or std_match(axilR.cimtWord, "101010101010111-0010") or std_match(axilR.cimtWord, "101010101010111-0100")
      else '0';
   
   axilComb : process (axilR, axilReadMaster, byteRst, axilWriteMaster, delayCurr, iserdeseOut, idleWord) is
      variable v      : RegType;
      variable axilEp : AxiLiteEndpointType;
   begin
      
      v := axilR;
      
      -------------------------------------------------------------------------------------------------
      -- AXIL Interface
      -------------------------------------------------------------------------------------------------

      v.delayEn := '0';
      v.axilReadSlave.rdata := (others => '0');

      axiSlaveWaitTxn(axilEp, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);

      axiSlaveRegister(axilEp, X"00", 0, v.delay);
      axiSlaveRegister(axilEp, X"00", 5, v.delayEn, '1');
      axiSlaveRegister(axilEp, X"04", 0, v.resync);
      
      -- override delay readout with the current value from the IDELAYE2
      axiSlaveRegisterR(axilEp, X"00", 0, delayCurr);
      axiSlaveRegisterR(axilEp, X"08", 0, axilR.locked);
      axiSlaveRegisterR(axilEp, X"0C", 0, std_logic_vector(to_unsigned(axilR.lockErrCnt,16)));
      
      -- test pattern registers
      axiSlaveRegister(axilEp, X"100", 0, v.testEn);
      axiSlaveRegister(axilEp, X"104", 0, v.testAddr);

      axiSlaveDefault(axilEp, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_DECERR_C);
      
      -------------------------------------------------------------------------------------------------
      -- Bit slip state machine
      -------------------------------------------------------------------------------------------------
      v.slip  := '0';
      
      case (axilR.state) is
         when BIT_SLIP_S =>
            v.slip      := '1';
            v.waitCnt   := 0;
            v.state     := SLIP_WAIT_S;

         when SLIP_WAIT_S =>
            if axilR.waitCnt >= 15 then
               v.waitCnt   := 0;
               v.state := PT0_CHECK_S;
            else 
               v.waitCnt := axilR.waitCnt + 1;
            end if;

         when PT0_CHECK_S =>
            if axilR.valid = '1' then
               if idleWord = '1' then
                  v.tryCnt := 0;
                  v.state := INSYNC_S;
               else
                  if axilR.tryCnt /= 31 then
                     v.tryCnt := axilR.tryCnt + 1;
                  else
                     v.delay := std_logic_vector(unsigned(delayCurr) + to_unsigned(1, 5));
                     v.delayEn := '1';
                     v.tryCnt := 0;
                  end if;
                  v.state := BIT_SLIP_S;
               end if;
            end if;
         
         when INSYNC_S => 
            v.locked := '1';
            if axilR.valid = '1' and not isValidWord(toGLinkWord(axilR.cimtWord)) then
               v.locked := '0';
               v.delay := std_logic_vector(unsigned(delayCurr) + to_unsigned(1, 5));
               v.delayEn := '1';
               v.state  := BIT_SLIP_S;
               -- lock error counter can be reset only via the reg access
               if axilR.lockErrCnt /= 65535 then 
                  v.lockErrCnt := axilR.lockErrCnt + 1;  
               end if;
            end if;
         
         when others => null;
         
      end case;
      
      -- latch whole cimt word
      v.valid := not axilR.valid;
      if axilR.valid = '1' then
         v.cimtWord  := axilR.iserdeseOutD2 & axilR.iserdeseOutD1;
      end if;
      
      -- reset state machine whenever resync requested 
      if axilR.resync = '1' then
         v.resync := '0';
         v.valid := '0';
         v.cimtWord := (others=>'0');
         v.lockErrCnt := 0;
         v.locked := '0';
         v.state  := BIT_SLIP_S;
      end if;
      
      -------------------------------------------------------------------------------------------------
      -- output registers
      -------------------------------------------------------------------------------------------------
      
      -- 10 bit words pipeline
      v.iserdeseOutD1 := iserdeseOut;
      v.iserdeseOutD2 := axilR.iserdeseOutD1;
      
      -- output register
      v.rxData    := axilR.cimtWord;
      if axilR.locked = '1' or axilR.testEn = '1' then
         v.rxReady := axilR.valid;
      else
         v.rxReady := '0';
      end if;
      
      
      if (byteRst = '1') then
         v := REG_INIT_C;
      end if;
      
      
      axilRin        <= v;
      axilWriteSlave <= axilR.axilWriteSlave;
      axilReadSlave  <= axilR.axilReadSlave;
      rxData         <= axilR.rxData;
      rxReady        <= axilR.rxReady;
      -- debug signals
      testAddr       <= axilR.testAddr;
      testEn         <= axilR.testEn;
      
   end process;

   axilSeq : process (byteClk) is
   begin
      if (rising_edge(byteClk)) then
         axilR <= axilRin after TPD_G;
      end if;
   end process axilSeq;
   
   
end RTL;

