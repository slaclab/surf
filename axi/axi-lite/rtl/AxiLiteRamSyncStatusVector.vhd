-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: A wrapper of AxiDualPortRam & SyncStatusVector
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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;

entity AxiLiteRamSyncStatusVector is
   generic (
      TPD_G           : time                   := 1 ns;  -- Simulation FF output delay
      --------------------------
      -- AxiDualPortRam Generics
      --------------------------
      SYNTH_MODE_G    : string                 := "inferred";
      MEMORY_TYPE_G   : string                 := "block";
      READ_LATENCY_G  : natural range 0 to 3   := 3;
      ----------------------------
      -- SyncStatusVector Generics
      ----------------------------
      RST_POLARITY_G  : sl                     := '1';  -- '1' for active HIGH reset, '0' for active LOW reset
      RST_ASYNC_G     : boolean                := false;  -- true if reset is asynchronous, false if reset is synchronous
      COMMON_CLK_G    : boolean                := false;  -- True if wrClk and rdClk are the same clock
      IN_POLARITY_G   : slv                    := "1";  -- 0 for active LOW, 1 for active HIGH (for statusIn port)
      OUT_POLARITY_G  : sl                     := '1';  -- 0 for active LOW, 1 for active HIGH (for irqOut port)
      SYNTH_CNT_G     : slv                    := "1";  -- Set to 1 for synthesizing counter RTL, '0' to not synthesis the counter
      CNT_RST_EDGE_G  : boolean                := true;  -- true if counter reset should be edge detected, else level detected
      CNT_WIDTH_G     : positive range 1 to 32 := 32;   -- Counters' width
      WIDTH_G         : positive);      -- Status vector width
   port (
      ---------------------------------------------
      -- Inbound Status bit Signals (wrClk domain)
      ---------------------------------------------
      wrClk           : in  sl;
      wrRst           : in  sl                      := '0';
      statusIn        : in  slv(WIDTH_G-1 downto 0);  -- Data to be 'synced'
      ---------------------------------------------
      -- Outbound Status/control Signals (axilClk domain)
      ---------------------------------------------
      statusOut       : out slv(WIDTH_G-1 downto 0);  -- Synced data
      cntRstIn        : in  sl                      := '0';
      rollOverEnIn    : in  slv(WIDTH_G-1 downto 0) := (others => '0');  -- No roll over for all counters by default
      ---------------------
      -- AXI-Lite Interface
      ---------------------
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end entity AxiLiteRamSyncStatusVector;

architecture mapping of AxiLiteRamSyncStatusVector is

   constant ADDR_WIDTH_C : positive := bitSize(WIDTH_G-1);

   type RegType is record
      we   : sl;
      data : slv(CNT_WIDTH_G-1 downto 0);
      addr : slv(ADDR_WIDTH_C-1 downto 0);
      cnt  : natural range 0 to WIDTH_G-1;
   end record RegType;
   constant REG_INIT_C : RegType := (
      we   => '0',
      addr => (others => '0'),
      data => (others => '0'),
      cnt  => 0);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal statusCnt : SlVectorArray(WIDTH_G-1 downto 0, CNT_WIDTH_G-1 downto 0);

begin

   U_AxiDualPortRam : entity surf.AxiDualPortRam
      generic map (
         TPD_G          => TPD_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         SYNTH_MODE_G   => SYNTH_MODE_G,
         MEMORY_TYPE_G  => MEMORY_TYPE_G,
         READ_LATENCY_G => READ_LATENCY_G,
         AXI_WR_EN_G    => false,
         SYS_WR_EN_G    => true,
         COMMON_CLK_G   => true,
         ADDR_WIDTH_G   => ADDR_WIDTH_C,
         DATA_WIDTH_G   => CNT_WIDTH_G)
      port map (
         -- Axi Port
         axiClk         => axilClk,
         axiRst         => axilRst,
         axiReadMaster  => axilReadMaster,
         axiReadSlave   => axilReadSlave,
         axiWriteMaster => axilWriteMaster,
         axiWriteSlave  => axilWriteSlave,
         -- Standard Port
         clk            => axilClk,
         rst            => axilRst,
         we             => r.we,
         addr           => r.addr,
         din            => r.data);

   U_SyncStatusVector : entity surf.SyncStatusVector
      generic map (
         TPD_G          => TPD_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         OUT_POLARITY_G => '1',
         CNT_RST_EDGE_G => true,
         CNT_WIDTH_G    => CNT_WIDTH_G,
         WIDTH_G        => WIDTH_G)
      port map (
         -- Input Status bit Signals (wrClk domain)
         statusIn     => statusIn,
         -- Output Status bit Signals (rdClk domain)
         statusOut    => statusOut,
         -- Status Bit Counters Signals (rdClk domain)
         cntRstIn     => cntRstIn,
         rollOverEnIn => rollOverEnIn,
         cntOut       => statusCnt,
         -- Clocks and Reset Ports
         wrClk        => wrClk,
         rdClk        => axilClk);

   process (axilRst, r, statusCnt) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Write the status counter to RAM
      v.we   := '1';
      v.data := muxSlVectorArray(statusCnt, r.cnt);
      v.addr := toSlv(r.cnt, ADDR_WIDTH_C);

      -- Check for last count
      if (r.cnt = WIDTH_G-1) then
         -- Reset the counter
         v.cnt := 0;
      else
         -- Increment the counter
         v.cnt := r.cnt + 1;
      end if;

      -- Reset
      if (RST_ASYNC_G = false and axilRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Next register assignment
      rin <= v;

   end process;

   seq : process (axilClk, axilRst) is
   begin
      if (RST_ASYNC_G and axilRst = '1') then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(axilClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end mapping;
