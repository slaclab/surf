-------------------------------------------------------------------------------
-- Title      : CoaXPress Protocol: http://jiia.org/wp-content/themes/jiia/pdf/standard_dl/coaxpress/CXP-001-2021.pdf
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation CoaXPressCrc Testbed
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.CrcPkg.all;
use surf.Code8b10bPkg.all;

entity CoaXPressCrcTb is
end entity CoaXPressCrcTb;

architecture tb of CoaXPressCrcTb is

   constant TX_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => (8/8),           -- 8-bit data interface
      TDEST_BITS_C  => 0,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_NORMAL_C,
      TUSER_BITS_C  => 1,
      TUSER_MODE_C  => TUSER_NORMAL_C);

   constant CRC_POLY_C : slv(31 downto 0)  := x"04C11DB7";
   signal inputWord    : slv(191 downto 0) := x"FDFDFDFD_00000000_00000000_04000000_02020202_FBFBFBFB";
   signal inputUser    : slv(191 downto 0) := x"FFFFFFFF_00000000_00000000_04000000_02020202_FFFFFFFF";

   signal txMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal txSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

   signal cfgTxMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal cfgTxSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

   signal outputCrc : slv(31 downto 0);
   signal dataEnc   : slv(9 downto 0);
   signal cnt       : slv(7 downto 0) := x"00";

   signal clk : sl := '0';
   signal rst : sl := '0';

begin

   U_ClkRst : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => 10 ns,
         RST_START_DELAY_G => 0 ns,
         RST_HOLD_TIME_G   => 1000 ns)
      port map (
         clkP => clk,
         rst  => rst);

   U_Encode : entity surf.Encoder8b10b
      generic map (
         RST_POLARITY_G => '1',         -- active HIGH reset
         FLOW_CTRL_EN_G => false,
         RST_ASYNC_G    => false,
         NUM_BYTES_G    => 1)
      port map (
         -- Clock and Reset
         clk        => clk,
         rst        => rst,
         -- Decoded Interface
         dataIn     => K_28_5_C,
         dataKIn(0) => '1',
         -- Encoded Interface
         dataOut    => dataEnc);

   process(inputWord)
      variable crc     : slv(31 downto 0);
      variable retVar  : slv(31 downto 0);
      variable byteXor : slv(7 downto 0);
   begin
      -- Init
      crc     := x"FFFFFFFF";
      byteXor := (others => '0');

      for i in 8 to 15 loop
         byteXor := crc(31 downto 24) xor bitReverse(inputWord(8*i+7 downto 8*i));
         crc     := (crc(23 downto 0) & x"00") xor crcByteLookup(byteXor, CRC_POLY_C);
      end loop;

      for i in 0 to 3 loop
         retVar(8*i+7 downto 8*i) := bitReverse(crc(8*i+7 downto 8*i));
      end loop;

      -- To aid understanding, a complete control command packet
      -- without tag (a read of address 0) is shown here, with the resulting CRC shown in red:
      -- K27.7 K27.7 K27.7 K27.7
      -- 0x02 0x02 0x02 0x02
      -- 0x00 0x00 0x00 0x04
      -- 0x00 0x00 0x00 0x00
      -- 0x56 0x86 0x5D 0x6F <----- CRC-32
      -- K29.7 K29.7 K29.7 K29.7.
      outputCrc <= endianSwap(retVar);

   end process;

   TX_FIFO : entity surf.AxiStreamFifoV2
      generic map (
         -- General Configurations
         TPD_G               => 1 ns,
         -- FIFO configurations
         MEMORY_TYPE_G       => "block",
         GEN_SYNC_FIFO_G     => false,
         FIFO_ADDR_WIDTH_G   => 9,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => TX_CONFIG_C,
         MASTER_AXI_CONFIG_G => TX_CONFIG_C)
      port map (
         -- Slave Port
         sAxisClk    => clk,
         sAxisRst    => rst,
         sAxisMaster => txMaster,
         sAxisSlave  => txSlave,
         -- Master Port
         mAxisClk    => clk,
         mAxisRst    => rst,
         mAxisMaster => cfgTxMaster,
         mAxisSlave  => cfgTxSlave);

   process(clk)
   begin
      if rising_edge(clk) then
         cnt <= cnt + 1 after 1 ns;
         if rst = '1' then
            txMaster.tStrb <= (others => '0') after 1 ns;
         else
            if cnt = 0 then
               txMaster.tValid              <= '1'                  after 1 ns;
               txMaster.tLast               <= '0'                  after 1 ns;
               txMaster.tData(191 downto 0) <= inputWord            after 1 ns;
               txMaster.tUser(191 downto 0) <= inputUser            after 1 ns;
               txMaster.tKeep(23 downto 0)  <= (others => '1')      after 1 ns;
               txMaster.tStrb(23 downto 0)  <= x"FF_00_00_00_00_FF" after 1 ns;
            elsif cnt < 24 then
               txMaster.tValid <= '1'                                                             after 1 ns;
               txMaster.tData  <= x"00" & txMaster.tData(AXI_STREAM_MAX_TDATA_WIDTH_C-1 downto 8) after 1 ns;
               txMaster.tUser  <= x"00" & txMaster.tUser(AXI_STREAM_MAX_TDATA_WIDTH_C-1 downto 8) after 1 ns;
               txMaster.tStrb  <= x"00" & txMaster.tStrb(AXI_STREAM_MAX_TKEEP_WIDTH_C-1 downto 8) after 1 ns;
               if cnt = 23 then
                  txMaster.tLast <= '1' after 1 ns;
               end if;
            else
               txMaster.tValid <= '0' after 1 ns;
            end if;
         end if;
      end if;
   end process;

end architecture tb;
