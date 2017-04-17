-------------------------------------------------------------------------------
-- File       : FifoSync.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-10
-- Last update: 2016-10-27
-------------------------------------------------------------------------------
-- Description: SYNC FIFO module
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

use work.StdRtlPkg.all;

entity FifoSync is
   generic (
      TPD_G          : time                       := 1 ns;
      RST_POLARITY_G : sl                         := '1';  -- '1' for active high rst, '0' for active low
      RST_ASYNC_G    : boolean                    := false;
      BRAM_EN_G      : boolean                    := true;
      BYP_RAM_G      : boolean                    := false;
      FWFT_EN_G      : boolean                    := false;
      USE_DSP48_G    : string                     := "no";
      ALTERA_SYN_G   : boolean                    := false;
      ALTERA_RAM_G   : string                     := "M9K";
      PIPE_STAGES_G  : natural range 0 to 16      := 0;
      DATA_WIDTH_G   : integer range 1 to (2**24) := 16;
      ADDR_WIDTH_G   : integer range 4 to 48      := 4;
      INIT_G         : slv                        := "0";
      FULL_THRES_G   : integer range 1 to (2**24) := 1;
      EMPTY_THRES_G  : integer range 1 to (2**24) := 1);
   port (
      rst          : in  sl := not RST_POLARITY_G;
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
      not_full     : out sl;
      empty        : out sl);
end FifoSync;

architecture rtl of FifoSync is
   constant INIT_C      : slv(DATA_WIDTH_G-1 downto 0) := ite(INIT_G = "0", slvZero(DATA_WIDTH_G), INIT_G);
   constant RAM_DEPTH_C : integer                      := 2**ADDR_WIDTH_G;

   type RamPortType is
   record
      clk  : sl;
      en   : sl;
      rst  : sl;
      we   : sl;
      addr : slv(ADDR_WIDTH_G-1 downto 0);
      din  : slv(DATA_WIDTH_G-1 downto 0);
      dout : slv(DATA_WIDTH_G-1 downto 0);
   end record;
   signal portA, portB : RamPortType;

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

   signal raddr : slv (ADDR_WIDTH_G-1 downto 0);
   signal waddr : slv (ADDR_WIDTH_G-1 downto 0);
   signal cnt   : slv (ADDR_WIDTH_G-1 downto 0);

   signal writeAck        : sl;
   signal readAck         : sl;
   signal overflowStatus  : sl;
   signal underflowStatus : sl;
   signal fullStatus      : sl;
   signal readEnable      : sl;
   signal rstStatus       : sl;

   signal sValid,
      sRdEn : sl;

   -- Attribute for XST
   attribute use_dsp48          : string;
   attribute use_dsp48 of raddr : signal is USE_DSP48_G;
   attribute use_dsp48 of waddr : signal is USE_DSP48_G;
   attribute use_dsp48 of cnt   : signal is USE_DSP48_G;
   
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
   -- INIT_G length check
   assert (INIT_G = "0" or INIT_G'length = DATA_WIDTH_G) report
      "INIT_G must either be ""0"" or the same length as DATA_WIDTH_G" severity failure;

   rstStatus <= rst when(RST_POLARITY_G = '1') else not(rst);

   -- Write ports
   full     <= fullStatus;
   not_full <= not(fullStatus);
   wr_ack   <= writeAck;
   overflow <= overflowStatus;

   process (clk, rst) is
   begin
      -- Asynchronous reset
      if (RST_ASYNC_G and rst = RST_POLARITY_G) then
         data_count  <= (others => '1') after TPD_G;
         prog_full   <= '1'             after TPD_G;
         almost_full <= '1'             after TPD_G;
         fullStatus  <= '1'             after TPD_G;
      elsif rising_edge(clk) then
         -- Synchronous reset
         if (RST_ASYNC_G = false and rst = RST_POLARITY_G) then
            data_count  <= (others => '1') after TPD_G;
            prog_full   <= '1'             after TPD_G;
            almost_full <= '1'             after TPD_G;
            fullStatus  <= '1'             after TPD_G;
         else
            data_count <= cnt after TPD_G;
            -- prog_full
            if (cnt > FULL_THRES_G) then
               prog_full <= '1' after TPD_G;
            else
               prog_full <= '0' after TPD_G;
            end if;
            -- almost_full
            if (cnt = (RAM_DEPTH_C-1)) or (cnt = (RAM_DEPTH_C-2)) or (cnt = (RAM_DEPTH_C-3)) then
               almost_full <= '1' after TPD_G;
            else
               almost_full <= '0' after TPD_G;
            end if;
            -- fullStatus
            if (cnt = (RAM_DEPTH_C-1)) or (cnt = (RAM_DEPTH_C-2)) then
               fullStatus <= '1' after TPD_G;
            else
               fullStatus <= '0' after TPD_G;
            end if;
         end if;
      end if;
   end process;

   -- Read ports
   underflow <= underflowStatus;

   fifoStatus.prog_empty   <= '1' when (cnt < EMPTY_THRES_G) else rstStatus;
   fifoStatus.almost_empty <= '1' when (cnt = 1)             else fifoStatus.empty;
   fifoStatus.empty        <= '1' when (cnt = 0)             else rstStatus;

   FIFO_Gen : if (FWFT_EN_G = false) generate
      readEnable   <= rd_en;
      valid        <= readAck;
      prog_empty   <= fifoStatus.prog_empty;
      almost_empty <= fifoStatus.almost_empty;
      empty        <= fifoStatus.empty;
      dout         <= portB.dout;
   end generate;

   FWFT_Gen : if (FWFT_EN_G = true) generate
      
      FifoOutputPipeline_Inst : entity work.FifoOutputPipeline
         generic map (
            TPD_G          => TPD_G,
            RST_POLARITY_G => RST_POLARITY_G,
            RST_ASYNC_G    => RST_ASYNC_G,
            DATA_WIDTH_G   => DATA_WIDTH_G,
            PIPE_STAGES_G  => PIPE_STAGES_G)
         port map (
            -- Slave Port
            sData  => portB.dout,
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
      process (clk, rst) is
      begin
         -- Asynchronous reset
         if (RST_ASYNC_G and rst = RST_POLARITY_G) then
            fwftStatus <= READ_STATUS_INIT_C after TPD_G;
         elsif rising_edge(clk) then
            -- Synchronous reset
            if (RST_ASYNC_G = false and rst = RST_POLARITY_G) then
               fwftStatus <= READ_STATUS_INIT_C after TPD_G;
            else
               fwftStatus.prog_empty   <= fifoStatus.prog_empty                            after TPD_G;
               fwftStatus.almost_empty <= fifoStatus.almost_empty                          after TPD_G;
               fwftStatus.empty        <= (sRdEn or fwftStatus.empty) and fifoStatus.empty after TPD_G;
            end if;
         end if;
      end process;
   end generate;

   process (clk, rst) is
   begin
      -- Asynchronous reset
      if (RST_ASYNC_G and rst = RST_POLARITY_G) then
         writeAck        <= '0'             after TPD_G;
         readAck         <= '0'             after TPD_G;
         waddr           <= (others => '0') after TPD_G;
         raddr           <= (others => '0') after TPD_G;
         cnt             <= (others => '0') after TPD_G;
         overflowStatus  <= '0'             after TPD_G;
         underflowStatus <= '0'             after TPD_G;
      elsif rising_edge(clk) then
         writeAck        <= '0' after TPD_G;
         readAck         <= '0' after TPD_G;
         overflowStatus  <= '0' after TPD_G;
         underflowStatus <= '0' after TPD_G;
         -- Synchronous reset
         if (RST_ASYNC_G = false and rst = RST_POLARITY_G) then
            waddr <= (others => '0') after TPD_G;
            raddr <= (others => '0') after TPD_G;
            cnt   <= (others => '0') after TPD_G;
         else

            -- Check for write operation
            if wr_en = '1' then
               if fullStatus = '0' then
                  -- Increment the write address pointer
                  waddr    <= waddr + 1 after TPD_G;
                  writeAck <= '1'       after TPD_G;
               else
                  overflowStatus <= '1' after TPD_G;
               end if;
            end if;

            -- Check for read operation
            if readEnable = '1' then
               if fifoStatus.empty = '0' then
                  -- Increment the read address pointer
                  raddr   <= raddr + 1 after TPD_G;
                  readAck <= '1'       after TPD_G;
               else
                  underflowStatus <= '1' after TPD_G;
               end if;
            end if;

            -- Increment the FIFO counter
            if (readEnable = '1') and (wr_en = '0') and (fifoStatus.empty = '0') then
               cnt <= cnt - 1 after TPD_G;
            elsif (readEnable = '0') and (wr_en = '1') and (fullStatus = '0') then
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
   portB.en   <= readEnable and not(fifoStatus.empty);
   portB.rst  <= rstStatus;
   portB.we   <= '0';
   portB.addr <= raddr;
   portB.din  <= (others => '0');

   BYP_RAM : if (BYP_RAM_G = true) generate
      portB.dout <= (others => '0');
   end generate;

   GEN_RAM : if (BYP_RAM_G = false) generate
      SimpleDualPortRam_Inst : entity work.SimpleDualPortRam
         generic map(
            TPD_G          => TPD_G,
            RST_POLARITY_G => '1',      -- portB.rst already converted to active high
            BRAM_EN_G      => BRAM_EN_G,
            ALTERA_SYN_G   => ALTERA_SYN_G,
            ALTERA_RAM_G   => ALTERA_RAM_G,
            DATA_WIDTH_G   => DATA_WIDTH_G,
            ADDR_WIDTH_G   => ADDR_WIDTH_G,
            INIT_G         => INIT_C)
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
            rstb  => '0',               -- Rely on rd/wr ptrs
            addrb => portB.addr,
            doutb => portB.dout);  
   end generate;

end rtl;
