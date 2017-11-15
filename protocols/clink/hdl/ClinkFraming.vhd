-------------------------------------------------------------------------------
-- File       : ClinkFraming.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-11-13
-------------------------------------------------------------------------------
-- Description:
-- CameraLink framing module
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

entity ClinkFraming is
   generic (
      TPD_G              : time                := 1 ns;
      SSI_EN_G           : boolean             := true; -- Insert SOF
      DATA_AXIS_CONFIG_G : AxiStreamConfigType := AXI_STREAM_CONFIG_INIT_C);
   port (
      -- System clock and reset
      sysClk       : in  sl;
      sysRst       : in  sl;
      -- Config and status
      mode         : in  slv(2 downto 0); -- 0 = Disable, 1 = Base, 2 = Medium, 3 = Full, 4 = Deca
      frameCount   : out slv(31 downto 0);
      -- Data interface
      locked       : in  slv(2 downto 0);
      running      : out sl;
      parData      : in  Slv28Array(2 downto 0);
      parValid     : in  slv(2 downto 0);
      parReady     : out slv(2 downto 0);
      -- Camera data
      dataMaster   : out AxiStreamMasterType;
      dataSlave    : in  AxiStreamSlaveType;
end ClinkFraming;

architecture structure of ClinkFraming is

   constant INT_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 1,
      TDEST_BITS_C  => 0,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_COMP_C,
      TUSER_BITS_C  => 2,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);

   type RegType is record
      ready   : sl;
      valid   : sl;
      fV      : sl;
      lV      : sl;
      dV      : sl;
      running : sl;
      data    : slv(83 downto 0);
      master  : AxiStreamMasterType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      ready   => '0',
      valid   => '0',
      fV      => '0',
      lV      => '0',
      dV      => '0',
      running => '0',
      data    => (others=>'0'),
      master  => AXI_STREAM_MASTER_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal intCtrl : AxiStreamCtrlType;

begin

   comb : process (r, sysRst, locked, intCtrl, parData, parValid) is
      variable v : RegType;
   begin
      v := r;

      -- Determine running mode and check valids
      -- Extract data, and alignment markers
      case mode is 

         -- Base mode
         when => 1
            v.running := locked(0);
            v.valid   := xValid;
            v.dV      := xData(26);
            v.fV      := xData(25);
            v.lV      := xData(24);

         -- Medium mode
         when => 2
            v.running := uAnd(locked(1 downto 0));
            v.valid   := xValid and yValid;
            v.dV      := xData(26) and yData(26);
            v.fV      := xData(25) and yData(25);
            v.lV      := xData(24) and yData(24);

         -- Full mode
         when => 3
            v.running := uAnd(locked);
            v.valid   := xValid and yValid and zValid;
            v.dV      := xData(26) and yData(26) and zData(26);
            v.fV      := xData(25) and yData(25) and zData(26);
            v.lV      := xData(24) and yData(24) and zData(24);

         -- DECA mode
         when => 4
            v.running := uAnd(locked);
            v.valid   := xValid and yValid and zValid;
            v.dV      := xData(26);
            v.fV      := xData(25);
            v.lV      := xData(24);

         -- Invalid
         when others =>
            v.running := '0';
            v.valid   := '0';
            v.dV      := '0';
            v.lV      := '0';
            v.fV      := '0';
      end case;
   
      -- Select data
      v.data(4  downto  0) := xData(4  downto  0);
      v.data(5)            := xData(6);
      v.data(6)            := xData(27);
      v.data(7)            := xData(5);
      v.data(10 downto  8) := xData(9  downto  7);
      v.data(12 downto 11) := xData(13 downto 12);
      v.data(13)           := xData(14);
      v.data(15 downto 14) := xData(11 downto 10);
      v.data(16)           := xData(15);
      v.data(19 downto 17) := xData(20 downto 18);
      v.data(21 downto 20) := xData(22 downto 21);
      v.data(23 downto 22) := xData(17 downto 16);
      v.data(83 downto 24) := (others=>'0');

      -- Medium, full, deca
      if mode > 1 then
         v.data(28 downto 24) := xData(4  downto  0);
         v.data(29)           := xData(6);
         v.data(30)           := xData(27);
         v.data(31)           := xData(5);
         v.data(34 downto 32) := xData(9  downto  7);
         v.data(36 downto 35) := xData(13 downto 12);
         v.data(37)           := xData(14);
         v.data(39 downto 48) := xData(11 downto 10);
         v.data(40)           := xData(15);
         v.data(43 downto 41) := xData(20 downto 18);
         v.data(45 downto 44) := xData(22 downto 21);
         v.data(47 downto 46) := xData(17 downto 16);
      end if;







      -- Drive ready, dump when not running
      v.ready := v.valid or (not r.running);

      -- Data valid
      if r.valid = '1' then





















      if (sysRst = '1') then
         v := REG_INIT_C;
      end if;

      rin        <= v;
      parReady   <= (others=>v.valid);
      running    <= r.running;
      frameCount <= r.count;

   end process;

   seq : process (sysClk) is
   begin  
      if (rising_edge(sysClk)) then
         r <= rin;
      end if;
   end process;

   ---------------------------------
   -- Data FIFO
   ---------------------------------
   U_DataFifo: entity work.AxiStreamFifoV2
      generic map (
         TPD_G               => TPD_G,
         SLAVE_READY_EN_G    => false,
         GEN_SYNC_FIFO_G     => true,
         FIFO_ADDR_WIDTH_G   => 9,
         SLAVE_AXI_CONFIG_G  => INT_CONFIG_C,
         MASTER_AXI_CONFIG_G => DATA_AXIS_CONFIG_G)
      port map (
         sAxisClk    => sysClk,
         sAxisRst    => sysRst,
         sAxisMaster => r.Master,
         sAxisCtrl   => intCtrl,
         mAxisClk    => sysClk,
         mAxisRst    => sysRst,
         mAxisMaster => dataMaster,
         mAxisSlave  => dataSlave);

end architecture rtl;

