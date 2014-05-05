-------------------------------------------------------------------------------
-- Title      : AXI Write Path FIFO
-- Project    : General Purpose Core
-------------------------------------------------------------------------------
-- File       : AxiReadPathFifo.vhd
-- Author     : Ryan Herbst, rherbst@slac.stanford.edu
-- Created    : 2014-04-25
-- Last update: 2014-05-01
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-- FIFO for AXI write path transactions.
-------------------------------------------------------------------------------
-- Copyright (c) 2014 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 04/25/2014: created.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiPkg.all;

entity AxiReadPathFifo is
   generic (

      -- General Configurations
      TPD_G : time := 1 ns;

      -- General FIFO configurations
      RST_ASYNC_G              : boolean                    := false;
      XIL_DEVICE_G             : string                     := "7SERIES";
      USE_BUILT_IN_G           : boolean                    := false;
      GEN_SYNC_FIFO_G          : boolean                    := false;
      ALTERA_SYN_G             : boolean                    := false;
      ALTERA_RAM_G             : string                     := "M9K";

      -- Address FIFO Config
      ADDR_BRAM_EN_G           : boolean                    := true;
      ADDR_CASCADE_SIZE_G      : integer range 1 to (2**24) := 1;
      ADDR_FIFO_ADDR_WIDTH_G   : integer range 4 to 48      := 9;
      ADDR_FIFO_PAUSE_THRESH_G : integer range 1 to (2**24) := 500;

      -- Data FIFO Config
      DATA_BRAM_EN_G           : boolean                    := true;
      DATA_CASCADE_SIZE_G      : integer range 1 to (2**24) := 1;
      DATA_FIFO_ADDR_WIDTH_G   : integer range 4 to 48      := 9;

      -- BUS Config
      ARM_CONFIG_G             : AxiConfigType              := AXI_CONFIG_INIT_C
      )
;
   port (

      -- Slave Port
      sAxiClk         : in  sl;
      sAxiRst         : in  sl;
      sAxiReadMaster : in  AxiReadMasterType;
      sAxiReadSlave  : out AxiReadSlaveType;
      sAxiCtrl        : out AxiCtrlType;

      -- Master Port
      mAxiClk         : in  sl;
      mAxiRst         : in  sl;
      mAxiReadMaster : out AxiReadMasterType;
      mAxiReadSlave  : in  AxiReadSlaveType);
end AxiReadPathFifo;

architecture rtl of AxiReadPathFifo is

   constant ADDR_BITS_C  : integer := 32 - ARM_CONFIG_G.ADDR_LSB_C;
   constant ID_BITS_C    : integer := ite(ARM_CONFIG_G.ID_FIXED_EN_C,0,ARM_CONFIG_G.ID_BITS_C);
   constant LEN_BITS_C   : integer := ite(ARM_CONFIG_G.LEN_FIXED_EN_C,0,4);
   constant SIZE_BITS_C  : integer := ite(ARM_CONFIG_G.SIZE_FIXED_EN_C,0,3);
   constant BURST_BITS_C : integer := ite(ARM_CONFIG_G.BURST_FIXED_EN_C,0,2);
   constant LOCK_BITS_C  : integer := ite(ARM_CONFIG_G.LOCK_FIXED_EN_C,0,2);
   constant PROT_BITS_C  : integer := ite(ARM_CONFIG_G.PROT_FIXED_EN_C,0,3);
   constant CACHE_BITS_C : integer := ite(ARM_CONFIG_G.CACHE_FIXED_EN_C,0,4);
   constant DATA_BITS_C  : integer := ARM_CONFIG_G.DATA_BYTES_C*8;
   constant STRB_BITS_C  : integer := ARM_CONFIG_G.DATA_BYTES_C;
   constant RESP_BITS_C  : integer := 2;

   constant ADDR_FIFO_SIZE_C : integer := ADDR_BITS_C  + ID_BITS_C   + LEN_BITS_C  + SIZE_BITS_C + 
                                          BURST_BITS_C + LOCK_BITS_C + PROT_BITS_C + CACHE_BITS_C;

   constant DATA_FIFO_SIZE_C : integer := 1 + DATA_BITS_C + RESP_BITS_C + ID_BITS_C;

   -- Convert address record to slv
   function addrToSlv (din : AxiReadMasterType) return slv is
      variable retValue : slv(ADDR_FIFO_SIZE_C-1 downto 0);
      variable i        : integer;
   begin

      retValue(ADDR_BITS_C-1 downto 0) := din.araddr(31 downto ARM_CONFIG_G.ADDR_LSB_C);
      i := ADDR_BITS_C;

      if ARM_CONFIG_G.ID_FIXED_EN_C = false then
         retValue((ID_BITS_C+i)-1 downto i) := din.arid(ID_BITS_C-1 downto 0);
         i := i + ID_BITS_C;
      end if;

      if ARM_CONFIG_G.LEN_FIXED_EN_C = false then
         retValue((LEN_BITS_C+i)-1 downto i) := din.arlen(LEN_BITS_C-1 downto 0);
         i := i + LEN_BITS_C;
      end if;

      if ARM_CONFIG_G.SIZE_FIXED_EN_C = false then
         retValue((SIZE_BITS_C+i)-1 downto i) := din.arsize(SIZE_BITS_C-1 downto 0);
         i := i + SIZE_BITS_C;
      end if;

      if ARM_CONFIG_G.BURST_FIXED_EN_C = false then
         retValue((BURST_BITS_C+i)-1 downto i) := din.arburst(BURST_BITS_C-1 downto 0);
         i := i + BURST_BITS_C;
      end if;

      if ARM_CONFIG_G.LOCK_FIXED_EN_C = false then
         retValue((LOCK_BITS_C+i)-1 downto i) := din.arlock(LOCK_BITS_C-1 downto 0);
         i := i + LOCK_BITS_C;
      end if;

      if ARM_CONFIG_G.PROT_FIXED_EN_C = false then
         retValue((PROT_BITS_C+i)-1 downto i) := din.arprot(PROT_BITS_C-1 downto 0);
         i := i + PROT_BITS_C;
      end if;

      if ARM_CONFIG_G.CACHE_FIXED_EN_C = false then
         retValue((CACHE_BITS_C+i)-1 downto i) := din.arcache(CACHE_BITS_C-1 downto 0);
         i := i + CACHE_BITS_C;
      end if;

      return(retValue);

   end function;

   -- Convert slv to address record
   procedure slvToAddr (din    : in    slv(ADDR_FIFO_SIZE_C-1 downto 0);
                        valid  : in    sl; 
                        slave  : in    AxiReadMasterType;
                        master : inout AxiReadMasterType ) is
      variable i   : integer;
   begin

      -- Set valid, 
      master.arvalid := valid;

      master.araddr := (others=>'0');
      master.araddr(31 downto ARM_CONFIG_G.ADDR_LSB_C) := din(ADDR_BITS_C-1 downto 0);
      i := ADDR_BITS_C;

      if ARM_CONFIG_G.ID_FIXED_EN_C then
         master.arid := slave.arid;
      else
         master.arid := (others=>'0');
         master.arid(ID_BITS_C-1 downto 0) := din((ID_BITS_C+i)-1 downto i);
         i := i + ID_BITS_C;
      end if;

      if ARM_CONFIG_G.LEN_FIXED_EN_C then
         master.arlen := slave.arlen;
      else
         master.arlen := (others=>'0');
         master.arlen(LEN_BITS_C-1 downto 0) := din((LEN_BITS_C+i)-1 downto i);
         i := i + LEN_BITS_C;
      end if;

      if ARM_CONFIG_G.SIZE_FIXED_EN_C then
         master.arsize := slave.arsize;
      else
         master.arsize := (others=>'0');
         master.arsize(SIZE_BITS_C-1 downto 0) := din((SIZE_BITS_C+i)-1 downto i);
         i := i + SIZE_BITS_C;
      end if;

      if ARM_CONFIG_G.BURST_FIXED_EN_C then
         master.arburst := slave.arburst;
      else
         master.arburst := (others=>'0');
         master.arburst(BURST_BITS_C-1 downto 0) := din((BURST_BITS_C+i)-1 downto i);
         i := i + BURST_BITS_C;
      end if;

      if ARM_CONFIG_G.LOCK_FIXED_EN_C then
         master.arlock := slave.arlock;
      else
         master.arlock := (others=>'0');
         master.arlock(LOCK_BITS_C-1 downto 0) := din((LOCK_BITS_C+i)-1 downto i);
         i := i + LOCK_BITS_C;
      end if;

      if ARM_CONFIG_G.PROT_FIXED_EN_C then
         master.arprot := (others=>'0');
         master.arprot := slave.arprot;
      else
         master.arprot(PROT_BITS_C-1 downto 0) := din((PROT_BITS_C+i)-1 downto i);
         i := i + PROT_BITS_C;
      end if;

      if ARM_CONFIG_G.CACHE_FIXED_EN_C then
         master.arcache := (others=>'0');
         master.arcache := slave.arcache;
      else
         master.arcache(CACHE_BITS_C-1 downto 0) := din((CACHE_BITS_C+i)-1 downto i);
         i := i + CACHE_BITS_C;
      end if;

   end procedure;

   -- Convert data record to slv
   function dataToSlv (din : AxiReadSlaveType) return slv is
      variable retValue : slv(DATA_FIFO_SIZE_C-1 downto 0);
      variable i        : integer;
   begin

      retValue(0) := din.rlast;
      i := 1;

      retValue((DATA_BITS_C+i)-1 downto i) := din.rdata(DATA_BITS_C-1 downto 0);
      i := i + DATA_BITS_C;

      if ARM_CONFIG_G.ID_FIXED_EN_C = false then
         retValue((ID_BITS_C+i)-1 downto i) := din.rid(ID_BITS_C-1 downto 0);
         i := i + ID_BITS_C;
      end if;

      retValue(RESP_BITS_C-1 downto 0) := din.rresp;
      i := RESP_BITS_C;

      return(retValue);

   end function;

   -- Convert slv to data record
   procedure slvToData (din    : in    slv(DATA_FIFO_SIZE_C-1 downto 0);
                        valid  : in    sl; 
                        master : in    AxiReadMasterType;
                        slave  : inout AxiReadSlaveType ) is
      variable i   : integer;
   begin

      -- Set valid, 
      slave.rvalid := valid;
      slave.rlast  := din(0);
      i := 1;

      slave.rdata := (others=>'0');
      slave.rdata(DATA_BITS_C-1 downto 0) := din((DATA_BITS_C+i)-1 downto i);
      i := i + DATA_BITS_C;

      if ARM_CONFIG_G.ID_FIXED_EN_C then
         slave.rid := master.arid;
      else
         slave.rid := (others=>'0');
         slave.rid(ID_BITS_C-1 downto 0) := din((ID_BITS_C+i)-1 downto i);
         i := i + ID_BITS_C;
      end if;

      slave.rresp := din(RESP_BITS_C-1 downto 0);
      i := RESP_BITS_C;

   end procedure;

   signal addrFifoWrite    : sl;
   signal addrFifoDin      : slv(ADDR_BITS_C-1 downto 0);
   signal addrFifoDout     : slv(ADDR_BITS_C-1 downto 0);
   signal addrFifoValid    : sl;
   signal addrFifoAFull    : sl;
   signal addrFifoPFull    : sl;
   signal addrFifoRead     : sl;
   signal dataFifoWrite    : sl;
   signal dataFifoDin      : slv(ADDR_BITS_C-1 downto 0);
   signal dataFifoDout     : slv(ADDR_BITS_C-1 downto 0);
   signal dataFifoValid    : sl;
   signal dataFifoAFull    : sl;
   signal dataFifoRead     : sl;

begin

   -------------------------
   -- FIFOs
   -------------------------

   U_AddrFifo : entity work.FifoCascade
      generic map (
         TPD_G              => TPD_G,
         CASCADE_SIZE_G     => ADDR_CASCADE_SIZE_G,
         LAST_STAGE_ASYNC_G => true,
         RST_POLARITY_G     => '1',
         RST_ASYNC_G        => RST_ASYNC_G,
         GEN_SYNC_FIFO_G    => GEN_SYNC_FIFO_G,
         BRAM_EN_G          => ADDR_BRAM_EN_G,
         FWFT_EN_G          => true,
         USE_DSP48_G        => "no",
         ALTERA_SYN_G       => ALTERA_SYN_G,
         ALTERA_RAM_G       => ALTERA_RAM_G,
         USE_BUILT_IN_G     => USE_BUILT_IN_G,
         XIL_DEVICE_G       => XIL_DEVICE_G,
         SYNC_STAGES_G      => 3,
         DATA_WIDTH_G       => ADDR_FIFO_SIZE_C,
         ADDR_WIDTH_G       => ADDR_FIFO_ADDR_WIDTH_G,
         INIT_G             => "0",
         FULL_THRES_G       => ADDR_FIFO_PAUSE_THRESH_G,
         EMPTY_THRES_G      => 1
         )
      port map (
         rst           => sAxiRst,
         wr_clk        => sAxiClk,
         wr_en         => addrFifoWrite,
         din           => addrFifoDin,
         wr_data_count => open,
         wr_ack        => open,
         overflow      => open,
         prog_full     => addrFifoPFull,
         almost_full   => addrFifoAFull,
         full          => open,
         not_full      => open,
         rd_clk        => mAxiClk,
         rd_en         => addrFifoRead,
         dout          => addrFifoDout,
         rd_data_count => open,
         valid         => addrFifoValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open
         );

   U_DataFifo : entity work.FifoCascade
      generic map (
         TPD_G              => TPD_G,
         CASCADE_SIZE_G     => DATA_CASCADE_SIZE_G,
         LAST_STAGE_ASYNC_G => true,
         RST_POLARITY_G     => '1',
         RST_ASYNC_G        => RST_ASYNC_G,
         GEN_SYNC_FIFO_G    => GEN_SYNC_FIFO_G,
         BRAM_EN_G          => DATA_BRAM_EN_G,
         FWFT_EN_G          => true,
         USE_DSP48_G        => "no",
         ALTERA_SYN_G       => ALTERA_SYN_G,
         ALTERA_RAM_G       => ALTERA_RAM_G,
         USE_BUILT_IN_G     => USE_BUILT_IN_G,
         XIL_DEVICE_G       => XIL_DEVICE_G,
         SYNC_STAGES_G      => 3,
         DATA_WIDTH_G       => DATA_FIFO_SIZE_C,
         ADDR_WIDTH_G       => DATA_FIFO_ADDR_WIDTH_G,
         INIT_G             => "0",
         FULL_THRES_G       => 1,
         EMPTY_THRES_G      => 1
         )
      port map (
         rst           => sAxiRst,
         wr_clk        => mAxiClk,
         wr_en         => dataFifoWrite,
         din           => dataFifoDin,
         wr_data_count => open,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => dataFifoAFull,
         full          => open,
         not_full      => open,
         rd_clk        => sAxiClk,
         rd_en         => dataFifoRead,
         dout          => dataFifoDout,
         rd_data_count => open,
         valid         => dataFifoValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open
         );


   -------------------------
   -- Fifo Inputs
   -------------------------

   addrFifoDin   <= addrToSlv(sAxiReadMaster);
   addrFifoWrite <= sAxiReadMaster.arvalid and (not addrFifoAFull);

   dataFifoDin   <= dataToSlv(mAxiReadSlave);
   dataFifoWrite <= mAxiReadSlave.rvalid and (not dataFifoAFull);


   -------------------------
   -- Fifo Outputs
   -------------------------

   process ( sAxiReadMaster, mAxiReadSlave, 
             addrFifoDout, addrFifoAFull, addrFifoValid,
             dataFifoDout, dataFifoAFull, dataFifoValid ) is

      variable imAxiReadMaster : AxiReadMasterType;
      variable isAxiReadSlave  : AxiReadSlaveType;

   begin

      imAxiReadMaster := AXI_READ_MASTER_INIT_C;
      isAxiReadSlave  := AXI_READ_SLAVE_INIT_C;

      slvToAddr(addrFifoDout, addrFifoValid, sAxiReadMaster, imAxiReadMaster);
      slvToData(dataFifoDout, dataFifoValid, sAxiReadMaster, isAxiReadSlave);

      isAxiReadSlave.arready := not addrFifoAFull;
      imAxiReadMaster.rready := not dataFifoAFull;

      sAxiReadSlave  <= isAxiReadSlave;
      mAxiReadMaster <= imAxiReadMaster;

   end process;

   -------------------------
   -- Flow Control
   -------------------------
   process ( sAxiClk ) begin
      if rising_edge (sAxiClk) then
         if sAxiRst = '1' then
            sAxiCtrl <= AXI_CTRL_INIT_C after TPD_G;
         else
            sAxiCtrl.pause <= addrFifoPFull after TPD_G;
         end if;
      end if;
   end process;

end rtl;

