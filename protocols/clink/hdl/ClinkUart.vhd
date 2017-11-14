-------------------------------------------------------------------------------
-- File       : ClinkUart.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-11-13
-------------------------------------------------------------------------------
-- Description:
-- CameraLink UART RX/TX
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

entity ClinkUart is
   generic (
      TPD_G         : time                := 1 ns;
      CLK_FREQ_G    : real                := 125.0e6;
      AXIS_CONFIG_G : AxiStreamConfigType := AXI_STREAM_CONFIG_INIT_C);
   port (
      -- Clock and reset
      clk             : in  sl;
      rst             : in  sl;
      -- Baud rate
      baud            : in  slv(23 downto 0);
      -- Data In/Out
      sAxisMaster     : in  AxiStreamMasterType;
      sAxisSlave      : out AxiStreamSlaveType;
      mAxisMaster     : out AxiStreamMasterType;
      mAxisSlave      : in  AxiStreamSlaveType;
      -- Serial data
      rxIn            : in  sl;
      txOut           : out sl);
end ClinkUart;

architecture structure of ClinkUart is

   constant INT_FREQ_C : integer := integer(CLK_FREQ_G);

   constant INT_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 1,
      TDEST_BITS_C  => 0,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_COMP_C,
      TUSER_BITS_C  => 0,
      TUSER_MODE_C  => TUSER_NONE_C);

   type RegType is   record
      count  : integer;
      clkEn  : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      count  => 0,
      clkEn  => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : Regtype;

   signal txMaster : AxiStreamMasterType;
   signal txSlave  : AxiStreamSlaveType;
   signal rxMaster : AxiStreamMasterType;
   signal rxSlave  : AxiStreamSlaveType;

begin

   -----------------------------------
   -- Baud rate generation
   -----------------------------------
   comb : process (r, rst, baud) is
      variable v : RegType;
   begin
      v := r;

      v.count := r.count + conv_integer(baud & x"0"); -- 16x
      v.clkEn := '0';

      if r.count >= INT_FREQ_C then
         v.count := '0';
         v.clkEn := '1';
      end if;

      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      rin   <= v;
   end process;

   seq : process (clk) is
   begin  
      if (rising_edge(clk)) then
         r <= rin;
      end if;
   end process;

   -------------------------------------------------------------------------------------------------
   -- Transmit FIFO
   -------------------------------------------------------------------------------------------------
   U_TxFifo: entity work.AxiStreamFifoV2
      generic map (
         TPD_G               => TPD_G,
         GEN_SYNC_FIFO_G     => true,
         FIFO_ADDR_WIDTH_G   => 9,
         SLAVE_AXI_CONFIG_G  => AXIS_CONFIG_G,
         MASTER_AXI_CONFIG_G => INT_CONFIG_G)
      port map (
         sAxisClk    => clk,
         sAxisRst    => rst,
         sAxisMaster => sAxisMaster, 
         sAxisSlave  => sAxisSlave,
         mAxisClk    => clk,
         mAxisRst    => rst,
         mAxisMaster => txMaster,
         mAxisSlave  => txSlave);

   -------------------------------------------------------------------------------------------------
   -- UART transmitter
   -------------------------------------------------------------------------------------------------
   U_UartTx_1 : entity work.UartTx
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => clk,                       -- [in]
         rst     => rst,                       -- [in]
         baud16x => r.clkEn,                   -- [in]
         wrData  => txMaster.data(7 downto 0), -- [in]
         wrValid => txMaster.tValid,           -- [in]
         wrReady => txSlave.tReady,            -- [out]
         tx      => txOut);                    -- [out]

   -------------------------------------------------------------------------------------------------
   -- UART Receiver
   -------------------------------------------------------------------------------------------------
   U_UartRx_1 : entity work.UartRx
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => clk,                       -- [in]
         rst     => rst,                       -- [in]
         baud16x => r.clkEn,                   -- [in]
         rdData  => rxMaster.tData(7 downto 0) -- [out]
         rdValid => rxMaster.tValid,           -- [out]
         rdReady => rxSlave.tReady,            -- [in]
         rx      => rxIn);                     -- [in]

   rxMaster.tData(127 downto 8) => (others => '0');
   rxMaster.tStrb  => (others => '1');
   rxMaster.tKeep  => (others => '1');
   rxMaster.tLast  => '1';
   rxMaster.tDest  => (others => '0');
   rxMaster.tId    => (others => '0');
   rxMaster.tUser  => (others => '0');

   -------------------------------------------------------------------------------------------------
   -- Receive FIFO
   -------------------------------------------------------------------------------------------------
   U_TxFifo: entity work.AxiStreamFifoV2
      generic map (
         TPD_G               => TPD_G,
         GEN_SYNC_FIFO_G     => true,
         FIFO_ADDR_WIDTH_G   => 9,
         SLAVE_AXI_CONFIG_G  => AXIS_CONFIG_G,
         MASTER_AXI_CONFIG_G => INT_CONFIG_G)
      port map (
         sAxisClk    => clk,
         sAxisRst    => rst,
         sAxisMaster => rxMaster,
         sAxisSlave  => rxSlave,
         mAxisClk    => clk,
         mAxisRst    => rst,
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);

end architecture rtl;

