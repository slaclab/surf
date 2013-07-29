-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : FifoAsyncBuiltIn.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-28
-- Last update: 2013-07-29
-- Platform   : ISE 14.5
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2013 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;

library unimacro;
use unimacro.vcomponents.all;

entity FifoAsyncBuiltIn is
   generic (
      TPD_G         : time                    := 1 ns;
      WCLK_PERIOD_G : time                    := 1 ns;  --write clock period 
      RCLK_PERIOD_G : time                    := 1 ns;  --read clock period
      XIL_DEVICE_G  : string                  := "7SERIES";  -- Target Device: "VIRTEX5", "VIRTEX6", "7SERIES"   
      FWFT_EN_G     : boolean                 := false;
      DATA_WIDTH_G  : integer range 1 to 72   := 18;
      ADDR_WIDTH_G  : integer range 9 to 13   := 10;
      FULL_THRES_G  : integer range 6 to 8191 := 8191;
      EMPTY_THRES_G : integer range 6 to 8191 := 6);
   port (
      -- Resets
      rst        : in  sl := '0';       -- Asynchronous Reset
      --Write Ports (wr_clk domain)
      wr_clk     : in  sl;
      wr_en      : in  sl := '0';
      din        : in  slv(DATA_WIDTH_G-1 downto 0);
      wr_ack     : out sl;
      overflow   : out sl;
      prog_full  : out sl;
      full       : out sl;
      not_full   : out sl;
      --Read Ports (rd_clk domain)
      rd_clk     : in  sl;
      rd_en      : in  sl := '0';
      dout       : out slv(DATA_WIDTH_G-1 downto 0);
      valid      : out sl;
      underflow  : out sl;
      prog_empty : out sl;
      empty      : out sl);
begin
   -- check ADDR_WIDTH_G and DATA_WIDTH_G when USE_BUILT_IN_G = true
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
   -- check that the user set the WCLK_PERIOD_G parameter
   assert (WCLK_PERIOD_G > 1.0000001 ns)
      report "WCLK_PERIOD_G not configured yet"
      severity failure;

   -- check that the user set the WCLK_PERIOD_G parameter
   assert (RCLK_PERIOD_G > 1.0000001 ns)
      report "RCLK_PERIOD_G not configured yet"
      severity failure;

   -- FULL_THRES_G lower range check
   assert (FULL_THRES_G >= ((4*(RCLK_PERIOD_G/WCLK_PERIOD_G))-6))
      report "FULL_THRES_G must be >= ((4*(RCLK_PERIOD_G/WCLK_PERIOD_G))-6)"
      severity failure;

   -- EMPTY_THRES_G lower range check
   assert (EMPTY_THRES_G >= ((4*(RCLK_PERIOD_G/WCLK_PERIOD_G))-6))
      report "EMPTY_THRES_G must be >= ((4*(RCLK_PERIOD_G/WCLK_PERIOD_G))-6)"
      severity failure;

   -- FULL_THRES_G upper range check
   assert (FULL_THRES_G <= ((2**ADDR_WIDTH_G)- 5))
      report "FULL_THRES_G must be <= ((2**ADDR_WIDTH_G)- 5)"
      severity failure;

   -- EMPTY_THRES_G upper range check
   assert (EMPTY_THRES_G <= ((2**ADDR_WIDTH_G)- 7))
      report "EMPTY_THRES_G must be <= ((2**ADDR_WIDTH_G)- 7)"
      severity failure;

end FifoAsyncBuiltIn;

architecture mapping of FifoAsyncBuiltIn is
   
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
         return "???Kb";                --generate error in Xilinx marco
      end if;
   end;

   constant FIFO_LENGTH_C         : integer    := ((2**ADDR_WIDTH_G)- 1);
   constant ALMOST_FULL_OFFSET_C  : bit_vector := to_bitvector(conv_std_logic_vector((FIFO_LENGTH_C-FULL_THRES_G), 16));
   constant ALMOST_EMPTY_OFFSET_C : bit_vector := to_bitvector(conv_std_logic_vector(EMPTY_THRES_G, 16));
   constant FIFO_SIZE_C           : string     := GetFifoType(DATA_WIDTH_G, ADDR_WIDTH_G);

   signal wrAddrPntr,
      rdAddrPntr : slv(ADDR_WIDTH_G-1 downto 0) := (others => '0');

   signal buildInFull,
      buildInEmpty,
      progEmpty,
      progFull,
      WRERR,
      RDERR,
      fifoRst,
      rstFull : sl := '0';
   
begin
   RstSync_FIFO : entity work.RstSync
      generic map (
         TPD_G           => TPD_G,
         RELEASE_DELAY_G => 6)   
      port map (
         clk      => wr_clk,
         asyncRst => rst,
         syncRst  => fifoRst); 


   RstSync_FULL : entity work.RstSync
      generic map (
         TPD_G           => TPD_G,
         RELEASE_DELAY_G => 8)   
      port map (
         clk      => wr_clk,
         asyncRst => rst,
         syncRst  => rstFull);           

   FIFO_DUALCLOCK_MACRO_inst : FIFO_DUALCLOCK_MACRO
      generic map (
         DEVICE                  => XIL_DEVICE_G,  -- Target Device: "VIRTEX5", "VIRTEX6", "7SERIES"
         ALMOST_FULL_OFFSET      => ALMOST_FULL_OFFSET_C,  -- Sets almost full threshold
         ALMOST_EMPTY_OFFSET     => ALMOST_EMPTY_OFFSET_C,  -- Sets the almost empty threshold
         DATA_WIDTH              => DATA_WIDTH_G,  -- Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
         FIFO_SIZE               => FIFO_SIZE_C,  -- Target BRAM, "18Kb" or "36Kb"
         FIRST_WORD_FALL_THROUGH => FWFT_EN_G)  -- Sets the FIFO FWFT to TRUE or FALSE
      port map (
         RST         => fifoRst,      -- 1-bit input reset
         WRCLK       => wr_clk,         -- 1-bit input write clock
         WREN        => wr_en,          -- 1-bit input write enable
         DI          => din,  -- Input data, width defined by DATA_WIDTH parameter
         WRCOUNT     => rdAddrPntr,     -- Output write address pointer
         WRERR       => open,           -- 1-bit output write error
         ALMOSTFULL  => progFull,       -- 1-bit output almost full
         FULL        => buildInFull,    -- 1-bit output full
         RDCLK       => rd_clk,         -- 1-bit input read clock
         RDEN        => rd_en,          -- 1-bit input read enable
         DO          => dout,  -- Output data, width defined by DATA_WIDTH parameter
         RDCOUNT     => wrAddrPntr,     -- Output read address pointer
         RDERR       => underflow,      -- 1-bit output read error
         ALMOSTEMPTY => progEmpty,      -- 1-bit output almost empty
         EMPTY       => buildInEmpty);  -- 1-bit output empty

   -- Full signals
   full      <= buildInFull or rstFull;
   not_full  <= not(buildInFull or rstFull);
   prog_full <= progFull or rstFull;

   process(wr_clk)
   begin
      if rising_edge(wr_clk) then
         if (wr_en = '1') and (rstFull = '0') then
            wr_ack <= not(buildInFull) after TPD_G;
         else
            wr_ack <= '0' after TPD_G;
         end if;
      end if;
   end process;

   process(wr_clk)
   begin
      if rising_edge(wr_clk) then
         if rstFull = '1' then
            overflow <= '0' after TPD_G;
         elsif (wr_en = '1') and (buildInFull = '1') then
            overflow <= '1' after TPD_G;  --latch error strobe
         end if;
      end if;
   end process;

   -- Empty signals
   empty      <= buildInEmpty;
   prog_empty <= progEmpty;
   
   FIFO_Gen : if (FWFT_EN_G = false) generate
      process(buildInEmpty, rd_clk)
      begin
         if rising_edge(rd_clk) then
            if (rd_en = '1') then
               valid <= not(buildInEmpty) after TPD_G;
            else
               valid <= '0' after TPD_G;
            end if;
         end if;
      end process;
   end generate;
   
   FWFT_Gen : if (FWFT_EN_G = true) generate
      valid <= not(buildInEmpty);
   end generate;
  
end architecture mapping;
