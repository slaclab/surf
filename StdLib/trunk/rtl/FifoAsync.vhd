-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : FifoAsync.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-10
-- Last update: 2013-07-17
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
      FWFT_EN_G     : boolean                    := false;
      USE_DSP48_G   : string                     := "no";
      ALTERA_RAM_G  : string                     := "M-RAM";
      SYNC_STAGES_G : integer range 2 to (2**24) := 2;
      DATA_WIDTH_G  : integer range 1 to (2**24) := 18;
      ADDR_WIDTH_G  : integer range 2 to 48      := 4;
      FULL_THRES_G  : integer range 1 to (2**24) := 1;
      EMPTY_THRES_G : integer range 0 to (2**24) := 0);
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
      rdy     : sl;
      done    : sl;
   end record;
   
   constant READ_INIT_C : RegType := (
      (others => '0'),
      (others => '0'),
      conv_std_logic_vector(1, ADDR_WIDTH_G),
      (others => '0'),                  --empty during reset
      '0',
      '0',
      '0',
      '0');       

   constant WRITE_INIT_C : RegType := (
      (others => '0'),
      (others => '0'),
      conv_std_logic_vector(1, ADDR_WIDTH_G),
      (others => '1'),                  --full during reset
      '0',
      '0',
      '0',
      '0');       

   signal rdReg : RegType := READ_INIT_C;
   signal wrReg : RegType := WRITE_INIT_C;

   signal fullStatus : sl;
   signal readEnable : sl;

   signal readRst  : sl;
   signal writeRst : sl;

   signal rdReg_rdy : sl;
   signal wrReg_rdy : sl;


   constant SYNC_INIT_C  : slv(SYNC_STAGES_G-1 downto 0) := (others => '0');
   constant GRAY_INIT_C  : slv(ADDR_WIDTH_G-1 downto 0)  := (others => '0');
   signal   rdReg_rdGray : slv(ADDR_WIDTH_G-1 downto 0)  := GRAY_INIT_C;
   signal   rdReg_wrGray : slv(ADDR_WIDTH_G-1 downto 0)  := GRAY_INIT_C;
   signal   wrReg_rdGray : slv(ADDR_WIDTH_G-1 downto 0)  := GRAY_INIT_C;
   signal   wrReg_wrGray : slv(ADDR_WIDTH_G-1 downto 0)  := GRAY_INIT_C;

   type RamPortType is record
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
      count        : slv(ADDR_WIDTH_G-1 downto 0);
      prog_empty   : sl;
      almost_empty : sl;
      empty        : sl;
   end record;
   constant READ_STATUS_INIT_C : ReadStatusType := (
      (others => '0'),
      '1',
      '1',
      '1');   
   signal fifoStatus, fwftStatus : ReadStatusType := READ_STATUS_INIT_C;

   -- Attribute for XST
   attribute use_dsp48          : string;
   attribute use_dsp48 of rdReg : signal is USE_DSP48_G;
   attribute use_dsp48 of wrReg : signal is USE_DSP48_G;
   
begin
   -------------------------------
   -- rd_clk domain
   -------------------------------
   READ_RstSync : entity work.RstSync
      generic map (
         TPD_G           => TPD_G,
         RELEASE_DELAY_G => SYNC_STAGES_G)   
      port map (
         clk      => rd_clk,
         asyncRst => rst,
         syncRst  => readRst); 

   dout      <= portB.dout;
   underflow <= rdReg.error;

   fifoStatus.count        <= rdReg.cnt;
   fifoStatus.prog_empty   <= '1' when (rdReg.cnt <= EMPTY_THRES_G) else '0';
   fifoStatus.almost_empty <= '1' when (rdReg.cnt <= 1)             else '0';
   fifoStatus.empty        <= '1' when (rdReg.cnt <= 0)             else '0';

   FIFO_Gen : if (FWFT_EN_G = false) generate
      readEnable    <= rd_en;
      valid         <= rdReg.Ack;
      prog_empty    <= fifoStatus.prog_empty;
      almost_empty  <= fifoStatus.almost_empty;
      empty         <= fifoStatus.empty;
      rd_data_count <= fifoStatus.count;
   end generate;

   FWFT_Gen : if (FWFT_EN_G = true) generate
      readEnable    <= (rd_en or fwftStatus.empty) and not(fifoStatus.empty);
      valid         <= not(fwftStatus.empty);
      prog_empty    <= fwftStatus.prog_empty;
      almost_empty  <= fwftStatus.almost_empty;
      empty         <= fwftStatus.empty;
      rd_data_count <= fwftStatus.count;
      process (rd_clk, readRst) is
      begin
         --asychronous reset
         if readRst = '1' then
            fwftStatus <= READ_STATUS_INIT_C after TPD_G;
         elsif rising_edge(rd_clk) then
            fwftStatus.prog_empty   <= fifoStatus.prog_empty                            after TPD_G;
            fwftStatus.almost_empty <= fifoStatus.almost_empty                          after TPD_G;
            fwftStatus.empty        <= (rd_en or fwftStatus.empty) and fifoStatus.empty after TPD_G;
            fwftStatus.count        <= fifoStatus.count                                 after TPD_G;
         end if;
      end process;
   end generate;

   SynchronizerVector_0 : entity work.SynchronizerVector
      generic map (
         TPD_G    => TPD_G,
         STAGES_G => SYNC_STAGES_G,
         WIDTH_G  => ADDR_WIDTH_G,
         INIT_G   => GRAY_INIT_C)
      port map (
         aRst    => readRst,
         clk     => rd_clk,
         dataIn  => wrReg_wrGray,
         dataOut => rdReg_wrGray);   

   Synchronizer_0 : entity work.Synchronizer
      generic map (
         TPD_G    => TPD_G,
         STAGES_G => SYNC_STAGES_G,
         INIT_G   => SYNC_INIT_C)
      port map (
         clk     => rd_clk,
         aRst    => readRst,
         dataIn  => wrReg.done,
         dataOut => rdReg_rdy);         

   READ_SEQUENCE : process (rd_clk, readRst) is
   begin
      if readRst = '1' then
         rdReg <= READ_INIT_C after TPD_G;
      elsif rising_edge(rd_clk) then
         rdReg.done <= '1' after TPD_G;
         rdReg.Ack  <= '0' after TPD_G;
         if rdReg_rdy = '1' then

            --Decode the Gray code pointer
            rdReg.waddr <= grayDecode(rdReg_wrGray) after TPD_G;

            --check for read operation
            if readEnable = '1' then
               if fifoStatus.empty = '0' then
                  --increment the read address pointer
                  rdReg.raddr   <= rdReg.raddr + 1             after TPD_G;
                  rdReg.advance <= rdReg.advance + 1           after TPD_G;
                  rdReg.Ack     <= '1'                         after TPD_G;
                  --Calculate the count
                  rdReg.cnt     <= rdReg.waddr - rdReg.advance after TPD_G;
               else
                  --Calculate the count
                  rdReg.cnt   <= rdReg.waddr - rdReg.raddr after TPD_G;
                  rdReg.error <= '1'                       after TPD_G;
               end if;
            else
               --Calculate the count
               rdReg.cnt <= rdReg.waddr - rdReg.raddr after TPD_G;
            end if;

            --Encode the Gray code pointer
            rdReg_rdGray <= grayEncode(rdReg.raddr) after TPD_G;
            
         end if;
      end if;
   end process READ_SEQUENCE;

   -------------------------------
   -- wr_clk domain
   -------------------------------   
   WRITE_RstSync : entity work.RstSync
      generic map (
         TPD_G           => TPD_G,
         RELEASE_DELAY_G => SYNC_STAGES_G)   
      port map (
         clk      => wr_clk,
         asyncRst => rst,
         syncRst  => writeRst); 

   wr_data_count <= wrReg.cnt;
   full          <= fullStatus;
   wr_ack        <= wrReg.Ack;
   overflow      <= wrReg.error;
   prog_full     <= '1' when (wrReg.cnt >= EMPTY_THRES_G)   else '0';
   almost_full   <= '1' when (wrReg.cnt >= (RAM_DEPTH_C-2)) else '0';
   fullStatus    <= '1' when (wrReg.cnt >= (RAM_DEPTH_C-1)) else '0';

   SynchronizerVector_1 : entity work.SynchronizerVector
      generic map (
         TPD_G    => TPD_G,
         STAGES_G => SYNC_STAGES_G,
         WIDTH_G  => ADDR_WIDTH_G,
         INIT_G   => GRAY_INIT_C)
      port map (
         aRst    => writeRst,
         clk     => wr_clk,
         dataIn  => rdReg_rdGray,
         dataOut => wrReg_rdGray);

   Synchronizer_1 : entity work.Synchronizer
      generic map (
         TPD_G    => TPD_G,
         STAGES_G => SYNC_STAGES_G,
         INIT_G   => SYNC_INIT_C)
      port map (
         clk     => wr_clk,
         aRst    => writeRst,
         dataIn  => rdReg.done,
         dataOut => wrReg_rdy);           

   WRITE_SEQUENCE : process (wr_clk, writeRst) is
   begin
      if writeRst = '1' then
         wrReg <= WRITE_INIT_C after TPD_G;
      elsif rising_edge(wr_clk) then
         wrReg.done <= '1' after TPD_G;
         wrReg.Ack  <= '0' after TPD_G;
         if wrReg_rdy = '1' then
            if wrReg.rdy = '0' then
               wrReg.rdy <= '1';
               wrReg.cnt <= (others => '0');
            else

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
                     wrReg.error <= '1'                       after TPD_G;
                     --Calculate the count
                     wrReg.cnt   <= wrReg.waddr - wrReg.raddr after TPD_G;
                  end if;
               else
                  --Calculate the count
                  wrReg.cnt <= wrReg.waddr - wrReg.raddr after TPD_G;
               end if;

               --Encode the Gray code pointer
               wrReg_wrGray <= grayEncode(wrReg.waddr) after TPD_G;
               
            end if;
         end if;
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
   portB.en   <= readEnable and not(fifoStatus.empty);
   portB.we   <= '0';
   portB.addr <= rdReg.raddr;
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

end architecture rtl;
