-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AxiDualPortRam.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-12-17
-- Last update: 2016-03-29
-- Platform   : 
-- Standard   : VHDL'93/02
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
      TPD_G        : time                       := 1 ns;
      BRAM_EN_G    : boolean                    := true;
      REG_EN_G     : boolean                    := true;
      MODE_G       : string                     := "write-first";
      AXI_WR_EN_G  : boolean                    := true;
      SYS_WR_EN_G  : boolean                    := false;
      COMMON_CLK_G : boolean                    := false;
      ADDR_WIDTH_G : integer range 1 to (2**24) := 4;
      DATA_WIDTH_G : integer range 1 to 128     := 32;
      INIT_G       : slv                        := "0");

   port (
      -- Axi Port
      axiClk         : in  sl;
      axiRst         : in  sl;
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;

      -- Standard Port
      clk         : in  sl                           := '0';
      en          : in  sl                           := '1';
      we          : in  sl                           := '0';
      rst         : in  sl                           := '0';
      addr        : in  slv(ADDR_WIDTH_G-1 downto 0) := (others => '0');
      din         : in  slv(DATA_WIDTH_G-1 downto 0) := (others => '0');
      dout        : out slv(DATA_WIDTH_G-1 downto 0);
      axiWrStrobe : out sl;
      axiWrAddr   : out slv(ADDR_WIDTH_G-1 downto 0);
      axiWrData   : out slv(DATA_WIDTH_G-1 downto 0));

end entity AxiDualPortRam;

architecture rtl of AxiDualPortRam is

   -- Number of Axi address bits that need to be manually decoded
   constant AXI_DEC_BITS_C : integer := (DATA_WIDTH_G-1)/32;
   subtype AXI_DEC_ADDR_RANGE_C is integer range 1+AXI_DEC_BITS_C downto 2;
   subtype AXI_RAM_ADDR_RANGE_C is integer range ADDR_WIDTH_G+AXI_DEC_ADDR_RANGE_C'high downto AXI_DEC_ADDR_RANGE_C'high+1;

   type RegType is record
      axiWriteSlave : AxiLiteWriteSlaveType;
      axiReadSlave  : AxiLiteReadSlaveType;
      axiAddr       : slv(ADDR_WIDTH_G-1 downto 0);
      axiWrData     : slv(DATA_WIDTH_G-1 downto 0);
      axiWrEn       : sl;
      axiRdEn       : slv(2 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
      axiWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      axiReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axiAddr       => (others => '0'),
      axiWrData     => (others => '0'),
      axiWrEn       => '0',
      axiRdEn       => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal axiDout : slv(DATA_WIDTH_G-1 downto 0);

   signal axiSyncIn  : slv(DATA_WIDTH_G + ADDR_WIDTH_G - 1 downto 0);
   signal axiSyncOut : slv(DATA_WIDTH_G + ADDR_WIDTH_G - 1 downto 0);

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
            DATA_WIDTH_G => DATA_WIDTH_G,
            ADDR_WIDTH_G => ADDR_WIDTH_G,
            INIT_G       => INIT_G)
         port map (
            clka  => clk,
            ena   => en,
            wea   => we,
            rsta  => rst,
            addra => addr,
            dina  => din,
            douta => dout,

            clkb  => axiClk,
            enb   => '1',
            rstb  => axiRst,
            addrb => r.axiAddr,
            doutb => axiDout);
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
            DATA_WIDTH_G => DATA_WIDTH_G,
            ADDR_WIDTH_G => ADDR_WIDTH_G,
            INIT_G       => INIT_G)
         port map (
            clka  => axiClk,
            ena   => '1',
            wea   => r.axiWrEn,
            rsta  => axiRst,
            addra => r.axiAddr,
            dina  => r.axiWrData,
            douta => axiDout,

            clkb  => clk,
            enb   => en,
            rstb  => rst,
            addrb => addr,
            doutb => dout);
   end generate;

   -- Both sides writable, true dual port ram
   AXI_RW_SYS_RW : if (AXI_WR_EN_G and SYS_WR_EN_G) generate
      U_TrueDualPortRam_1 : entity work.TrueDualPortRam
         generic map (
            TPD_G        => TPD_G,
            MODE_G       => MODE_G,
            DOA_REG_G    => REG_EN_G,
            DOB_REG_G    => REG_EN_G,
            DATA_WIDTH_G => DATA_WIDTH_G,
            ADDR_WIDTH_G => ADDR_WIDTH_G,
            INIT_G       => INIT_G)
         port map (
            clka  => axiClk,            -- [in]
            ena   => '1',               -- [in]
            wea   => r.axiWrEn,         -- [in]
            rsta  => axiRst,            -- [in]
            addra => r.axiAddr,         -- [in]
            dina  => r.axiWrData,       -- [in]
            douta => axiDout,           -- [out]
            clkb  => clk,               -- [in]
            enb   => en,                -- [in]
            web   => we,                -- [in]
            rstb  => rst,               -- [in]
            addrb => addr,              -- [in]
            dinb  => din,               -- [in]
            doutb => dout);             -- [out]

   end generate;

   axiSyncIn <= r.axiAddr & r.axiWrData;
   U_SynchronizerFifo_1 : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         COMMON_CLK_G => COMMON_CLK_G,
         BRAM_EN_G    => false,
         DATA_WIDTH_G => ADDR_WIDTH_G+DATA_WIDTH_G)
      port map (
         rst    => rst,                 -- [in]
         wr_clk => axiClk,              -- [in]
         wr_en  => r.axiWrEn,           -- [in]
         din    => axiSyncIn,           -- [in]
         rd_clk => clk,                 -- [in]
         rd_en  => '1',                 -- [in]
         valid  => axiWrStrobe,         -- [out]
         dout   => axiSyncOut);         -- [out]

   axiWrData <= axiSyncOut(DATA_WIDTH_G-1 downto 0);
   axiWrAddr <= axiSyncOut(ADDR_WIDTH_G+DATA_WIDTH_G-1 downto DATA_WIDTH_G);


   comb : process (axiDout, axiReadMaster, axiRst, axiWriteMaster, r) is
      variable v          : RegType;
      variable axiStatus  : AxiLiteStatusType;
      variable decAddrInt : integer;
   begin
      v := r;


      -- Reset strobes and shift Register
      v.axiWrEn := '0';
      v.axiRdEn(0) := '0';
      v.axiRdEn(1) := r.axiRdEn(0);
      v.axiRdEn(2) := r.axiRdEn(1);

      -- This call overwrites v.axiReadSlave.rdata with zero, so call it at the top.
      axiSlaveWaitTxn(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiStatus);
      v.axiReadSlave.rdata := (others => '0');

      -- Assign axiReadSlave.rdata and axiWrData
      if (AXI_DEC_BITS_C = 0) then
         v.axiReadSlave.rdata(DATA_WIDTH_G-1 downto 0) := axiDout;
         v.axiWrData                                   := axiWriteMaster.wdata(DATA_WIDTH_G-1 downto 0);
      else

         -- Mux ram dout onto axi rdata bus
         decAddrInt := conv_integer(axiReadMaster.araddr(AXI_DEC_ADDR_RANGE_C));
         for i in 31 downto 0 loop
            if (32*decAddrInt + i <= DATA_WIDTH_G-1) then
               v.axiReadSlave.rdata(i) := axiDout((32*decAddrInt)+i);
            end if;
         end loop;

         -- Demux axi wdata onto wide ram data bus
         decAddrInt := conv_integer(axiWriteMaster.awaddr(AXI_DEC_ADDR_RANGE_C));
         if (axiStatus.writeEnable = '1') then
            v.axiWrData := axiDout;
            for i in 31 downto 0 loop
               if (32*decAddrInt + i <= DATA_WIDTH_G-1) then
                  v.axiWrData((32*decAddrInt)+i) := axiWriteMaster.wdata(i);
               end if;
            end loop;
         end if;

      end if;

      if (axiStatus.writeEnable = '1') then
         v.axiAddr := axiWriteMaster.awaddr(AXI_RAM_ADDR_RANGE_C);
         v.axiWrEn := ite(AXI_WR_EN_G, '1', '0');
         axiSlaveWriteResponse(v.axiWriteSlave, ite(AXI_WR_EN_G, AXI_RESP_OK_C, AXI_RESP_SLVERR_C));


      elsif (axiStatus.readEnable = '1' and r.axiRdEn = "000") then
         -- Set the address bus
         v.axiAddr := axiReadMaster.araddr(AXI_RAM_ADDR_RANGE_C);
         -- Check for registered BRAM
         if (BRAM_EN_G = true) and (REG_EN_G = true) then
            v.axiRdEn := "001";          -- read in 3 cycles
         -- Check for non-registered BRAM
         elsif (BRAM_EN_G = true) and (REG_EN_G = false) then
            v.axiRdEn := "010";          -- read in 2 cycles
         -- Check for registered LUTRAM
         elsif (BRAM_EN_G = false) and (REG_EN_G = true) then
            v.axiRdEn := "010";          -- read in 2 cycles
         -- Else non-registered LUTRAM
         else
            v.axiRdEn := "100";          -- read on next cycle
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
