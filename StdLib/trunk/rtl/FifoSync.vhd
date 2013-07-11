-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : FifoSync.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-10
-- Last update: 2013-07-11
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
      DATA_WIDTH_G  : integer range 1 to (2**24) := 1;
      ADDR_WIDTH_G  : integer range 4 to (2**24) := 4;
      FULL_THRES_G  : integer range 3 to (2**24) := 3;
      EMPTY_THRES_G : integer range 2 to (2**24) := 2);
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
   assert (FULL_THRES_G <= ((2**ADDR_WIDTH_G)-2))
      report "FULL_THRES_G must be <= ((2**ADDR_WIDTH_G)-2)"
      severity failure;
   -- EMPTY_THRES_G upper range check
   assert (EMPTY_THRES_G <= ((2**ADDR_WIDTH_G)-3))
      report "EMPTY_THRES_G must be <= ((2**ADDR_WIDTH_G)-3)"
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
   signal raddr        : slv (ADDR_WIDTH_G-1 downto 0);
   signal waddr        : slv (ADDR_WIDTH_G-1 downto 0);
   signal cnt          : slv (ADDR_WIDTH_G-1 downto 0);

   signal writeAck : sl;
   signal readAck  : sl;

   signal overflowStatus  : sl;
   signal underflowStatus : sl;

   signal fullStatus  : sl;
   signal emptyStatus : sl;
   
begin
   
   dout       <= portB.dout;
   data_count <= cnt;

   full  <= fullStatus;
   empty <= emptyStatus;

   wr_ack <= writeAck;
   valid  <= readAck;

   overflow  <= overflowStatus;
   underflow <= underflowStatus;

   prog_full  <= '1' when (cnt >= FULL_THRES_G)  else '0';
   prog_empty <= '1' when (cnt <= EMPTY_THRES_G) else '0';

   almost_full  <= '1' when (cnt >= (RAM_DEPTH_C-2)) else '0';
   almost_empty <= '1' when (cnt <= 1)               else '0';

   fullStatus  <= '1' when (cnt >= (RAM_DEPTH_C-1)) else '0';
   emptyStatus <= '1' when (cnt <= 0)               else '0';

   process (clk, rst) is
   begin
      --asychronous reset
      if rst = '1' then
         writeAck        <= '0'             after TPD_G;
         readAck         <= '0'             after TPD_G;
         waddr           <= (others => '0') after TPD_G;
         raddr           <= (others => '0') after TPD_G;
         cnt             <= (others => '0') after TPD_G;
         overflowStatus  <= '0'             after TPD_G;
         underflowStatus <= '0'             after TPD_G;
      elsif rising_edge(clk) then
         writeAck <= '0' after TPD_G;
         readAck  <= '0' after TPD_G;
         --sychronous reset
         if srst = '1'then
            waddr           <= (others => '0') after TPD_G;
            raddr           <= (others => '0') after TPD_G;
            cnt             <= (others => '0') after TPD_G;
            overflowStatus  <= '0'             after TPD_G;
            underflowStatus <= '0'             after TPD_G;
         else

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
            if rd_en = '1' then
               if emptyStatus = '0' then
                  --increment the read address pointer
                  raddr   <= raddr + 1 after TPD_G;
                  readAck <= '1'       after TPD_G;
               else
                  underflowStatus <= '1' after TPD_G;
               end if;
            end if;

            --increment the FIFO counter
            if (rd_en = '1') and (wr_en = '0') and (emptyStatus = '0') then
               cnt <= cnt - 1 after TPD_G;
            elsif (rd_en = '0') and (wr_en = '1') and (fullStatus = '0') then
               cnt <= cnt + 1 after TPD_G;
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
   portB.en   <= rd_en and not(emptyStatus);
   portB.we   <= '0';
   portB.addr <= raddr;
   portB.din  <= (others => '0');

   DualPortRam_Inst : entity work.DualPortRam
      generic map(
         TPD_G        => TPD_G,
         BRAM_EN_G    => BRAM_EN_G,
         DATA_WIDTH_G => DATA_WIDTH_G,
         ADDR_WIDTH_G => ADDR_WIDTH_G)
      port map (
         -- Port A
         clka  => portA.clk,
         ena   => portA.en,
         wea   => portA.we,
         addra => portA.addr,
         dina  => portA.din,
         douta => portA.dout,
         -- Port B
         clkb  => portB.clk,
         enb   => portB.en,
         web   => portB.we,
         addrb => portB.addr,
         dinb  => portB.din,
         doutb => portB.dout);     

end rtl;
