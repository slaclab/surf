-------------------------------------------------------------------------------
-- File       : AxiDualPortRam.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-12-17
-- Last update: 2017-01-11
-------------------------------------------------------------------------------
-- Description: A wrapper of StdLib DualPortRam that places an AxiLite
-- interface on the read/write port. 
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
use work.AxiLitePkg.all;

entity AxiDualPortRam is

   generic (
      TPD_G            : time                       := 1 ns;
      BRAM_EN_G        : boolean                    := false;
      REG_EN_G         : boolean                    := true;
      MODE_G           : string                     := "read-first";
      AXI_WR_EN_G      : boolean                    := true;
      SYS_WR_EN_G      : boolean                    := false;
      SYS_BYTE_WR_EN_G : boolean                    := false;
      COMMON_CLK_G     : boolean                    := false;
      ADDR_WIDTH_G     : integer range 1 to (2**24) := 5;
      DATA_WIDTH_G     : integer                    := 32;
      INIT_G           : slv                        := "0";
      AXI_ERROR_RESP_G : slv(1 downto 0)            := AXI_RESP_DECERR_C);

   port (
      -- Axi Port
      axiClk         : in  sl;
      axiRst         : in  sl;
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;

      -- Standard Port
      clk         : in  sl                                         := '0';
      en          : in  sl                                         := '1';
      we          : in  sl                                         := '0';
      weByte      : in  slv(wordCount(DATA_WIDTH_G, 8)-1 downto 0) := (others => '0');
      rst         : in  sl                                         := '0';
      addr        : in  slv(ADDR_WIDTH_G-1 downto 0)               := (others => '0');
      din         : in  slv(DATA_WIDTH_G-1 downto 0)               := (others => '0');
      dout        : out slv(DATA_WIDTH_G-1 downto 0);
      axiWrValid  : out sl;
      axiWrStrobe : out slv(wordCount(DATA_WIDTH_G, 8)-1 downto 0);
      axiWrAddr   : out slv(ADDR_WIDTH_G-1 downto 0);
      axiWrData   : out slv(DATA_WIDTH_G-1 downto 0));

end entity AxiDualPortRam;

architecture rtl of AxiDualPortRam is

   -- Number of Axi address bits that need to be manually decoded
   constant AXI_DEC_BITS_C : integer := ite(DATA_WIDTH_G <= 32, 0, log2((DATA_WIDTH_G-1)/32));
   subtype AXI_DEC_ADDR_RANGE_C is integer range 1+AXI_DEC_BITS_C downto 2;
   subtype AXI_RAM_ADDR_RANGE_C is integer range ADDR_WIDTH_G+AXI_DEC_ADDR_RANGE_C'high downto AXI_DEC_ADDR_RANGE_C'high+1;


   constant ADDR_AXI_WORDS_C : natural := wordCount(DATA_WIDTH_G, 32);
   constant ADDR_AXI_BYTES_C : natural := wordCount(DATA_WIDTH_G, 8);
   constant RAM_WIDTH_C      : natural := ADDR_AXI_WORDS_C*32;
   constant STRB_WIDTH_C     : natural := minimum(4, ADDR_AXI_BYTES_C);

   type RegType is record
      axiWriteSlave : AxiLiteWriteSlaveType;
      axiReadSlave  : AxiLiteReadSlaveType;
      axiAddr       : slv(ADDR_WIDTH_G-1 downto 0);
      axiWrStrobe   : slv(ADDR_AXI_WORDS_C*4-1 downto 0);
      axiRdEn       : slv(2 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
      axiWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      axiReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axiAddr       => (others => '0'),
      axiWrStrobe   => (others => '0'),
      axiRdEn       => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal axiWrDataFanout : slv(RAM_WIDTH_C-1 downto 0);
   signal axiDout         : slv(RAM_WIDTH_C-1 downto 0) := (others => '0');

   signal axiSyncWrEn : sl;
   signal axiSyncIn   : slv(DATA_WIDTH_G + ADDR_WIDTH_G + ADDR_AXI_BYTES_C - 1 downto 0);
   signal axiSyncOut  : slv(DATA_WIDTH_G + ADDR_WIDTH_G + ADDR_AXI_BYTES_C - 1 downto 0);

begin


   -- AXI read only, sys writable or read only (rom)
   AXI_R0_SYS_RW : if (not AXI_WR_EN_G and SYS_WR_EN_G) generate
      DualPortRam_1 : entity work.DualPortRam
         generic map (
            TPD_G        => TPD_G,
            BRAM_EN_G    => BRAM_EN_G,
            REG_EN_G     => REG_EN_G,
            DOA_REG_G    => REG_EN_G,
            DOB_REG_G    => REG_EN_G,
            MODE_G       => MODE_G,
            BYTE_WR_EN_G => SYS_BYTE_WR_EN_G,
            DATA_WIDTH_G => DATA_WIDTH_G,
            ADDR_WIDTH_G => ADDR_WIDTH_G,
            INIT_G       => INIT_G)
         port map (
            clka    => clk,
            ena     => en,
            wea     => we,
            weaByte => weByte,
            rsta    => rst,
            addra   => addr,
            dina    => din,
            douta   => dout,

            clkb  => axiClk,
            enb   => '1',
            rstb  => '0',
            addrb => r.axiAddr,
            doutb => axiDout(DATA_WIDTH_G-1 downto 0));
   end generate;

   -- System Read only, Axi writable or read only (ROM)
   -- Logic disables axi writes if AXI_WR_EN_G=false
   AXI_RW_SYS_RO : if (not SYS_WR_EN_G) generate
      DualPortRam_1 : entity work.DualPortRam
         generic map (
            TPD_G        => TPD_G,
            BRAM_EN_G    => BRAM_EN_G,
            REG_EN_G     => REG_EN_G,
            DOA_REG_G    => REG_EN_G,
            DOB_REG_G    => REG_EN_G,
            MODE_G       => MODE_G,
            BYTE_WR_EN_G => true,
            DATA_WIDTH_G => DATA_WIDTH_G,
            BYTE_WIDTH_G => 8,
            ADDR_WIDTH_G => ADDR_WIDTH_G,
            INIT_G       => INIT_G)
         port map (
            clka    => axiClk,
            ena     => '1',
            weaByte => r.axiWrStrobe(ADDR_AXI_BYTES_C-1 downto 0),
            rsta    => '0',
            addra   => r.axiAddr,
            dina    => axiWrDataFanout(DATA_WIDTH_G-1 downto 0),
            douta   => axiDout(DATA_WIDTH_G-1 downto 0),
            clkb    => clk,
            enb     => en,
            rstb    => rst,
            addrb   => addr,
            doutb   => dout);
   end generate;

--    -- Both sides writable, true dual port ram
   AXI_RW_SYS_RW : if (AXI_WR_EN_G and SYS_WR_EN_G) generate
      U_TrueDualPortRam_1 : entity work.TrueDualPortRam
         generic map (
            TPD_G        => TPD_G,
            MODE_G       => MODE_G,
            BYTE_WR_EN_G => true,
            DOA_REG_G    => REG_EN_G,
            DOB_REG_G    => REG_EN_G,
            DATA_WIDTH_G => DATA_WIDTH_G,
            BYTE_WIDTH_G => 8,
            ADDR_WIDTH_G => ADDR_WIDTH_G,
            INIT_G       => INIT_G)
         port map (
            clka    => axiClk,                                    -- [in]
            ena     => '1',                                       -- [in]
            wea     => '1',
            weaByte => r.axiWrStrobe(ADDR_AXI_BYTES_C-1 downto 0),
            rsta    => '0',                                       -- [in]
            addra   => r.axiAddr,                                 -- [in]
            dina    => axiWrDataFanout(DATA_WIDTH_G-1 downto 0),  -- [in]
            douta   => axiDout(DATA_WIDTH_G-1 downto 0),          -- [out]
            clkb    => clk,                                       -- [in]
            enb     => en,                                        -- [in]
            web     => we,                                        -- [in]
            webByte => weByte,                                    -- [in]
            rstb    => rst,                                       -- [in]
            addrb   => addr,                                      -- [in]
            dinb    => din,                                       -- [in]
            doutb   => dout);                                     -- [out]

   end generate;

   axiSyncIn(DATA_WIDTH_G-1 downto 0)
      <= axiWrDataFanout(DATA_WIDTH_G-1 downto 0);
   axiSyncIn(ADDR_WIDTH_G+DATA_WIDTH_G-1 downto DATA_WIDTH_G)
      <= r.axiAddr;
   axiSyncIn(ADDR_WIDTH_G+DATA_WIDTH_G+ADDR_AXI_BYTES_C-1 downto ADDR_WIDTH_G+DATA_WIDTH_G)
      <= r.axiWrStrobe(ADDR_AXI_BYTES_C-1 downto 0);
   axiSyncWrEn <= uOr(r.axiWrStrobe(ADDR_AXI_BYTES_C-1 downto 0));
   U_SynchronizerFifo_1 : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         COMMON_CLK_G => COMMON_CLK_G,
         BRAM_EN_G    => false,
         DATA_WIDTH_G => ADDR_WIDTH_G+DATA_WIDTH_G+ADDR_AXI_BYTES_C)
      port map (
         rst    => rst,                 -- [in]
         wr_clk => axiClk,              -- [in]
         wr_en  => axiSyncWrEn,         -- [in]
         din    => axiSyncIn,           -- [in]
         rd_clk => clk,                 -- [in]
         rd_en  => '1',                 -- [in]
         valid  => axiWrValid,          -- [out]
         dout   => axiSyncOut);         -- [out]

   axiWrData   <= axiSyncOut(DATA_WIDTH_G-1 downto 0);
   axiWrAddr   <= axiSyncOut(ADDR_WIDTH_G+DATA_WIDTH_G-1 downto DATA_WIDTH_G);
   axiWrStrobe <= axiSyncOut(ADDR_WIDTH_G+DATA_WIDTH_G+ADDR_AXI_BYTES_C-1 downto ADDR_WIDTH_G+DATA_WIDTH_G);


   axiWrMap : for i in 0 to ADDR_AXI_WORDS_C-1 generate
      axiWrDataFanout((i+1)*32-1 downto i*32) <= axiWriteMaster.wdata;
   end generate axiWrMap;

   comb : process (axiDout, axiReadMaster, axiRst, axiWriteMaster, r) is
      variable v          : RegType;
      variable axiStatus  : AxiLiteStatusType;
      variable decAddrInt : integer;
   begin
      v := r;


      -- Reset strobes and shift Register
      v.axiWrStrobe := (others => '0');
      v.axiRdEn(0)  := '0';
      v.axiRdEn(1)  := r.axiRdEn(0);
      v.axiRdEn(2)  := r.axiRdEn(1);


      axiSlaveWaitTxn(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiStatus);
      v.axiReadSlave.rdata := (others => '0');


      -- Multiplex read data onto axi bus
      decAddrInt := conv_integer(axiReadMaster.araddr(AXI_DEC_ADDR_RANGE_C));
      v.axiReadSlave.rdata := axiDout((decAddrInt+1)*32-1 downto decAddrInt*32);

      -- Set axiAddr to read address by default
      v.axiAddr := axiReadMaster.araddr(AXI_RAM_ADDR_RANGE_C);

      -- Don't allow a write if a read is active
      if (axiStatus.writeEnable = '1' and r.axiRdEn = "000") then
         if (AXI_WR_EN_G) then
            v.axiAddr  := axiWriteMaster.awaddr(AXI_RAM_ADDR_RANGE_C);
            decAddrInt := conv_integer(axiWriteMaster.awaddr(AXI_DEC_ADDR_RANGE_C));
            v.axiWrStrobe((decAddrInt+1)*4-1 downto decAddrInt*4) :=
               axiWriteMaster.wstrb;
         end if;
         axiSlaveWriteResponse(v.axiWriteSlave, ite(AXI_WR_EN_G, AXI_RESP_OK_C, AXI_RESP_SLVERR_C));


      elsif (axiStatus.readEnable = '1' and r.axiRdEn = "000") then
         -- Set the address bus
         v.axiAddr := axiReadMaster.araddr(AXI_RAM_ADDR_RANGE_C);
         -- Check for registered BRAM
         if (BRAM_EN_G = true) and (REG_EN_G = true) then
            v.axiRdEn := "001";         -- read in 3 cycles
         -- Check for non-registered BRAM
         elsif (BRAM_EN_G = true) and (REG_EN_G = false) then
            v.axiRdEn := "010";         -- read in 2 cycles
         -- Check for registered LUTRAM
         elsif (BRAM_EN_G = false) and (REG_EN_G = true) then
            v.axiRdEn := "010";         -- read in 2 cycles
         -- Else non-registered LUTRAM
         else
            v.axiRdEn := "100";         -- read on next cycle
         end if;
      end if;

      if (r.axiRdEn(2) = '1') then
         axiSlaveReadResponse(v.axiReadSlave);
      end if;

      if (axiRst = '1') then
         v := REG_INIT_C;
      end if;

      rin           <= v;
      axiReadSlave  <= r.axiReadSlave;
      axiWriteSlave <= r.axiWriteSlave;

   end process comb;

   seq : process (axiClk) is
   begin
      if (rising_edge(axiClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
