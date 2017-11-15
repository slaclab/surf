-------------------------------------------------------------------------------
-- File       : AxiStreamMonAxiL.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-07-14
-- Last update: 2017-11-15
-------------------------------------------------------------------------------
-- Description: AXI Stream Monitor Module
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
use work.AxiStreamPkg.all;
use work.AxiLitePkg.all;
use work.SsiPkg.all;


entity AxiStreamMonAxiL is
   generic (
      TPD_G            : time                := 1 ns;
      COMMON_CLK_G     : boolean             := false;  -- true if axisClk = statusClk
      AXIS_CLK_FREQ_G  : real                := 156.25E+6;  -- units of Hz
      AXIS_NUM_SLOTS_G : positive            := 1;
      AXIS_CONFIG_G    : AxiStreamConfigType := AXI_STREAM_CONFIG_INIT_C;
      AXIL_ERR_RESP_G  : slv(1 downto 0)     := AXI_RESP_DECERR_C);
   port (
      -- AXIS Stream Interface
      axisClk          : in  sl;
      axisRst          : in  sl;
      axisMaster       : in  AxiStreamMasterArray(AXIS_NUM_SLOTS_G-1 downto 0);
      axisSlave        : in  AxiStreamSlaveArray(AXIS_NUM_SLOTS_G-1 downto 0);
      -- AXI lite slave port for register access
      axilClk          : in  std_logic;
      axilRst          : in  std_logic;
      sAxilWriteMaster : in  AxiLiteWriteMasterType;
      sAxilWriteSlave  : out AxiLiteWriteSlaveType;
      sAxilReadMaster  : in  AxiLiteReadMasterType;
      sAxilReadSlave   : out AxiLiteReadSlaveType);
end AxiStreamMonAxiL;

architecture rtl of AxiStreamMonAxiL is

   type RegType is record
      rstCnt          : sl;
      frameRate       : Slv32Array(AXIS_NUM_SLOTS_G-1 downto 0);
      frameRateMax    : Slv32Array(AXIS_NUM_SLOTS_G-1 downto 0);
      frameRateMin    : Slv32Array(AXIS_NUM_SLOTS_G-1 downto 0);
      bandwidth       : Slv64Array(AXIS_NUM_SLOTS_G-1 downto 0);
      bandwidthMax    : Slv64Array(AXIS_NUM_SLOTS_G-1 downto 0);
      bandwidthMin    : Slv64Array(AXIS_NUM_SLOTS_G-1 downto 0);
      sAxilWriteSlave : AxiLiteWriteSlaveType;
      sAxilReadSlave  : AxiLiteReadSlaveType;
   end record;

   constant REG_INIT_C : RegType := (
      rstCnt          => '1',
      frameRate       => (others => (others => '0')),
      frameRateMax    => (others => (others => '0')),
      frameRateMin    => (others => (others => '0')),
      bandwidth       => (others => (others => '0')),
      bandwidthMax    => (others => (others => '0')),
      bandwidthMin    => (others => (others => '0')),
      sAxilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      sAxilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal localReset : sl;
   signal axisReset  : sl;

   signal frameRate : Slv32Array(AXIS_NUM_SLOTS_G-1 downto 0);
   signal bandwidth : Slv64Array(AXIS_NUM_SLOTS_G-1 downto 0);

   -- attribute dont_touch          : string;
   -- attribute dont_touch of r     : signal is "true";   

begin

   assert (AXIS_NUM_SLOTS_G <= 85) report "AXIS_NUM_SLOTS_G must be <= 85" severity failure;

   localReset <= axisRst or r.rstCnt;

   U_axisRst : entity work.RstSync
      generic map (
         TPD_G => TPD_G)
      port map (
         clk      => axisClk,
         asyncRst => localReset,
         syncRst  => axisReset);

   GEN_VEC : for i in 0 to (AXIS_NUM_SLOTS_G-1) generate

      U_rateMonitor : entity work.AxiStreamMon
         generic map(
            TPD_G           => TPD_G,
            COMMON_CLK_G    => COMMON_CLK_G,     -- true if axisClk = statusClk
            AXIS_CLK_FREQ_G => AXIS_CLK_FREQ_G,  -- units of Hz
            AXIS_CONFIG_G   => AXIS_CONFIG_G)
         port map(
            -- AXIS Stream Interface
            axisClk    => axisClk,
            axisRst    => axisReset,
            axisMaster => axisMaster(i),
            axisSlave  => axisSlave(i),
            -- Status Interface
            statusClk  => axilClk,
            statusRst  => r.rstCnt,
            frameRate  => frameRate(i),
            bandwidth  => bandwidth(i));

   end generate;

   comb : process (axilRst, bandwidth, frameRate, r, sAxilReadMaster,
                   sAxilWriteMaster) is
      variable v      : RegType;
      variable regCon : AxiLiteEndPointType;
   begin
      -- Latch the current value
      v := r;

      for i in 0 to (AXIS_NUM_SLOTS_G-1) loop
         v.frameRate(i) := frameRate(i);
         v.bandwidth(i) := bandwidth(i);
      end loop;

      if r.rstCnt = '1' then
         for i in 0 to (AXIS_NUM_SLOTS_G-1) loop
            v.frameRateMax(i) := frameRate(i);
            v.frameRateMin(i) := frameRate(i);
            v.bandwidthMax(i) := bandwidth(i);
            v.bandwidthMin(i) := bandwidth(i);
         end loop;
      else
         for i in 0 to (AXIS_NUM_SLOTS_G-1) loop
            if r.frameRate(i) > r.frameRateMax(i) then
               v.frameRateMax(i) := r.frameRate(i);
            end if;
            if r.frameRate(i) < r.frameRateMin(i) then
               v.frameRateMin(i) := r.frameRate(i);
            end if;
            if r.bandwidth(i) > r.bandwidthMax(i) then
               v.bandwidthMax(i) := r.bandwidth(i);
            end if;
            if r.bandwidth(i) < r.bandwidthMin(i) then
               v.bandwidthMin(i) := r.bandwidth(i);
            end if;
         end loop;
      end if;

      -- Reset strobes
      v.rstCnt := '0';

      -- Determine the transaction type
      axiSlaveWaitTxn(regCon, sAxilWriteMaster, sAxilReadMaster, v.sAxilWriteSlave, v.sAxilReadSlave);

      -- Register mapping
      axiSlaveRegister (regCon, x"000", 0, v.rstCnt);

      for i in 0 to (AXIS_NUM_SLOTS_G-1) loop
         axiSlaveRegisterR(regCon, toSlv(16 + (i * 48), 12), 0, r.frameRate(i));  --x"10" + i * x"30" 
         axiSlaveRegisterR(regCon, toSlv(20 + (i * 48), 12), 0, r.frameRateMax(i));  --x"14" + i * x"30" 
         axiSlaveRegisterR(regCon, toSlv(24 + (i * 48), 12), 0, r.frameRateMin(i));  --x"18" + i * x"30" 
         axiSlaveRegisterR(regCon, toSlv(28 + (i * 48), 12), 0, r.bandwidth(i));  --x"1C" + i * x"30" 
         axiSlaveRegisterR(regCon, toSlv(36 + (i * 48), 12), 0, r.bandwidthMax(i));  --x"24" + i * x"30" 
         axiSlaveRegisterR(regCon, toSlv(44 + (i * 48), 12), 0, r.bandwidthMin(i));  --x"2C" + i * x"30" 
      end loop;

      -- Closeout the transaction
      axiSlaveDefault(regCon, v.sAxilWriteSlave, v.sAxilReadSlave, AXIL_ERR_RESP_G);

      -- Synchronous Reset
      if (axilRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      sAxilWriteSlave <= r.sAxilWriteSlave;
      sAxilReadSlave  <= r.sAxilReadSlave;

   end process comb;

   seq : process (axilClk) is
   begin
      if (rising_edge(axilClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
