-------------------------------------------------------------------------------
-- File       : AxiStreamMonAxiL.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: AXI-Lite Wrapper on AXI Stream Monitor Module
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
use surf.AxiStreamPkg.all;
use surf.AxiLitePkg.all;

entity AxiStreamMonAxiL is
   generic (
      TPD_G            : time                := 1 ns;
      COMMON_CLK_G     : boolean             := false;  -- true if axisClk = statusClk
      AXIS_CLK_FREQ_G  : real                := 156.25E+6;  -- units of Hz
      AXIS_NUM_SLOTS_G : positive            := 1;
      AXIS_CONFIG_G    : AxiStreamConfigType := AXI_STREAM_CONFIG_INIT_C);
   port (
      -- AXIS Stream Interface
      axisClk          : in  sl;
      axisRst          : in  sl;
      axisMasters      : in  AxiStreamMasterArray(AXIS_NUM_SLOTS_G-1 downto 0);
      axisSlaves       : in  AxiStreamSlaveArray(AXIS_NUM_SLOTS_G-1 downto 0);
      -- AXI lite slave port for register access
      axilClk          : in  std_logic;
      axilRst          : in  std_logic;
      sAxilWriteMaster : in  AxiLiteWriteMasterType;
      sAxilWriteSlave  : out AxiLiteWriteSlaveType;
      sAxilReadMaster  : in  AxiLiteReadMasterType;
      sAxilReadSlave   : out AxiLiteReadSlaveType);
end AxiStreamMonAxiL;

architecture rtl of AxiStreamMonAxiL is

   constant ADDR_WIDTH_C : positive := bitSize(AXIS_NUM_SLOTS_G*16-1);

   type RegType is record
      we   : sl;
      data : slv(31 downto 0);
      addr : slv(ADDR_WIDTH_C-1 downto 0);
      ch   : natural range 0 to AXIS_NUM_SLOTS_G-1;
      wrd  : natural range 0 to 15;
   end record;

   constant REG_INIT_C : RegType := (
      we   => '0',
      data => (others => '0'),
      addr => (others => '1'),  -- pre-set to all ones so 1st write after reset is address=0x0
      ch   => 0,
      wrd  => 0);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal rstCnt     : sl;
   signal localReset : sl;
   signal axisReset  : sl;

   signal frameCnt     : Slv64Array(AXIS_NUM_SLOTS_G-1 downto 0);
   signal frameRate    : Slv32Array(AXIS_NUM_SLOTS_G-1 downto 0);
   signal frameRateMax : Slv32Array(AXIS_NUM_SLOTS_G-1 downto 0);
   signal frameRateMin : Slv32Array(AXIS_NUM_SLOTS_G-1 downto 0);
   signal bandwidth    : Slv64Array(AXIS_NUM_SLOTS_G-1 downto 0);
   signal bandwidthMax : Slv64Array(AXIS_NUM_SLOTS_G-1 downto 0);
   signal bandwidthMin : Slv64Array(AXIS_NUM_SLOTS_G-1 downto 0);

   -- attribute dont_touch          : string;
   -- attribute dont_touch of r     : signal is "true";   

begin

   -- Only doing a write address decode of 0x0
   rstCnt          <= sAxilWriteMaster.awvalid when(sAxilWriteMaster.awaddr(ADDR_WIDTH_C+1 downto 0) = 0) else '0';
   sAxilWriteSlave <= AXI_LITE_WRITE_SLAVE_EMPTY_OK_C;

   localReset <= axisRst or rstCnt;

   U_RstSync : entity surf.RstSync
      generic map (
         TPD_G => TPD_G)
      port map (
         clk      => axisClk,
         asyncRst => localReset,
         syncRst  => axisReset);

   GEN_VEC : for i in 0 to (AXIS_NUM_SLOTS_G-1) generate

      U_AxiStreamMon : entity surf.AxiStreamMon
         generic map(
            TPD_G           => TPD_G,
            COMMON_CLK_G    => true,             -- true if axisClk = statusClk
            AXIS_CLK_FREQ_G => AXIS_CLK_FREQ_G,  -- units of Hz
            AXIS_CONFIG_G   => AXIS_CONFIG_G)
         port map(
            -- AXIS Stream Interface
            axisClk      => axisClk,
            axisRst      => axisReset,
            axisMaster   => axisMasters(i),
            axisSlave    => axisSlaves(i),
            -- Status Interface
            statusClk    => axisClk,
            statusRst    => axisReset,
            frameCnt     => frameCnt(i),
            frameRate    => frameRate(i),
            frameRateMax => frameRateMax(i),
            frameRateMin => frameRateMin(i),
            bandwidth    => bandwidth(i),
            bandwidthMax => bandwidthMax(i),
            bandwidthMin => bandwidthMin(i));

   end generate;

   U_AxiDualPortRam : entity surf.AxiDualPortRam
      generic map (
         TPD_G          => TPD_G,
         SYNTH_MODE_G   => "inferred",
         MEMORY_TYPE_G  => ite(ADDR_WIDTH_C > 5, "block", "distributed"),
         READ_LATENCY_G => 3,
         AXI_WR_EN_G    => false,
         SYS_WR_EN_G    => true,
         COMMON_CLK_G   => false,
         ADDR_WIDTH_G   => ADDR_WIDTH_C,
         DATA_WIDTH_G   => 32)
      port map (
         -- Axi Port
         axiClk         => axilClk,
         axiRst         => axilRst,
         axiReadMaster  => sAxilReadMaster,
         axiReadSlave   => sAxilReadSlave,
         axiWriteMaster => AXI_LITE_WRITE_MASTER_INIT_C,
         axiWriteSlave  => open,
         -- Standard Port
         clk            => axisClk,
         rst            => axisRst,
         we             => r.we,
         addr           => r.addr,
         din            => r.data);

   comb : process (axisRst, bandwidth, bandwidthMax, bandwidthMin, frameCnt,
                   frameRate, frameRateMax, frameRateMin, r) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Write the status counter to RAM
      v.we   := '1';
      v.addr := r.addr + 1;
      case (r.wrd) is
         ----------------------------------------------------------------------   
         when 1      => v.data := frameCnt(r.ch)(31 downto 0);  -- i*0x40 + 0x04
         when 2      => v.data := frameCnt(r.ch)(63 downto 32);  -- i*0x40 + 0x08
         when 3      => v.data := frameRate(r.ch);     -- i*0x40 + 0x0C
         when 4      => v.data := frameRateMax(r.ch);  -- i*0x40 + 0x10
         when 5      => v.data := frameRateMin(r.ch);  -- i*0x40 + 0x14
         when 6      => v.data := bandwidth(r.ch)(31 downto 0);  -- i*0x40 + 0x18
         when 7      => v.data := bandwidth(r.ch)(63 downto 32);  -- i*0x40 + 0x1C
         when 8      => v.data := bandwidthMax(r.ch)(31 downto 0);  -- i*0x40 + 0x20
         when 9      => v.data := bandwidthMax(r.ch)(63 downto 32);  -- i*0x40 + 0x24
         when 10     => v.data := bandwidthMin(r.ch)(31 downto 0);  -- i*0x40 + 0x28
         when 11     => v.data := bandwidthMin(r.ch)(63 downto 32);  -- i*0x40 + 0x2C         
         when others => v.we   := '0';
      ----------------------------------------------------------------------
      end case;

      -- Check for last word
      if (r.wrd = 15) then

         -- Reset the counter
         v.wrd := 0;

         -- Check for last word
         if (r.ch = AXIS_NUM_SLOTS_G-1) then
            -- Reset the counter
            v.ch := 0;
         else
            -- Increment the counters
            v.ch := r.ch + 1;
         end if;

      else
         -- Increment the counters
         v.wrd := r.wrd + 1;
      end if;

      -- Synchronous Reset
      if (axisRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (axisClk) is
   begin
      if (rising_edge(axisClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
