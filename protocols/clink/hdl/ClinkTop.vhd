-------------------------------------------------------------------------------
-- File       : ClinkTop.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-11-13
-------------------------------------------------------------------------------
-- Description:
-- CameraLink Top Level
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.StdRtlPkg.all;
library unisim;
use unisim.vcomponents.all;

entity ClinkTop is
   generic (
      TPD_G              : time                := 1 ns;
      SYS_CLK_FREQ_G     : real                := 125.0e6;
      SSI_EN_G           : boolean             := true; -- Insert SOF
      AXI_ERROR_RESP_G   : slv(1 downto 0)     := AXI_RESP_DECERR_C;
      DATA_AXIS_CONFIG_G : AxiStreamConfigType := AXI_STREAM_CONFIG_INIT_C;
      UART_AXIS_CONFIG_G : AxiStreamConfigType := AXI_STREAM_CONFIG_INIT_C);
   port (
      -- Cable Input/Output
      cbl0Half0P      : inout slv(4 downto 0); --  2,  4,  5,  6, 3
      cbl0Half0M      : inout slv(4 downto 0); -- 15, 17, 18, 19 16
      cbl0Half1P      : in    slv(4 downto 0); --  8, 10, 11, 12,  9
      cbl0Half1M      : in    slv(4 downto 0); -- 21, 23, 24, 25, 22
      cbl0SerP        : out   sl; -- 20
      cbl0SerM        : out   sl; -- 7
      cbl1Half0P      : inout slv(4 downto 0); --  2,  4,  5,  6, 3
      cbl1Half0M      : inout slv(4 downto 0); -- 15, 17, 18, 19 16
      cbl1Half1P      : in    slv(4 downto 0); --  8, 10, 11, 12,  9
      cbl1Half1M      : in    slv(4 downto 0); -- 21, 23, 24, 25, 22
      cbl1SerP        : out   sl; -- 20
      cbl1SerM        : out   sl; -- 7
      -- System clock and reset, must be 100Mhz or greater
      sysClk          : in  sl;
      sysRst          : in  sl;
      -- Axi-Lite Interface
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;
      -- Camera Control Bits
      camCtrl         : in  Svl4Array(1 downto 0);
      -- Camera data
      dataMaster      : out AxiStreamMasterArray(1 downto 0);
      dataSlave       : in  AxiStreamSlaveArray(1 downto 0);
      -- UART data
      serRxMaster     : in  AxiStreamMasterArray(1 downto 0);
      serRxSlave      : out AxiStreamSlaveArray(1 downto 0);
      serTxMaster     : out AxiStreamMasterArray(1 downto 0);
      serTxSlave      : in  AxiStreamSlaveArray(1 downto 0));
end ClinkTop;

architecture structure of ClinkTop is

   type RegType is record
      swCamCtrl       : Slv4Array(1 downto 0);
      swCamCtrlEn     : Slv4Array(1 downto 0);
      intCamCtrl      : Slv4Array(1 downto 0);
      serBaud         : Slv24Array(1 downto 0);
      linkMode        : Slv4Array(1 downto 0);
      dataMode        : Slv4Array(1 downto 0);
      dualCable       : sl;
      axilReadSlave   : AxiLiteReadSlaveType;
      axilWriteSlave  : AxiLiteWriteSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      swCamCtrl       => (others=>(others=>'0')),
      swCamCtrlEn     => (others=>(others=>'0')),
      intCamCtrl      => (others=>(others=>'0')),
      serBaud         => (others=>(others=>'0')),
      linkMode        => (others=>(others=>'0')),
      dataMode        => (others=>(others=>'0')),
      dualCable       => '0',
      axilReadSlave   => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave  => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal intCamCtrl : Slv4Array(1 downto 0);
   signal locked     : slv(2 downto 0);
   signal running    : slv(1 downto 0);
   signal frameCount : Slv32Array(1 downto 0);
   signal dropCount  : Slv32Array(1 downto 0);
   signal parData    : Slv28Array(2 downto 0);
   signal parValid   : slv(2 downto 0);
   signal parReady   : sl;
   signal frameReady : slv(1 downto 0);

begin

   ----------------------------------------
   -- IO Modules
   ----------------------------------------

   -- Cable 0, half 0
   U_Cbl0Half0: entity work.ClinkCtrl
      generic map (
         TPD_G              => TPD_G,
         SYS_CLK_FREQ_G     => SYS_CLK_FREQ_G,
         UART_AXIS_CONFIG_G => UART_AXIS_CONFIG_G)
      port map (
         cblHalfP     => cbl0Half0P,
         cblHalfM     => cbl0Half0M,
         cblSerP      => cbl0SerP,
         cblSerM      => cbl0SerM,
         sysClk       => sysClk,
         sysRst       => sysRst,
         camCtrl      => intCamCtrl(0),
         serBaud      => r.serBaud(0),
         serRxMaster  => serRxMaster(0),
         serRxSlave   => serRxSlave(0),
         serTxMaster  => serTxMaster(0),
         serTxSlave   => serTxSlave(0),

   -- Cable 0, half 1
   U_Cbl0Half1: entity work.ClinkData
      generic map ( TPD_G => TPD_G )
      port map (
         cblHalfP  => cbl0Half1P,
         cblHalfM  => cbl0Half1M,
         sysClk    => sysClk,
         sysRst    => sysRst,
         locked    => locked(0),
         parData   => parData(0),
         parValid  => parValid(0),
         parReady  => frameReady(0));

   -- Cable 1, half 0
   U_Cbl1Half0: entity work.ClinkDual
      generic map (
         TPD_G              => TPD_G,
         SYS_CLK_FREQ_G     => SYS_CLK_FREQ_G,
         UART_AXIS_CONFIG_G => UART_AXIS_CONFIG_G)
      port map (
         cblHalfP     => cbl1Half0P,
         cblHalfM     => cbl1Half0M,
         cblSerP      => cbl1SerP,
         cblSerM      => cbl1SerM,
         sysClk       => sysClk,
         sysRst       => sysRst,
         camCtrl      => intCamCtrl(1),
         serBaud      => r.serBaud(1),
         locked       => locked(1),
         ctrlMode     => r.dualCable,
         parData      => parData(1),
         parValid     => parValid(1),
         parReady     => frameReady(0),
         serRxMaster  => serRxMaster(1),
         serRxSlave   => serRxSlave(1),
         serTxMaster  => serTxMaster(1),
         serTxSlave   => serTxSlave(1));

   -- Cable 1, half 1
   U_Cbl1Half1: entity work.ClinkData
      generic map ( TPD_G => TPD_G )
      port map (
         cblHalfP  => cbl1Half1P,
         cblHalfM  => cbl1Half1M,
         sysClk    => sysClk,
         sysRst    => sysRst,
         locked    => locked(2),
         parData   => parData(2),
         parValid  => parValid(2),
         parReady  => parReady);

   -- Ready generation
   parReady <= frameReady(1) when r.dualCable = '1' else frameReady(0);

   ---------------------------------
   -- Data Processing
   ---------------------------------
   U_Framer0 : entity work.ClinkFraming
      generic map (
         TPD_G              => TPD_G,
         SSI_EN_G           => SSI_EN_G,
         DATA_AXIS_CONFIG_G => DATA_AXIS_CONFIG_G)
      port map (
         sysClk        => sysClk,
         sysRst        => sysRst,
         linkMode      => r.linkMode(0),
         dataMode      => r.dataMode(0),
         frameCount    => frameCount(0),
         dropCount     => dropCount(0),
         locked        => locked,
         running       => running(0),
         parData       => parData,
         parValid      => parValid,
         parReady      => frameReady(0),
         dataMaster    => dataMaster(0),
         dataSlave     => dataSlave(0));

   U_Framer1 : entity work.ClinkFraming
      generic map (
         TPD_G              => TPD_G,
         SSI_EN_G           => SSI_EN_G,
         DATA_AXIS_CONFIG_G => DATA_AXIS_CONFIG_G)
      port map (
         sysClk        => sysClk,
         sysRst        => sysRst,
         linkMode      => r.linkMode(1),
         dataMode      => r.dataMode(1),
         frameCount    => frameCount(1),
         dropCount     => dropCount(1),
         locked(0)     => locked(2),
         locked(1)     => '0',
         locked(2)     => '0',
         running       => running(2),
         parData(0)    => parData(2),
         parData(1)    => (others=>'0'),
         parData(2)    => (others=>'0'),
         parValid(0)   => parValid(2),
         parValid(1)   => '0',
         parValid(2)   => '0',
         parReady      => frameReady(1),
         dataMaster    => dataMaster(1),
         dataSlave     => dataSlave(1));

   ---------------------------------
   -- Registers
   ---------------------------------
   comb : process (r, sysRst, axilReadMaster, axilWriteMaster, locked, camCtrl, running, frameCount) is
      variable v      : RegType;
      variable axilEp : AxiLiteEndpointType;
   begin

      -- Latch the current value
      v := r;

      -- Camera link secondary channel link mode generation
      if r.linkMode(0) <= 2 then  -- disable, lite or base
         v.dualCable   := '1';
         v.linkMode(1) := r.linkMode(0);
      else
         v.dualCable   := '0';
         v.linkMode(1) := (others=>'0');
      end if;

      -- Drive camera control bits
      for i in 0 to 1 loop
         for j in 0 to 3 loop
            if swCamCtrlEn(i)(j) = '1' then
               v.intCamCtrl(i)(j) := swCamCtrl(i)(j);
            else
               v.intCamCtrl(i)(j) := camCtrl(i)(j);
            end if;
         end loop;
      end loop;

      ------------------------      
      -- AXI-Lite Transactions
      ------------------------      

      -- Determine the transaction type
      axiSlaveWaitTxn(axilEp, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);

      axiSlaveRegister(axilEp, x"10",  0, v.linkMode(0));
      axiSlaveRegister(axilEp, x"10",  8, v.dataMode(0));
      axiSlaveRegister(axilEp, x"10", 16, v.dataMode(1));

      axiSlaveRegister(axilEp, x"18",  0, v.serBaud(0));
      axiSlaveRegister(axilEp, x"1C",  0, v.serBaud(1));

      axiSlaveRegister(axilEp, x"20",  0, locked);
      axiSlaveRegister(axilEp, x"20",  4, running);

      axiSlaveRegister(axilEp, x"30",  0, frameCount(0));
      axiSlaveRegister(axilEp, x"34",  0, frameCount(1));
      axiSlaveRegister(axilEp, x"38",  0, dropCount(0));
      axiSlaveRegister(axilEp, x"3C",  0, dropCount(1));

      axiSlaveRegister(axilEp, x"40",  0, v.swCamCtrl(0));
      axiSlaveRegister(axilEp, x"40",  4, v.swCamCtrl(1));
      axiSlaveRegister(axilEp, x"40",  8, v.swCamCtrlEn(0));
      axiSlaveRegister(axilEp, x"40", 12, v.swCamCtrlEn(1));

      axiSlaveDefault(axilEp, v.axilWriteSlave, v.axilReadSlave, AXI_ERROR_RESP_G);

      --------
      -- Reset
      --------
      if (sysRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs 
      axilReadSlave  <= r.axilReadSlave;
      axilWriteSlave <= r.axilWriteSlave;
      intCamCtrl     <= v.intCamCtrl;

   end process comb;

   seq : process (sysClk) is
   begin
      if (rising_edge(sysClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;

