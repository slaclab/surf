-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: EthMacRxCsum for Frag SOF Simulation Testbed
-------------------------------------------------------------------------------
-- This file is part of 'LCLS2 LLRF Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'LCLS2 LLRF Firmware', including this file,
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
use surf.SsiPkg.all;
use surf.EthMacPkg.all;

entity EthMacRxCsumFragTb is end EthMacRxCsumFragTb;

architecture testbed of EthMacRxCsumFragTb is

   constant CLK_PERIOD_C : time := 10 ns;
   constant TPD_G        : time := CLK_PERIOD_C/4;

   type RegType is record
      wrdCnt   : natural range 0 to 255;
      cnt      : natural range 0 to 15;
      txMaster : AxiStreamMasterType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      wrdCnt   => 0,
      cnt      => 0,
      txMaster => AXI_STREAM_MASTER_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal clk : sl := '0';
   signal rst : sl := '1';

begin

   U_ClkRst : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,  -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 1000 ns)  -- Hold reset for this long)
      port map (
         clkP => clk,
         rst  => rst);

   comb : process (r, rst) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobes
      v.txMaster.tValid := '0';
      v.txMaster.tLast  := '0';
      v.txMaster.tUser  := (others => '0');
      v.txMaster.tKeep  := (others => '1');

      -- Check the counter
      if r.cnt = 15 then

         -- Reset the counter
         v.cnt := 0;

         -- Increment the counter
         v.wrdCnt := r.wrdCnt + 1;

         -- Set the flag
         v.txMaster.tValid := '1';

         if (r.wrdCnt = 0) then
            ssiSetUserSof(EMAC_AXIS_CONFIG_C, v.txMaster, '1');
         end if;

         -- State Machine
         case r.wrdCnt is
            when 0 =>
               ssiSetUserSof(EMAC_AXIS_CONFIG_C, v.txMaster, '1');
               v.txMaster.tData(127 downto 0) := endianSwap(x"0800560044d9001b21bd402208004500");
            when 1   => v.txMaster.tData(127 downto 0) := endianSwap(x"05dc9105200040113e88c0a80201c0a8");
            when 2   => v.txMaster.tData(127 downto 0) := endianSwap(x"023208010339106ce826a726d1870000");
            when 3   => v.txMaster.tData(127 downto 0) := endianSwap(x"00010000000000000000000000000000");
            when 4   => v.txMaster.tData(127 downto 0) := endianSwap(x"00000000000000000001000081ed0000");
            when 5   => v.txMaster.tData(127 downto 0) := endianSwap(x"00010000000000000000001278680000");
            when 6   => v.txMaster.tData(127 downto 0) := endianSwap(x"1000ffffffff00000940dbb5ff470128");
            when 7   => v.txMaster.tData(127 downto 0) := endianSwap(x"18295cb60095000904f85caf3b540000");
            when 8   => v.txMaster.tData(127 downto 0) := endianSwap(x"00005cafe4800004e2b8000010000000");
            when 9   => v.txMaster.tData(127 downto 0) := endianSwap(x"000012000000d0020000000000000000");
            when 10  => v.txMaster.tData(127 downto 0) := endianSwap(x"0000120000006c440000000000000000");
            when 11  => v.txMaster.tData(127 downto 0) := endianSwap(x"00001200000073460000000000000000");
            when 12  => v.txMaster.tData(127 downto 0) := endianSwap(x"0000120000002f380000000000000000");
            when 13  => v.txMaster.tData(127 downto 0) := endianSwap(x"000012000000314a0000000000000000");
            when 14  => v.txMaster.tData(127 downto 0) := endianSwap(x"000012000000e4010000000000000000");
            when 15  => v.txMaster.tData(127 downto 0) := endianSwap(x"00001200000027170000000000000000");
            when 16  => v.txMaster.tData(127 downto 0) := endianSwap(x"000012000000042e0000000000000000");
            when 17  => v.txMaster.tData(127 downto 0) := endianSwap(x"0000120000009b420000000000000000");
            when 18  => v.txMaster.tData(127 downto 0) := endianSwap(x"00001200000076250000000000000000");
            when 19  => v.txMaster.tData(127 downto 0) := endianSwap(x"000012000000683d0000000000000000");
            when 20  => v.txMaster.tData(127 downto 0) := endianSwap(x"000012000000f9420000000000000000");
            when 31  => v.txMaster.tData(127 downto 0) := endianSwap(x"000012000000cc320000000000000000");
            when 32  => v.txMaster.tData(127 downto 0) := endianSwap(x"000012000000c71a0000000000000000");
            when 33  => v.txMaster.tData(127 downto 0) := endianSwap(x"000012000000834b0000000000000000");
            when 34  => v.txMaster.tData(127 downto 0) := endianSwap(x"00001200000096230000000000000000");
            when 35  => v.txMaster.tData(127 downto 0) := endianSwap(x"00001200000077470000000000000000");
            when 36  => v.txMaster.tData(127 downto 0) := endianSwap(x"000012000000b9490000000000000000");
            when 37  => v.txMaster.tData(127 downto 0) := endianSwap(x"000012000000db2a0000000000000000");
            when 38  => v.txMaster.tData(127 downto 0) := endianSwap(x"000012000000cb0c0000000000000000");
            when 39  => v.txMaster.tData(127 downto 0) := endianSwap(x"00001200000093040000000000000000");
            when 40  => v.txMaster.tData(127 downto 0) := endianSwap(x"000012000000c2120000000000000000");
            when 41  => v.txMaster.tData(127 downto 0) := endianSwap(x"000012000000db360000000000000000");
            when 42  => v.txMaster.tData(127 downto 0) := endianSwap(x"00001200000008110000000000000000");
            when 43  => v.txMaster.tData(127 downto 0) := endianSwap(x"000012000000704a0000000000000000");
            when 44  => v.txMaster.tData(127 downto 0) := endianSwap(x"0000120000007f390000000000000000");
            when 45  => v.txMaster.tData(127 downto 0) := endianSwap(x"000012000000ea2e0000000000000000");
            when 46  => v.txMaster.tData(127 downto 0) := endianSwap(x"000012000000c30a0000000000000000");
            when 47  => v.txMaster.tData(127 downto 0) := endianSwap(x"000012000000420d0000000000000000");
            when 48  => v.txMaster.tData(127 downto 0) := endianSwap(x"00001200000001490000000000000000");
            when 49  => v.txMaster.tData(127 downto 0) := endianSwap(x"0000120000006a2c0000000000000000");
            when 50  => v.txMaster.tData(127 downto 0) := endianSwap(x"00001200000048100000000000000000");
            when 51  => v.txMaster.tData(127 downto 0) := endianSwap(x"0000120000003a110000000000000000");
            when 52  => v.txMaster.tData(127 downto 0) := endianSwap(x"000012000000f91a0000000000000000");
            when 53  => v.txMaster.tData(127 downto 0) := endianSwap(x"000012000000f3430000000000000000");
            when 54  => v.txMaster.tData(127 downto 0) := endianSwap(x"000012000000c9470000000000000000");
            when 55  => v.txMaster.tData(127 downto 0) := endianSwap(x"000012000000b70e0000000000000000");
            when 56  => v.txMaster.tData(127 downto 0) := endianSwap(x"000012000000ca220000000000000000");
            when 57  => v.txMaster.tData(127 downto 0) := endianSwap(x"0000120000005d360000000000000000");
            when 58  => v.txMaster.tData(127 downto 0) := endianSwap(x"00001200000035260000000000000000");
            when 59  => v.txMaster.tData(127 downto 0) := endianSwap(x"0000120000004e2d0000000000000000");
            when 60  => v.txMaster.tData(127 downto 0) := endianSwap(x"000012000000162a0000000000000000");
            when 61  => v.txMaster.tData(127 downto 0) := endianSwap(x"0000120000009e480000000000000000");
            when 62  => v.txMaster.tData(127 downto 0) := endianSwap(x"000012000000a3180000000000000000");
            when 63  => v.txMaster.tData(127 downto 0) := endianSwap(x"00001200000043350000000000000000");
            when 64  => v.txMaster.tData(127 downto 0) := endianSwap(x"000012000000d8270000000000000000");
            when 65  => v.txMaster.tData(127 downto 0) := endianSwap(x"000012000000872c0000000000000000");
            when 66  => v.txMaster.tData(127 downto 0) := endianSwap(x"00001200000061180000000000000000");
            when 67  => v.txMaster.tData(127 downto 0) := endianSwap(x"00001200000059220000000000000000");
            when 68  => v.txMaster.tData(127 downto 0) := endianSwap(x"000012000000e7300000000000000000");
            when 69  => v.txMaster.tData(127 downto 0) := endianSwap(x"000012000000ff000000000000000000");
            when 70  => v.txMaster.tData(127 downto 0) := endianSwap(x"000012000000403d0000000000000000");
            when 71  => v.txMaster.tData(127 downto 0) := endianSwap(x"0000120000004f2e0000000000000000");
            when 72  => v.txMaster.tData(127 downto 0) := endianSwap(x"000012000000f94a0000000000000000");
            when 73  => v.txMaster.tData(127 downto 0) := endianSwap(x"0000120000007e460000000000000000");
            when 74  => v.txMaster.tData(127 downto 0) := endianSwap(x"0000120000009b200000000000000000");
            when 75  => v.txMaster.tData(127 downto 0) := endianSwap(x"0000120000003c1b0000000000000000");
            when 76  => v.txMaster.tData(127 downto 0) := endianSwap(x"000012000000d81f0000000000000000");
            when 77  => v.txMaster.tData(127 downto 0) := endianSwap(x"000012000000e5160000000000000000");
            when 78  => v.txMaster.tData(127 downto 0) := endianSwap(x"000012000000480a0000000000000000");
            when 79  => v.txMaster.tData(127 downto 0) := endianSwap(x"000012000000ca300000000000000000");
            when 80  => v.txMaster.tData(127 downto 0) := endianSwap(x"000012000000a8090000000000000000");
            when 81  => v.txMaster.tData(127 downto 0) := endianSwap(x"000012000000590f0000000000000000");
            when 82  => v.txMaster.tData(127 downto 0) := endianSwap(x"000012000000523a0000000000000000");
            when 83  => v.txMaster.tData(127 downto 0) := endianSwap(x"00001200000063470000000000000000");
            when 84  => v.txMaster.tData(127 downto 0) := endianSwap(x"000012000000e7420000000000000000");
            when 85  => v.txMaster.tData(127 downto 0) := endianSwap(x"00001200000027350000000000000000");
            when 86  => v.txMaster.tData(127 downto 0) := endianSwap(x"000012000000ba230000000000000000");
            when 87  => v.txMaster.tData(127 downto 0) := endianSwap(x"000012000000b3080000000000000000");
            when 88  => v.txMaster.tData(127 downto 0) := endianSwap(x"000012000000f30a0000000000000000");
            when 89  => v.txMaster.tData(127 downto 0) := endianSwap(x"000012000000910e0000000000000000");
            when 90  => v.txMaster.tData(127 downto 0) := endianSwap(x"00001200000058460000000000000000");
            when 91  => v.txMaster.tData(127 downto 0) := endianSwap(x"000012000000ab290000000000000000");
            when 92  => v.txMaster.tData(127 downto 0) := endianSwap(x"0000120000000e0a0000000000000000");
            when 93  => v.txMaster.tData(127 downto 0) := endianSwap(x"000012000000aa4a0000000000000000");
            when 94  => v.txMaster.tData(127 downto 0) := endianSwap(x"00001200000089150000000000000000");
            when 95  => v.txMaster.tData(127 downto 0) := endianSwap(x"00001200000085090000000000000000");
            when 96  => v.txMaster.tData(127 downto 0) := endianSwap(x"000012000000be060000000000000000");
            when 97  => v.txMaster.tData(127 downto 0) := endianSwap(x"000012000000e42d0000000000000000");
            when 98  => v.txMaster.tData(127 downto 0) := endianSwap(x"00001200000065060000000000000000");
            when 99  => v.txMaster.tData(127 downto 0) := endianSwap(x"00001200000086140000000000000000");
            when 100 => v.txMaster.tData(127 downto 0) := endianSwap(x"000012000000604a0000000000000000");
            when 101 => v.txMaster.tData(127 downto 0) := endianSwap(x"000012000000651a0000000000000000");
            when 102 => v.txMaster.tData(127 downto 0) := endianSwap(x"0000120000005a1d0000000000000000");
            when 103 => v.txMaster.tData(127 downto 0) := endianSwap(x"000012000000fd2c0000000000000000");
            when 104 =>
               v.txMaster.tLast              := '1';
               v.txMaster.tData(79 downto 0) := endianSwap(x"0000120000007e470000");
               v.txMaster.tKeep              := resize(x"3FF", AXI_STREAM_MAX_TKEEP_WIDTH_C);
            when others =>
               -- Stop
               v.wrdCnt := r.wrdCnt;
               v.txMaster.tValid := '0';
         ----------------------------------------------------------------------
         end case;

      else
         -- Increment the counter
         v.cnt := r.cnt + 1;
      end if;

      -- Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   U_EthMacRxCsum : entity surf.EthMacRxCsum
      generic map (
         TPD_G => TPD_G)
      port map (
         -- Clock and Reset
         ethClk      => clk,
         ethRst      => rst,
         -- Configurations
         ipCsumEn    => '1',
         tcpCsumEn   => '1',
         udpCsumEn   => '1',
         -- Inbound data from MAC
         sAxisMaster => r.txMaster,
         mAxisMaster => open);

end testbed;
