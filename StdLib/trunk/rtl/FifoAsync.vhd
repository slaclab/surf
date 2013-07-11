-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : FifoAsync.vhd
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

entity FifoAsync is
   generic (
      TPD_G         : time                       := 1 ns;
      BRAM_EN_G     : boolean                    := true;
      SYNC_STAGES_G : integer range 2 to (2**24) := 2;
      DATA_WIDTH_G  : integer range 1 to (2**24) := 18;
      ADDR_WIDTH_G  : integer range 4 to (2**24) := 4;
      FULL_THRES_G  : integer range 3 to (2**24) := 3;
      EMPTY_THRES_G : integer range 2 to (2**24) := 2);
   port (
      -- Asynchronous Reset
      rst           : in  sl;
      --Write Ports (wr_clk domain)
      wr_clk        : in  sl;
      wr_en         : in  sl;
      din           : in  slv(DATA_WIDTH_G-1 downto 0);
      wr_data_count : out slv(ADDR_WIDTH_G-1 downto 0);
      wr_ack        : out sl;
      overflow      : out sl;
      prog_full     : out sl;
      almost_full   : out sl;
      full          : out sl;
      --Read Ports (rd_clk domain)
      rd_clk        : in  sl;
      rd_en         : in  sl;
      dout          : out slv(DATA_WIDTH_G-1 downto 0);
      rd_data_count : out slv(ADDR_WIDTH_G-1 downto 0);
      valid         : out sl;
      underflow     : out sl;
      prog_empty    : out sl;
      almost_empty  : out sl;
      empty         : out sl);
begin
   -- FULL_THRES_G upper range check
   assert (FULL_THRES_G <= ((2**ADDR_WIDTH_G)-2))
      report "FULL_THRES_G must be <= ((2**ADDR_WIDTH_G)-2)"
      severity failure;
   -- EMPTY_THRES_G upper range check
   assert (EMPTY_THRES_G <= ((2**ADDR_WIDTH_G)-3))
      report "EMPTY_THRES_G must be <= ((2**ADDR_WIDTH_G)-3)"
      severity failure;
end FifoAsync;

architecture rtl of FifoAsync is
   constant RAM_DEPTH_C : integer := 2**ADDR_WIDTH_G;

   type RegType is record
      waddr   : slv(ADDR_WIDTH_G-1 downto 0);
      raddr   : slv(ADDR_WIDTH_G-1 downto 0);
      advance : slv(ADDR_WIDTH_G-1 downto 0);
      cnt     : slv(ADDR_WIDTH_G-1 downto 0);
      Ack     : sl;
      error   : sl;
   end record;
   
   constant REG_INIT_C : RegType := (
      (others => '0'),
      (others => '0'),
      conv_std_logic_vector(1, ADDR_WIDTH_G),
      (others => '0'),
      '0',
      '0'); 

   signal rdReg, wrReg : RegType := REG_INIT_C;
   signal fullStatus   : sl;
   signal emptyStatus  : sl;


   constant GRAY_INIT_C  : slv(ADDR_WIDTH_G-1 downto 0) := (others => '0');
   signal   rdReg_rdGray : slv(ADDR_WIDTH_G-1 downto 0) := GRAY_INIT_C;
   signal   rdReg_wrGray : slv(ADDR_WIDTH_G-1 downto 0) := GRAY_INIT_C;
   signal   wrReg_rdGray : slv(ADDR_WIDTH_G-1 downto 0) := GRAY_INIT_C;
   signal   wrReg_wrGray : slv(ADDR_WIDTH_G-1 downto 0) := GRAY_INIT_C;

   type RamPortType is record
      clk  : sl;
      en   : sl;
      we   : sl;
      addr : slv(ADDR_WIDTH_G-1 downto 0);
      din  : slv(DATA_WIDTH_G-1 downto 0);
      dout : slv(DATA_WIDTH_G-1 downto 0);
   end record;

   signal portA, portB : RamPortType;
   
begin
   -------------------------------
   -- rd_clk domain
   -------------------------------
   dout          <= portB.dout;
   rd_data_count <= rdReg.cnt;
   empty         <= emptyStatus;
   valid         <= rdReg.Ack;
   underflow     <= rdReg.error;

   prog_empty   <= '1' when (rdReg.cnt <= EMPTY_THRES_G) else '0';
   almost_empty <= '1' when (rdReg.cnt <= 1)             else '0';
   emptyStatus  <= '1' when (rdReg.cnt <= 0)             else '0';

   SYNC_WriteToRead : entity work.SynchronizerVector
      generic map (
         STAGES_G => SYNC_STAGES_G,
         WIDTH_G  => ADDR_WIDTH_G,
         INIT_G   => GRAY_INIT_C)
      port map (
         aRst    => rst,
         clk     => rd_clk,
         dataIn  => wrReg_wrGray,
         dataOut => rdReg_wrGray);   

   READ_SEQUENCE : process (rd_clk, rst) is
   begin
      if rst = '1' then
         rdReg <= REG_INIT_C after TPD_G;
      elsif rising_edge(rd_clk) then
         rdReg.Ack <= '0' after TPD_G;

         --Decode the Gray code pointer
         rdReg.waddr <= grayDecode(rdReg_wrGray) after TPD_G;

         --check for read operation
         if rd_en = '1' then
            if emptyStatus = '0' then
               --increment the read address pointer
               rdReg.raddr   <= rdReg.raddr + 1             after TPD_G;
               rdReg.advance <= rdReg.advance + 1           after TPD_G;
               rdReg.Ack     <= '1'                         after TPD_G;
               --Calculate the count
               rdReg.cnt     <= rdReg.waddr - rdReg.advance after TPD_G;
            else
               rdReg.error <= '1' after TPD_G;
            end if;
         else
            --Calculate the count
            rdReg.cnt <= rdReg.waddr - rdReg.raddr after TPD_G;
         end if;

         --Encode the Gray code pointer
         rdReg_rdGray <= grayEncode(rdReg.raddr) after TPD_G;
         
      end if;
   end process READ_SEQUENCE;

   -------------------------------
   -- wr_clk domain
   -------------------------------     
   wr_data_count <= wrReg.cnt;
   full          <= fullStatus;
   wr_ack        <= wrReg.Ack;
   overflow      <= wrReg.error;
   prog_full     <= '1' when (wrReg.cnt >= EMPTY_THRES_G)   else '0';
   almost_full   <= '1' when (wrReg.cnt >= (RAM_DEPTH_C-2)) else '0';
   fullStatus    <= '1' when (wrReg.cnt >= (RAM_DEPTH_C-1)) else '0';

   SYNC_ReadToWrite : entity work.SynchronizerVector
      generic map (
         STAGES_G => SYNC_STAGES_G,
         WIDTH_G  => ADDR_WIDTH_G,
         INIT_G   => GRAY_INIT_C)
      port map (
         aRst    => rst,
         clk     => wr_clk,
         dataIn  => rdReg_rdGray,
         dataOut => wrReg_rdGray);    

   WRITE_SEQUENCE : process (rst, wr_clk) is
   begin
      if rst = '1' then
         wrReg <= REG_INIT_C after TPD_G;
      elsif rising_edge(wr_clk) then
         wrReg.Ack <= '0' after TPD_G;

         --Decode the Gray code pointer
         wrReg.raddr <= grayDecode(wrReg_rdGray) after TPD_G;

         --check for write operation
         if wr_en = '1' then
            if fullStatus = '0' then
               --increment the read address pointer
               wrReg.waddr   <= wrReg.waddr + 1             after TPD_G;
               wrReg.advance <= wrReg.advance + 1           after TPD_G;
               wrReg.Ack     <= '1'                         after TPD_G;
               --Calculate the count
               wrReg.cnt     <= wrReg.advance - wrReg.raddr after TPD_G;
            else
               wrReg.error <= '1' after TPD_G;
            end if;
         else
            --Calculate the count
            wrReg.cnt <= wrReg.waddr - wrReg.raddr after TPD_G;
         end if;

         --Encode the Gray code pointer
         wrReg_wrGray <= grayEncode(wrReg.waddr) after TPD_G;

      end if;
   end process WRITE_SEQUENCE;

   -------------------------------
   -- rd_clk and wr_clk domain
   -------------------------------   

   -- RAM Port A Mapping
   portA.clk  <= wr_clk;
   portA.en   <= '1';
   portA.we   <= wr_en and not(fullStatus);
   portA.addr <= wrReg.waddr;
   portA.din  <= din;

   -- RAM Port B Mapping
   portB.clk  <= rd_clk;
   portB.en   <= rd_en and not(emptyStatus);
   portB.we   <= '0';
   portB.addr <= rdReg.raddr;
   portB.din  <= (others => '0');

   DualPortRam_Inst : entity work.DualPortRam
      generic map (
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

end architecture rtl;
