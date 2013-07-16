-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : FifoSync.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-10
-- Last update: 2013-07-16
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

entity FifoSync is
   generic (
      TPD_G         : time                       := 1 ns;
      BRAM_EN_G     : boolean                    := true;
      FWFT_EN_G     : boolean                    := false;
      USE_DSP48_G   : string                     := "no";
      ALTERA_RAM_G  : string                     := "M-RAM";
      DATA_WIDTH_G  : integer range 1 to (2**24) := 1;
      ADDR_WIDTH_G  : integer range 4 to 48      := 4;
      FULL_THRES_G  : integer range 1 to (2**24) := 1;
      EMPTY_THRES_G : integer range 0 to (2**24) := 0);
   port (
      rst          : in  sl := '0';
      srst         : in  sl := '0';
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
      full         : out sl;
      empty        : out sl);
begin
   -- FULL_THRES_G upper range check
   assert (FULL_THRES_G <= ((2**ADDR_WIDTH_G)-1))
      report "FULL_THRES_G must be <= ((2**ADDR_WIDTH_G)-1)"
      severity failure;
   -- EMPTY_THRES_G upper range check
   assert (EMPTY_THRES_G <= ((2**ADDR_WIDTH_G)-2))
      report "EMPTY_THRES_G must be <= ((2**ADDR_WIDTH_G)-2)"
      severity failure;
   -- USE_DSP48_G check
   assert ((USE_DSP48_G = "yes") or (USE_DSP48_G = "no") or (USE_DSP48_G = "auto") or (USE_DSP48_G = "automax"))
      report "USE_DSP48_G must be either yes, no, auto, or automax"
      severity failure;
end FifoSync;

architecture rtl of FifoSync is
   constant RAM_DEPTH_C : integer := 2**ADDR_WIDTH_G;

   type RamPortType is
   record
      clk  : sl;
      en   : sl;
      we   : sl;
      addr : slv(ADDR_WIDTH_G-1 downto 0);
      din  : slv(DATA_WIDTH_G-1 downto 0);
      dout : slv(DATA_WIDTH_G-1 downto 0);
   end record;
   signal portA, portB : RamPortType;

   type ReadStatusType is
   record
      --count       : slv(ADDR_WIDTH_G-1 downto 0);
      prog_empty   : sl;
      almost_empty : sl;
      empty        : sl;
   end record;
   constant READ_STATUS_INIT_C : ReadStatusType := (
      --(others => '0'),
      '1',
      '1',
      '1');   
   signal fifoStatus, fwftStatus : ReadStatusType := READ_STATUS_INIT_C;

   signal raddr : slv (ADDR_WIDTH_G-1 downto 0);
   signal waddr : slv (ADDR_WIDTH_G-1 downto 0);
   signal rcnt  : slv (ADDR_WIDTH_G-1 downto 0);
   signal wcnt  : slv (ADDR_WIDTH_G-1 downto 0);

   signal writeAck        : sl;
   signal readAck         : sl;
   signal overflowStatus  : sl;
   signal underflowStatus : sl;
   signal fullStatus      : sl;
   signal readEnable      : sl;
   signal reset           : sl;
   signal ready           : sl;

   -- Attribute for XST
   attribute use_dsp48          : string;
   attribute use_dsp48 of raddr : signal is USE_DSP48_G;
   attribute use_dsp48 of waddr : signal is USE_DSP48_G;
   attribute use_dsp48 of rcnt  : signal is USE_DSP48_G;
   attribute use_dsp48 of wcnt  : signal is USE_DSP48_G;
   
begin
   --write ports
   data_count  <= wcnt;
   full        <= fullStatus;
   wr_ack      <= writeAck;
   overflow    <= overflowStatus;
   prog_full   <= '1' when (wcnt >= FULL_THRES_G)    else '0';
   almost_full <= '1' when (wcnt >= (RAM_DEPTH_C-2)) else '0';
   fullStatus  <= '1' when (wcnt >= (RAM_DEPTH_C-1)) else '0';

   --read ports
   dout      <= portB.dout;
   underflow <= underflowStatus;

   fifoStatus.prog_empty   <= '1' when (rcnt <= EMPTY_THRES_G) else '0';
   fifoStatus.almost_empty <= '1' when (rcnt <= 1)             else '0';
   fifoStatus.empty        <= '1' when (rcnt <= 0)             else '0';

   FIFO_Gen : if (FWFT_EN_G = false) generate
      readEnable   <= rd_en;
      valid        <= readAck;
      prog_empty   <= fifoStatus.prog_empty;
      almost_empty <= fifoStatus.almost_empty;
      empty        <= fifoStatus.empty;
   end generate;

   FWFT_Gen : if (FWFT_EN_G = true) generate
      readEnable   <= (rd_en or fwftStatus.empty) and not(fifoStatus.empty);
      valid        <= not(fwftStatus.empty);
      prog_empty   <= fwftStatus.prog_empty;
      almost_empty <= fwftStatus.almost_empty;
      empty        <= fwftStatus.empty;
      process (clk, rst) is
      begin
         --asychronous reset
         if rst = '1' then
            fwftStatus <= READ_STATUS_INIT_C after TPD_G;
         elsif rising_edge(clk) then
            --sychronous reset
            if srst = '1'then
               fwftStatus <= READ_STATUS_INIT_C after TPD_G;
            else
               fwftStatus.prog_empty   <= fifoStatus.prog_empty                            after TPD_G;
               fwftStatus.almost_empty <= fifoStatus.almost_empty                          after TPD_G;
               fwftStatus.empty        <= (rd_en or fwftStatus.empty) and fifoStatus.empty after TPD_G;
            end if;
         end if;
      end process;
   end generate;

   process (clk, rst) is
   begin
      --asychronous reset
      if rst = '1' then
         writeAck        <= '0'             after TPD_G;
         readAck         <= '0'             after TPD_G;
         waddr           <= (others => '0') after TPD_G;
         raddr           <= (others => '0') after TPD_G;
         rcnt            <= (others => '0') after TPD_G;
         wcnt            <= (others => '1') after TPD_G;
         overflowStatus  <= '0'             after TPD_G;
         underflowStatus <= '0'             after TPD_G;
         ready           <= '0'             after TPD_G;
      elsif rising_edge(clk) then
         writeAck <= '0' after TPD_G;
         readAck  <= '0' after TPD_G;
         --sychronous reset
         if srst = '1'then
            waddr           <= (others => '0') after TPD_G;
            raddr           <= (others => '0') after TPD_G;
            rcnt            <= (others => '0') after TPD_G;
            wcnt            <= (others => '1') after TPD_G;
            overflowStatus  <= '0'             after TPD_G;
            underflowStatus <= '0'             after TPD_G;
            ready           <= '0'             after TPD_G;
         else
            --check if this is first cycle after reset
            if ready = '0' then
               ready <= '1'             after TPD_G;
               wcnt  <= (others => '0') after TPD_G;
            end if;

            --check for write operation
            if wr_en = '1' then
               if fullStatus = '0' then
                  --increment the write address pointer
                  waddr    <= waddr + 1 after TPD_G;
                  writeAck <= '1'       after TPD_G;
               else
                  overflowStatus <= '1' after TPD_G;
               end if;
            end if;

            --check for read operation
            if readEnable = '1' then
               if fifoStatus.empty = '0' then
                  --increment the read address pointer
                  raddr   <= raddr + 1 after TPD_G;
                  readAck <= '1'       after TPD_G;
               else
                  underflowStatus <= '1' after TPD_G;
               end if;
            end if;

            --increment the FIFO counter
            if (readEnable = '1') and (wr_en = '0') and (fifoStatus.empty = '0') then
               rcnt <= rcnt - 1 after TPD_G;
               wcnt <= rcnt - 1 after TPD_G;
            elsif (readEnable = '0') and (wr_en = '1') and (fullStatus = '0') then
               rcnt <= rcnt + 1 after TPD_G;
               wcnt <= rcnt + 1 after TPD_G;
            end if;
            
         end if;
      end if;
   end process;

   -- RAM Port A Mapping
   portA.clk  <= clk;
   portA.en   <= '1';
   portA.we   <= wr_en and not(fullStatus);
   portA.addr <= waddr;
   portA.din  <= din;

   -- RAM Port B Mapping
   portB.clk  <= clk;
   portB.en   <= readEnable and not(fifoStatus.empty);
   portB.we   <= '0';
   portB.addr <= raddr;
   portB.din  <= (others => '0');

   SimpleDualPortRam_Inst : entity work.SimpleDualPortRam
      generic map(
         TPD_G        => TPD_G,
         BRAM_EN_G    => BRAM_EN_G,
         ALTERA_RAM_G => ALTERA_RAM_G,
         DATA_WIDTH_G => DATA_WIDTH_G,
         ADDR_WIDTH_G => ADDR_WIDTH_G)
      port map (
         -- Port A
         clka  => portA.clk,
         ena   => portA.en,
         wea   => portA.we,
         addra => portA.addr,
         dina  => portA.din,
         -- Port B
         clkb  => portB.clk,
         enb   => portB.en,
         addrb => portB.addr,
         doutb => portB.dout);     

end rtl;
