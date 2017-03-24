-------------------------------------------------------------------------------
-- File       : FifoAsyncBuiltIn.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-28
-- Last update: 2014-07-14
-------------------------------------------------------------------------------
-- Description: Wrapper for Xilinx's built-in SYNC FIFO module
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

use work.StdRtlPkg.all;

library UNISIM;
use UNISIM.vcomponents.all;

library UNIMACRO;
use UNIMACRO.vcomponents.all;

entity FifoSyncBuiltIn is
   generic (
      TPD_G          : time                    := 1 ns;
      RST_POLARITY_G : sl                      := '1';  -- '1' for active high rst, '0' for active low
      FWFT_EN_G      : boolean                 := false;
      USE_DSP48_G    : string                  := "no";
      XIL_DEVICE_G   : string                  := "7SERIES";  -- Target Device: "VIRTEX5", "VIRTEX6", "7SERIES"  
      PIPE_STAGES_G  : natural range 0 to 16   := 0;
      DATA_WIDTH_G   : integer range 1 to 72   := 18;
      ADDR_WIDTH_G   : integer range 9 to 13   := 10;
      FULL_THRES_G   : integer range 1 to 8190 := 1;
      EMPTY_THRES_G  : integer range 1 to 8190 := 1);
   port (
      rst          : in  sl := '0';
      clk          : in  sl;
      wr_en        : in  sl;
      rd_en        : in  sl;
      din          : in  slv(DATA_WIDTH_G-1 downto 0);
      dout         : out slv(DATA_WIDTH_G-1 downto 0);
      data_count   : out slv(ADDR_WIDTH_G-1 downto 0);
      wr_ack       : out sl;
      valid        : out sl;
      overflow     : out sl;
      underflow    : out sl;
      prog_full    : out sl;
      prog_empty   : out sl;
      almost_full  : out sl;
      almost_empty : out sl;
      not_full     : out sl;
      full         : out sl;
      empty        : out sl);      
end FifoSyncBuiltIn;

architecture mapping of FifoSyncBuiltIn is
   
   function GetFifoType (d_width : in integer; a_width : in integer) return string is
   begin
      if ((d_width >= 37) and (d_width <= 72) and (a_width = 9)) then
         return "36Kb";
      elsif ((d_width >= 19) and (d_width <= 36) and (a_width = 10)) then
         return "36Kb";
      elsif ((d_width >= 19) and (d_width <= 36) and (a_width = 9)) then
         return "18Kb";
      elsif ((d_width >= 10) and (d_width <= 18) and (a_width = 11)) then
         return "36Kb";
      elsif ((d_width >= 10) and (d_width <= 18) and (a_width = 10)) then
         return "18Kb";
      elsif ((d_width >= 5) and (d_width <= 9) and (a_width = 12)) then
         return "36Kb";
      elsif ((d_width >= 5) and (d_width <= 9) and (a_width = 11)) then
         return "18Kb";
      elsif ((d_width >= 1) and (d_width <= 4) and (a_width = 13)) then
         return "36Kb";
      elsif ((d_width >= 1) and (d_width <= 4) and (a_width = 12)) then
         return "18Kb";
      else
         return "???Kb";                -- Generate error in Xilinx marco
      end if;
   end;

   constant FIFO_LENGTH_C         : integer    := ((2**ADDR_WIDTH_G)- 1);
   constant ALMOST_FULL_OFFSET_C  : bit_vector := to_bitvector(toSlv((FIFO_LENGTH_C-FULL_THRES_G), 16));
   constant ALMOST_EMPTY_OFFSET_C : bit_vector := to_bitvector(toSlv(EMPTY_THRES_G, 16));
   constant FIFO_SIZE_C           : string     := GetFifoType(DATA_WIDTH_G, ADDR_WIDTH_G);

   type ReadStatusType is
   record
      prog_empty   : sl;
      almost_empty : sl;
      empty        : sl;
   end record;
   constant READ_STATUS_INIT_C : ReadStatusType := (
      prog_empty   => '1',
      almost_empty => '1',
      empty        => '1');   
   signal fifoStatus, fwftStatus : ReadStatusType := READ_STATUS_INIT_C;

   signal wrAddrPntr,
      rdAddrPntr,
      cnt : slv(ADDR_WIDTH_G-1 downto 0) := (others => '0');
   signal buildInFull,
      buildInEmpty,
      progEmpty,
      progFull,
      readEnable,
      rstFlags,
      fifoRst,
      wrEn,
      dummyWRERR,
      sValid,
      sRdEn,
      rstDet : sl := '0';

   signal dataOut : slv(DATA_WIDTH_G-1 downto 0);

   -- Attribute for XST
   attribute use_dsp48        : string;
   attribute use_dsp48 of cnt : signal is USE_DSP48_G;
   
begin

   -- Check ADDR_WIDTH_G and DATA_WIDTH_G when USE_BUILT_IN_G = true
   assert (((DATA_WIDTH_G >= 37) and (DATA_WIDTH_G    <= 72) and (ADDR_WIDTH_G = 9))
           or ((DATA_WIDTH_G >= 19) and (DATA_WIDTH_G <= 36) and (ADDR_WIDTH_G = 10))
           or ((DATA_WIDTH_G >= 19) and (DATA_WIDTH_G <= 36) and (ADDR_WIDTH_G = 9))
           or ((DATA_WIDTH_G >= 10) and (DATA_WIDTH_G <= 18) and (ADDR_WIDTH_G = 11))
           or ((DATA_WIDTH_G >= 10) and (DATA_WIDTH_G <= 18) and (ADDR_WIDTH_G = 10))
           or ((DATA_WIDTH_G >= 5) and (DATA_WIDTH_G  <= 9) and (ADDR_WIDTH_G = 12))
           or ((DATA_WIDTH_G >= 5) and (DATA_WIDTH_G  <= 9) and (ADDR_WIDTH_G = 11))
           or ((DATA_WIDTH_G >= 1) and (DATA_WIDTH_G  <= 4) and (ADDR_WIDTH_G = 13))
           or ((DATA_WIDTH_G >= 1) and (DATA_WIDTH_G  <= 4) and (ADDR_WIDTH_G = 12)))
      report "Invalid DATA_WIDTH_G or ADDR_WIDTH_G for built-in FIFO configuration"
      severity failure;
   -----------------------------------------------------------------
   -- DATA_WIDTH | FIFO_SIZE | FIFO Depth | RDCOUNT/WRCOUNT Width --
   -- ===========|===========|============|=======================--
   --    37-72   |   "36Kb"  |     512    |         9-bit         --
   --    19-36   |   "36Kb"  |     1024   |        10-bit         --
   --    19-36   |   "18Kb"  |     512    |         9-bit         --
   --    10-18   |   "36Kb"  |     2048   |        11-bit         --
   --    10-18   |   "18Kb"  |     1024   |        10-bit         --
   --     5-9    |   "36Kb"  |     4096   |        12-bit         --
   --     5-9    |   "18Kb"  |     2048   |        11-bit         --
   --     1-4    |   "36Kb"  |     8192   |        13-bit         --
   --     1-4    |   "18Kb"  |     4096   |        12-bit         --
   -----------------------------------------------------------------       
   -- FULL_THRES_G upper range check
   assert (FULL_THRES_G <= ((2**ADDR_WIDTH_G)-2))
      report "FULL_THRES_G must be <= ((2**ADDR_WIDTH_G)-2)"
      severity failure;
   -- EMPTY_THRES_G upper range check
   assert (EMPTY_THRES_G <= ((2**ADDR_WIDTH_G)-2))
      report "EMPTY_THRES_G must be <= ((2**ADDR_WIDTH_G)-2)"
      severity failure;
   -- USE_DSP48_G check
   assert ((USE_DSP48_G = "yes") or (USE_DSP48_G = "no") or (USE_DSP48_G = "auto") or (USE_DSP48_G = "automax"))
      report "USE_DSP48_G must be either yes, no, auto, or automax"
      severity failure;

   RstSync_FULL : entity work.RstSync
      generic map (
         TPD_G           => TPD_G,
         IN_POLARITY_G   => RST_POLARITY_G,
         RELEASE_DELAY_G => 10)   
      port map (
         clk      => clk,
         asyncRst => rst,
         syncRst  => rstFlags); 

   SynchronizerEdge_FULL : entity work.SynchronizerEdge
      generic map (
         TPD_G => TPD_G)   
      port map (
         clk        => clk,
         dataIn     => rstFlags,
         risingEdge => rstDet);                 

   RstSync_FIFO : entity work.RstSync
      generic map (
         TPD_G           => TPD_G,
         RELEASE_DELAY_G => 6)   
      port map (
         clk      => clk,
         asyncRst => rstDet,
         syncRst  => fifoRst); 

   FIFO_SYNC_MACRO_Inst : FIFO_SYNC_MACRO
      generic map (
         DO_REG              => 0,  --DO_REG must be set to 0 for flags and data to follow a standard synchronous FIFO operation
         DEVICE              => XIL_DEVICE_G,  -- Target Device: "VIRTEX5", "VIRTEX6", "7SERIES"
         ALMOST_FULL_OFFSET  => ALMOST_FULL_OFFSET_C,   -- Sets almost full threshold
         ALMOST_EMPTY_OFFSET => ALMOST_EMPTY_OFFSET_C,  -- Sets the almost empty threshold
         DATA_WIDTH          => DATA_WIDTH_G,  -- Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
         FIFO_SIZE           => FIFO_SIZE_C)   -- Target BRAM, "18Kb" or "36Kb"
      port map (
         RST         => fifoRst,        -- 1-bit input reset
         CLK         => clk,            -- 1-bit input clock
         WREN        => wrEn,           -- 1-bit input write enable
         RDEN        => readEnable,     -- 1-bit input read enable
         DI          => din,            -- Input data, width defined by DATA_WIDTH parameter
         DO          => dataOut,        -- Output data, width defined by DATA_WIDTH parameter
         RDCOUNT     => rdAddrPntr,     -- Output read count, width determined by FIFO depth
         WRCOUNT     => wrAddrPntr,     -- Output write count, width determined by FIFO depth
         WRERR       => dummyWRERR,     -- 1-bit output write error
         RDERR       => underflow,      -- 1-bit output read error
         ALMOSTFULL  => progFull,       -- 1-bit output almost full
         ALMOSTEMPTY => progEmpty,      -- 1-bit output almost empty
         FULL        => buildInFull,    -- 1-bit output full
         EMPTY       => buildInEmpty);  -- 1-bit output empty  

   -- Calculate data count
   cnt        <= wrAddrPntr - rdAddrPntr;
   data_count <= cnt;

   -- Write signals
   wrEn        <= wr_en and not(rstFlags) and not(buildInFull);
   full        <= buildInFull or rstFlags;
   not_full    <= not(buildInFull or rstFlags);
   prog_full   <= progFull or rstFlags;
   almost_full <= '1' when (cnt = (FIFO_LENGTH_C-1)) else (buildInFull or rstFlags);

   process(clk)
   begin
      if rising_edge(clk) then
         wr_ack <= '0' after TPD_G;
         if wr_en = '1' then
            wr_ack <= not(buildInFull) after TPD_G;
         end if;
      end if;
   end process;

   process(clk)
   begin
      if rising_edge(clk) then
         overflow <= '0' after TPD_G;
         if (wr_en = '1') and (buildInFull = '1') then
            overflow <= '1' after TPD_G;  -- Error strobe
         end if;
      end if;
   end process;

   -- Read signals   
   fifoStatus.prog_empty   <= progEmpty or rstFlags;
   fifoStatus.almost_empty <= '1' when (cnt = 1) else (buildInEmpty or rstFlags);
   fifoStatus.empty        <= buildInEmpty or rstFlags;

   FIFO_Gen : if (FWFT_EN_G = false) generate
      readEnable   <= rd_en;
      prog_empty   <= fifoStatus.prog_empty;
      almost_empty <= fifoStatus.almost_empty;
      empty        <= fifoStatus.empty;
      dout         <= dataOut;

      process(clk)
      begin
         if rising_edge(clk) then
            valid <= '0' after TPD_G;
            if rd_en = '1' then
               valid <= not(buildInEmpty) after TPD_G;
            end if;
         end if;
      end process;
      
   end generate;

   FWFT_Gen : if (FWFT_EN_G = true) generate
      
      FifoOutputPipeline_Inst : entity work.FifoOutputPipeline
         generic map (
            TPD_G          => TPD_G,
            RST_POLARITY_G => RST_POLARITY_G,
            DATA_WIDTH_G   => DATA_WIDTH_G,
            PIPE_STAGES_G  => PIPE_STAGES_G)
         port map (
            -- Slave Port
            sData  => dataOut,
            sValid => sValid,
            sRdEn  => sRdEn,
            -- Master Port
            mData  => dout,
            mValid => valid,
            mRdEn  => rd_en,
            -- Clock and Reset
            clk    => clk,
            rst    => rst);   

      readEnable <= (sRdEn or fwftStatus.empty) and not(fifoStatus.empty);
      sValid     <= not(fwftStatus.empty);

      prog_empty   <= fwftStatus.prog_empty;
      almost_empty <= fwftStatus.almost_empty;
      empty        <= fwftStatus.empty;
      process (clk) is
      begin
         if rising_edge(clk) then
            if rstFlags = '1'then
               fwftStatus <= READ_STATUS_INIT_C after TPD_G;
            else
               fwftStatus.prog_empty   <= fifoStatus.prog_empty                            after TPD_G;
               fwftStatus.almost_empty <= fifoStatus.almost_empty                          after TPD_G;
               fwftStatus.empty        <= (sRdEn or fwftStatus.empty) and fifoStatus.empty after TPD_G;
            end if;
         end if;
      end process;
   end generate;

end architecture mapping;
