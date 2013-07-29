-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : FifoSyncBuiltIn.vhd
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

entity FifoSyncBuiltIn is
   generic (
      TPD_G         : time                    := 1 ns;
      XIL_DEVICE_G  : string                  := "7SERIES";  -- Target Device: "VIRTEX5", "VIRTEX6", "7SERIES"   
      USE_DSP48_G   : string                  := "no";
      FWFT_EN_G     : boolean                 := false;
      DATA_WIDTH_G  : integer range 1 to 72   := 18;
      ADDR_WIDTH_G  : integer range 9 to 13   := 10;
      FULL_THRES_G  : integer range 1 to 8190 := 1;
      EMPTY_THRES_G : integer range 1 to 8190 := 1);
   port (
      rst          : in  sl := '0';     -- Asynchronous Reset
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
   -- FULL_THRES_G upper range check
   assert (FULL_THRES_G <= ((2**ADDR_WIDTH_G)-2))
      report "FULL_THRES_G must be <= ((2**ADDR_WIDTH_G)-2)"
      severity failure;
   -- EMPTY_THRES_G upper range check
   assert (EMPTY_THRES_G <= ((2**ADDR_WIDTH_G)-2))
      report "EMPTY_THRES_G must be <= ((2**ADDR_WIDTH_G)-2)"
      severity failure;
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
         return "???Kb";                --generate error in Xilinx marco
      end if;
   end;

   constant FIFO_LENGTH_C         : integer    := ((2**ADDR_WIDTH_G)- 1);
   constant ALMOST_FULL_OFFSET_C  : bit_vector := to_bitvector(conv_std_logic_vector((FIFO_LENGTH_C-FULL_THRES_G), 16));
   constant ALMOST_EMPTY_OFFSET_C : bit_vector := to_bitvector(conv_std_logic_vector(EMPTY_THRES_G, 16));
   constant FIFO_SIZE_C           : string     := GetFifoType(DATA_WIDTH_G, ADDR_WIDTH_G);
   
   type ReadStatusType is
   record
      prog_empty   : sl;
      almost_empty : sl;
      empty        : sl;
   end record;
   constant READ_STATUS_INIT_C : ReadStatusType := (
      '1',
      '1',
      '1');   
   signal fifoStatus, fwftStatus : ReadStatusType := READ_STATUS_INIT_C;

   signal wrAddrPntr,
      rdAddrPntr,
      cnt : slv(ADDR_WIDTH_G-1 downto 0) := (others => '0');
   signal buildInFull,
      buildInEmpty,
      progEmpty,
      progFull,
      readEnable,
      rstFull,
      fifoRst : sl := '0';

   -- Attribute for XST
   attribute use_dsp48        : string;
   attribute use_dsp48 of cnt : signal is USE_DSP48_G;
   
begin
   RstSync_FIFO : entity work.RstSync
      generic map (
         TPD_G           => TPD_G,
         RELEASE_DELAY_G => 6)   
      port map (
         clk      => clk,
         asyncRst => rst,
         syncRst  => fifoRst); 

   RstSync_FULL : entity work.RstSync
      generic map (
         TPD_G           => TPD_G,
         RELEASE_DELAY_G => 8)   
      port map (
         clk      => clk,
         asyncRst => rst,
         syncRst  => rstFull);  

   FIFO_SYNC_MACRO_Inst : FIFO_SYNC_MACRO
      generic map (
         DO_REG              => 0,  --DO_REG must be set to 0 for flags and data to follow a standard synchronous FIFO operation
         DEVICE              => XIL_DEVICE_G,  -- Target Device: "VIRTEX5", "VIRTEX6", "7SERIES"
         ALMOST_FULL_OFFSET  => ALMOST_FULL_OFFSET_C,  -- Sets almost full threshold
         ALMOST_EMPTY_OFFSET => ALMOST_EMPTY_OFFSET_C,  -- Sets the almost empty threshold
         DATA_WIDTH          => DATA_WIDTH_G,  -- Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
         FIFO_SIZE           => FIFO_SIZE_C)   -- Target BRAM, "18Kb" or "36Kb"
      port map (
         RST         => fifoRst,        -- 1-bit input reset
         CLK         => clk,            -- 1-bit input clock
         WREN        => wr_en,          -- 1-bit input write enable
         RDEN        => readEnable,     -- 1-bit input read enable
         DI          => din,  -- Input data, width defined by DATA_WIDTH parameter
         DO          => dout,  -- Output data, width defined by DATA_WIDTH parameter
         RDCOUNT     => rdAddrPntr,  -- Output read count, width determined by FIFO depth
         WRCOUNT     => wrAddrPntr,  -- Output write count, width determined by FIFO depth
         WRERR       => open,           -- 1-bit output write error
         RDERR       => underflow,      -- 1-bit output read error
         ALMOSTFULL  => progFull,       -- 1-bit output almost full
         ALMOSTEMPTY => progEmpty,      -- 1-bit output almost empty
         FULL        => buildInFull,    -- 1-bit output full
         EMPTY       => buildInEmpty);  -- 1-bit output empty  

   -- calculate data count
   cnt        <= wrAddrPntr - rdAddrPntr;
   data_count <= cnt;

   --write signals
   full        <= buildInFull or rstFull;
   not_full    <= not(buildInFull or rstFull);
   prog_full   <= progFull or rstFull;
   almost_full <= '1' when (cnt >= (FIFO_LENGTH_C-1)) else rstFull;

   process(clk)
   begin
      if rising_edge(clk) then
         if wr_en = '1' then
            wr_ack <= not(buildInFull) after TPD_G;
         else
            wr_ack <= '0' after TPD_G;
         end if;
      end if;
   end process;
   
   process(clk)
   begin
      if rising_edge(clk) then
         if rstFull = '1' then
            overflow <= '0' after TPD_G;
         elsif (wr_en = '1') and (buildInFull = '1') then
            overflow <= '1' after TPD_G;  --latch error strobe
         end if;
      end if;
   end process;   

   --read signals   
   fifoStatus.prog_empty   <= progEmpty;
   fifoStatus.almost_empty <= '1' when (cnt <= 1) else '0';
   fifoStatus.empty        <= buildInEmpty;

   FIFO_Gen : if (FWFT_EN_G = false) generate
      readEnable   <= rd_en;
      prog_empty   <= fifoStatus.prog_empty;
      almost_empty <= fifoStatus.almost_empty;
      empty        <= fifoStatus.empty;

      process(clk)
      begin
         if rising_edge(clk) then
            if rd_en = '1' then
               valid <= not(buildInEmpty) after TPD_G;
            else
               valid <= '0' after TPD_G;
            end if;
         end if;
      end process;
      
   end generate;

   FWFT_Gen : if (FWFT_EN_G = true) generate
      readEnable   <= (rd_en or fwftStatus.empty) and not(fifoStatus.empty);
      valid        <= not(fwftStatus.empty);
      prog_empty   <= fwftStatus.prog_empty;
      almost_empty <= fwftStatus.almost_empty;
      empty        <= fwftStatus.empty;
      process (clk) is
      begin
         --asychronous reset
         if rising_edge(clk) then
            if fifoRst = '1'then
               fwftStatus <= READ_STATUS_INIT_C after TPD_G;
            else
               fwftStatus.prog_empty   <= fifoStatus.prog_empty                            after TPD_G;
               fwftStatus.almost_empty <= fifoStatus.almost_empty                          after TPD_G;
               fwftStatus.empty        <= (rd_en or fwftStatus.empty) and fifoStatus.empty after TPD_G;
            end if;
         end if;
      end process;
   end generate;

end architecture mapping;
