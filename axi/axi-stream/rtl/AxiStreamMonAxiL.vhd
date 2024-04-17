-------------------------------------------------------------------------------
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
      TPD_G            : time     := 1 ns;
      RST_ASYNC_G      : boolean  := false;
      COMMON_CLK_G     : boolean  := false;  -- true if axisClk = axilClk
      AXIS_CLK_FREQ_G  : real     := 156.25E+6;  -- units of Hz
      AXIS_NUM_SLOTS_G : positive := 1;
      AXIS_CONFIG_G    : AxiStreamConfigType);
   port (
      -- AXIS Stream Interface
      axisClk          : in  sl;
      axisRst          : in  sl;
      axisMasters      : in  AxiStreamMasterArray(AXIS_NUM_SLOTS_G-1 downto 0);
      axisSlaves       : in  AxiStreamSlaveArray(AXIS_NUM_SLOTS_G-1 downto 0);
      -- AXI lite slave port for register access
      axilClk          : in  sl;
      axilRst          : in  sl;
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
      cnt  : slv(ADDR_WIDTH_C-1 downto 0);
      addr : slv(ADDR_WIDTH_C-1 downto 0);
      ch   : natural range 0 to AXIS_NUM_SLOTS_G-1;
   end record;

   constant REG_INIT_C : RegType := (
      we   => '0',
      data => (others => '0'),
      cnt  => (others => '1'),  -- pre-set to all ones so 1st write after reset is address=0x0
      addr => (others => '1'),  -- pre-set to all ones so 1st write after reset is address=0x0
      ch   => 0);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal rstCnt     : sl;
   signal localReset : sl;
   signal axisReset  : sl;

   signal frameCnt : Slv64Array(AXIS_NUM_SLOTS_G-1 downto 0);

   signal frameSize    : Slv32Array(AXIS_NUM_SLOTS_G-1 downto 0);
   signal frameSizeMax : Slv32Array(AXIS_NUM_SLOTS_G-1 downto 0);
   signal frameSizeMin : Slv32Array(AXIS_NUM_SLOTS_G-1 downto 0);

   signal frameRate    : Slv32Array(AXIS_NUM_SLOTS_G-1 downto 0);
   signal frameRateMax : Slv32Array(AXIS_NUM_SLOTS_G-1 downto 0);
   signal frameRateMin : Slv32Array(AXIS_NUM_SLOTS_G-1 downto 0);

   signal bandwidth    : Slv64Array(AXIS_NUM_SLOTS_G-1 downto 0);
   signal bandwidthMax : Slv64Array(AXIS_NUM_SLOTS_G-1 downto 0);
   signal bandwidthMin : Slv64Array(AXIS_NUM_SLOTS_G-1 downto 0);

   -- attribute dont_touch                 : string;
   -- attribute dont_touch of r            : signal is "true";
   -- attribute dont_touch of rstCnt       : signal is "true";
   -- attribute dont_touch of localReset   : signal is "true";
   -- attribute dont_touch of axisReset    : signal is "true";
   -- attribute dont_touch of frameCnt     : signal is "true";
   -- attribute dont_touch of frameSize    : signal is "true";
   -- attribute dont_touch of frameSizeMax : signal is "true";
   -- attribute dont_touch of frameSizeMin : signal is "true";
   -- attribute dont_touch of frameRate    : signal is "true";
   -- attribute dont_touch of frameRateMax : signal is "true";
   -- attribute dont_touch of frameRateMin : signal is "true";
   -- attribute dont_touch of bandwidth    : signal is "true";
   -- attribute dont_touch of bandwidthMax : signal is "true";
   -- attribute dont_touch of bandwidthMin : signal is "true";

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
            RST_ASYNC_G     => RST_ASYNC_G,
            COMMON_CLK_G    => true,             -- true if axisClk = statusClk
            AXIS_CLK_FREQ_G => AXIS_CLK_FREQ_G,  -- units of Hz
            AXIS_CONFIG_G   => AXIS_CONFIG_G)
         port map(
            -- AXIS Stream Interface
            axisClk      => axisClk,
            axisRst      => axisReset,
            axisMaster   => axisMasters(i),
            axisSlave    => axisSlaves(i),
            -- Status Clock and reset
            statusClk    => axisClk,
            statusRst    => axisReset,
            -- Status: Total number of frame received since statusRst
            frameCnt     => frameCnt(i),
            -- Status: Frame Size (units of Byte)
            frameSize    => frameSize(i),
            frameSizeMax => frameSizeMax(i),
            frameSizeMin => frameSizeMin(i),
            -- Status: Frame rate (units of Hz)
            frameRate    => frameRate(i),
            frameRateMax => frameRateMax(i),
            frameRateMin => frameRateMin(i),
            -- Status: Bandwidth (units of Byte/s)
            bandwidth    => bandwidth(i),
            bandwidthMax => bandwidthMax(i),
            bandwidthMin => bandwidthMin(i));

   end generate;

   U_AxiDualPortRam : entity surf.AxiDualPortRam
      generic map (
         TPD_G          => TPD_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         SYNTH_MODE_G   => "inferred",
         MEMORY_TYPE_G  => ite(ADDR_WIDTH_C > 5, "block", "distributed"),
         READ_LATENCY_G => ite(ADDR_WIDTH_C > 5, 2, 1),
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
                   frameRate, frameRateMax, frameRateMin, frameSize,
                   frameSizeMax, frameSizeMin, r) is
      variable v   : RegType;
      variable wrd : slv(3 downto 0);
   begin
      -- Latch the current value
      v := r;

      -- Increment the counter
      v.cnt := r.cnt + 1;

      -- Write the status counter to RAM
      v.we   := '1';
      v.addr := v.cnt;

      -- Case on the word index
      wrd := v.addr(3 downto 0);
      case (wrd) is
         ----------------------------------------------------------------------
         when x"0" =>  -- i*0x40 + 0x00: DMA AXI Stream Configuration (debugging)

            v.data(31 downto 24) := toSlv(AXIS_CONFIG_G.TDATA_BYTES_C, 8);
            v.data(23 downto 20) := toSlv(AXIS_CONFIG_G.TDEST_BITS_C, 4);
            v.data(19 downto 16) := toSlv(AXIS_CONFIG_G.TUSER_BITS_C, 4);
            v.data(15 downto 12) := toSlv(AXIS_CONFIG_G.TID_BITS_C, 4);

            case AXIS_CONFIG_G.TKEEP_MODE_C is
               when TKEEP_NORMAL_C => v.data(11 downto 8) := x"0";
               when TKEEP_COMP_C   => v.data(11 downto 8) := x"1";
               when TKEEP_FIXED_C  => v.data(11 downto 8) := x"2";
               when TKEEP_COUNT_C  => v.data(11 downto 8) := x"3";
               when others         => v.data(11 downto 8) := x"F";
            end case;

            case AXIS_CONFIG_G.TUSER_MODE_C is
               when TUSER_NORMAL_C     => v.data(7 downto 4) := x"0";
               when TUSER_FIRST_LAST_C => v.data(7 downto 4) := x"1";
               when TUSER_LAST_C       => v.data(7 downto 4) := x"2";
               when TUSER_NONE_C       => v.data(7 downto 4) := x"3";
               when others             => v.data(7 downto 4) := x"F";
            end case;

            v.data(3) := '0';
            v.data(2) := '0';
            v.data(1) := ite(AXIS_CONFIG_G.TSTRB_EN_C, '1', '0');
            v.data(0) := ite(COMMON_CLK_G, '1', '0');

         ----------------------------------------------------------------------
         when x"1" => v.data := frameCnt(r.ch)(31 downto 0);   -- i*0x40 + 0x04
         when x"2" => v.data := frameCnt(r.ch)(63 downto 32);  -- i*0x40 + 0x08
         ----------------------------------------------------------------------
         when x"3" => v.data := frameRate(r.ch);               -- i*0x40 + 0x0C
         when x"4" => v.data := frameRateMax(r.ch);            -- i*0x40 + 0x10
         when x"5" => v.data := frameRateMin(r.ch);            -- i*0x40 + 0x14
         ----------------------------------------------------------------------
         when x"6" => v.data := bandwidth(r.ch)(31 downto 0);  -- i*0x40 + 0x18
         when x"7" => v.data := bandwidth(r.ch)(63 downto 32);  -- i*0x40 + 0x1C
         when x"8" => v.data := bandwidthMax(r.ch)(31 downto 0);  -- i*0x40 + 0x20
         when x"9" => v.data := bandwidthMax(r.ch)(63 downto 32);  -- i*0x40 + 0x24
         when x"A" => v.data := bandwidthMin(r.ch)(31 downto 0);  -- i*0x40 + 0x28
         when x"B" => v.data := bandwidthMin(r.ch)(63 downto 32);  -- i*0x40 + 0x2C
         ----------------------------------------------------------------------
         when x"C" => v.data := frameSize(r.ch);               -- i*0x40 + 0x30
         when x"D" => v.data := frameSizeMax(r.ch);            -- i*0x40 + 0x34
         when x"E" => v.data := frameSizeMin(r.ch);            -- i*0x40 + 0x38
         ----------------------------------------------------------------------
         when x"F" =>                   -- i*0x40 + 0x3C: Debugging
            v.data(7 downto 0)   := toSlv(AXIS_NUM_SLOTS_G, 8);
            v.data(15 downto 8)  := toSlv(ADDR_WIDTH_C, 8);
            v.data(23 downto 16) := toSlv(r.ch, 8);
            v.data(31 downto 16) := (others => '0');
         -----------------------------------------------------------------------
         when others =>
            v.we := '0';
      -----------------------------------------------------------------------
      end case;

      -- Check for last word
      if (wrd = x"F") then

         -- Check for last word
         if (r.ch = AXIS_NUM_SLOTS_G-1) then
            -- Reset the counters
            v.ch  := 0;
            v.cnt := (others => '1');  -- pre-set to all ones so 1st write after reset is address=0x0
         else
            -- Increment the counters
            v.ch := r.ch + 1;
         end if;

      end if;

      -- Synchronous Reset
      if (RST_ASYNC_G = false and axisRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (axisClk, axisRst) is
   begin
      if (RST_ASYNC_G) and (axisRst = '1') then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(axisClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
