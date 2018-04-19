-------------------------------------------------------------------------------
-- File       : AxiWritePathFifo.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-25
-- Last update: 2014-05-01
-------------------------------------------------------------------------------
-- Description:
-- FIFO for AXI write path transactions.
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiPkg.all;

entity AxiWritePathFifo is
   generic (

      -- General Configurations
      TPD_G : time := 1 ns;

      -- General FIFO configurations
      XIL_DEVICE_G             : string  := "7SERIES";
      USE_BUILT_IN_G           : boolean := false;
      GEN_SYNC_FIFO_G          : boolean := false;
      ALTERA_SYN_G             : boolean := false;
      ALTERA_RAM_G             : string  := "M9K";

      -- Bit Optimizations
      ADDR_LSB_G               : natural range 0 to 31 := 0;
      ID_FIXED_EN_G            : boolean := false;
      SIZE_FIXED_EN_G          : boolean := false;
      BURST_FIXED_EN_G         : boolean := false;
      LEN_FIXED_EN_G           : boolean := false;
      LOCK_FIXED_EN_G          : boolean := false;
      PROT_FIXED_EN_G          : boolean := false;
      CACHE_FIXED_EN_G         : boolean := false;

      -- Address FIFO Config
      ADDR_BRAM_EN_G           : boolean                    := true;
      ADDR_CASCADE_SIZE_G      : integer range 1 to (2**24) := 1;
      ADDR_FIFO_ADDR_WIDTH_G   : integer range 4 to 48      := 9;

      -- Data FIFO Config
      DATA_BRAM_EN_G           : boolean                    := true;
      DATA_CASCADE_SIZE_G      : integer range 1 to (2**24) := 1;
      DATA_FIFO_ADDR_WIDTH_G   : integer range 4 to 48      := 9;
      DATA_FIFO_PAUSE_THRESH_G : integer range 1 to (2**24) := 500;

      -- Response FIFO Config
      RESP_BRAM_EN_G           : boolean                    := true;
      RESP_CASCADE_SIZE_G      : integer range 1 to (2**24) := 1;
      RESP_FIFO_ADDR_WIDTH_G   : integer range 4 to 48      := 9;

      -- BUS Config
      AXI_CONFIG_G : AxiConfigType := AXI_CONFIG_INIT_C
      );
   port (

      -- Slave Port
      sAxiClk         : in  sl;
      sAxiRst         : in  sl;
      sAxiWriteMaster : in  AxiWriteMasterType;
      sAxiWriteSlave  : out AxiWriteSlaveType;
      sAxiCtrl        : out AxiCtrlType;

      -- Master Port
      mAxiClk         : in  sl;
      mAxiRst         : in  sl;
      mAxiWriteMaster : out AxiWriteMasterType;
      mAxiWriteSlave  : in  AxiWriteSlaveType);
end AxiWritePathFifo;

architecture rtl of AxiWritePathFifo is

   constant ADDR_BITS_C  : integer := AXI_CONFIG_G.ADDR_WIDTH_C - ADDR_LSB_G;
   constant ID_BITS_C    : integer := ite(ID_FIXED_EN_G,0,AXI_CONFIG_G.ID_BITS_C);
   constant LEN_BITS_C   : integer := ite(LEN_FIXED_EN_G,0,AXI_CONFIG_G.LEN_BITS_C);
   constant SIZE_BITS_C  : integer := ite(SIZE_FIXED_EN_G,0,3);
   constant BURST_BITS_C : integer := ite(BURST_FIXED_EN_G,0,2);
   constant LOCK_BITS_C  : integer := ite(LOCK_FIXED_EN_G,0,2);
   constant PROT_BITS_C  : integer := ite(PROT_FIXED_EN_G,0,3);
   constant CACHE_BITS_C : integer := ite(CACHE_FIXED_EN_G,0,4);
   constant DATA_BITS_C  : integer := AXI_CONFIG_G.DATA_BYTES_C*8;
   constant STRB_BITS_C  : integer := AXI_CONFIG_G.DATA_BYTES_C;
   constant RESP_BITS_C  : integer := 2;

   constant ADDR_FIFO_SIZE_C : integer := ADDR_BITS_C  + ID_BITS_C   + LEN_BITS_C  + SIZE_BITS_C + 
                                          BURST_BITS_C + LOCK_BITS_C + PROT_BITS_C + CACHE_BITS_C;

   constant DATA_FIFO_SIZE_C : integer := 1 + DATA_BITS_C  + STRB_BITS_C + ID_BITS_C;

   constant RESP_FIFO_SIZE_C : integer := RESP_BITS_C + ID_BITS_C;

   -- Convert address record to slv
   function addrToSlv (din : AxiWriteMasterType) return slv is
      variable retValue : slv(ADDR_FIFO_SIZE_C-1 downto 0);
      variable i        : integer;
   begin

      retValue(ADDR_BITS_C-1 downto 0) := din.awaddr(AXI_CONFIG_G.ADDR_WIDTH_C-1 downto ADDR_LSB_G);
      i := ADDR_BITS_C;

      if ID_FIXED_EN_G = false then
         retValue((ID_BITS_C+i)-1 downto i) := din.awid(ID_BITS_C-1 downto 0);
         i := i + ID_BITS_C;
      end if;

      if LEN_FIXED_EN_G = false then
         retValue((LEN_BITS_C+i)-1 downto i) := din.awlen(LEN_BITS_C-1 downto 0);
         i := i + LEN_BITS_C;
      end if;

      if SIZE_FIXED_EN_G = false then
         retValue((SIZE_BITS_C+i)-1 downto i) := din.awsize(SIZE_BITS_C-1 downto 0);
         i := i + SIZE_BITS_C;
      end if;

      if BURST_FIXED_EN_G = false then
         retValue((BURST_BITS_C+i)-1 downto i) := din.awburst(BURST_BITS_C-1 downto 0);
         i := i + BURST_BITS_C;
      end if;

      if LOCK_FIXED_EN_G = false then
         retValue((LOCK_BITS_C+i)-1 downto i) := din.awlock(LOCK_BITS_C-1 downto 0);
         i := i + LOCK_BITS_C;
      end if;

      if PROT_FIXED_EN_G = false then
         retValue((PROT_BITS_C+i)-1 downto i) := din.awprot(PROT_BITS_C-1 downto 0);
         i := i + PROT_BITS_C;
      end if;

      if CACHE_FIXED_EN_G = false then
         retValue((CACHE_BITS_C+i)-1 downto i) := din.awcache(CACHE_BITS_C-1 downto 0);
         i := i + CACHE_BITS_C;
      end if;

      return(retValue);

   end function;

   -- Convert slv to address record
   procedure slvToAddr (din    : in    slv(ADDR_FIFO_SIZE_C-1 downto 0);
                        valid  : in    sl; 
                        slave  : in    AxiWriteMasterType;
                        master : inout AxiWriteMasterType ) is
      variable i   : integer;
   begin

      -- Set valid, 
      master.awvalid := valid;

      master.awaddr := (others=>'0');
      master.awaddr(AXI_CONFIG_G.ADDR_WIDTH_C-1 downto ADDR_LSB_G) := din(ADDR_BITS_C-1 downto 0);
      i := ADDR_BITS_C;

      if ID_FIXED_EN_G then
         master.awid := slave.awid;
      else
         master.awid := (others=>'0');
         master.awid(ID_BITS_C-1 downto 0) := din((ID_BITS_C+i)-1 downto i);
         i := i + ID_BITS_C;
      end if;

      if LEN_FIXED_EN_G then
         master.awlen := slave.awlen;
      else
         master.awlen := (others=>'0');
         master.awlen(LEN_BITS_C-1 downto 0) := din((LEN_BITS_C+i)-1 downto i);
         i := i + LEN_BITS_C;
      end if;

      if SIZE_FIXED_EN_G then
         master.awsize := slave.awsize;
      else
         master.awsize := (others=>'0');
         master.awsize(SIZE_BITS_C-1 downto 0) := din((SIZE_BITS_C+i)-1 downto i);
         i := i + SIZE_BITS_C;
      end if;

      if BURST_FIXED_EN_G then
         master.awburst := slave.awburst;
      else
         master.awburst := (others=>'0');
         master.awburst(BURST_BITS_C-1 downto 0) := din((BURST_BITS_C+i)-1 downto i);
         i := i + BURST_BITS_C;
      end if;

      if LOCK_FIXED_EN_G then
         master.awlock := slave.awlock;
      else
         master.awlock := (others=>'0');
         master.awlock(LOCK_BITS_C-1 downto 0) := din((LOCK_BITS_C+i)-1 downto i);
         i := i + LOCK_BITS_C;
      end if;

      if PROT_FIXED_EN_G then
         master.awprot := (others=>'0');
         master.awprot := slave.awprot;
      else
         master.awprot(PROT_BITS_C-1 downto 0) := din((PROT_BITS_C+i)-1 downto i);
         i := i + PROT_BITS_C;
      end if;

      if CACHE_FIXED_EN_G then
         master.awcache := (others=>'0');
         master.awcache := slave.awcache;
      else
         master.awcache(CACHE_BITS_C-1 downto 0) := din((CACHE_BITS_C+i)-1 downto i);
         i := i + CACHE_BITS_C;
      end if;

   end procedure;

   -- Convert data record to slv
   function dataToSlv (din : AxiWriteMasterType) return slv is
      variable retValue : slv(DATA_FIFO_SIZE_C-1 downto 0);
      variable i        : integer;
   begin

      retValue(0) := din.wlast;
      i := 1;

      retValue((DATA_BITS_C+i)-1 downto i) := din.wdata(DATA_BITS_C-1 downto 0);
      i := i + DATA_BITS_C;

      retValue((STRB_BITS_C+i)-1 downto i) := din.wstrb(STRB_BITS_C-1 downto 0);
      i := i + STRB_BITS_C;

      if ID_FIXED_EN_G = false then
         retValue((ID_BITS_C+i)-1 downto i) := din.wid(ID_BITS_C-1 downto 0);
         i := i + ID_BITS_C;
      end if;

      return(retValue);

   end function;

   -- Convert slv to data record
   procedure slvToData (din    : in    slv(DATA_FIFO_SIZE_C-1 downto 0);
                        valid  : in    sl; 
                        slave  : in    AxiWriteMasterType;
                        master : inout AxiWriteMasterType ) is
      variable i   : integer;
   begin

      -- Set valid, 
      master.wvalid := valid;
      master.wlast  := din(0);
      i := 1;

      master.wdata := (others=>'0');
      master.wdata(DATA_BITS_C-1 downto 0) := din((DATA_BITS_C+i)-1 downto i);
      i := i + DATA_BITS_C;

      master.wstrb := (others=>'0');
      master.wstrb(STRB_BITS_C-1 downto 0) := din((STRB_BITS_C+i)-1 downto i);
      i := i + STRB_BITS_C;

      if ID_FIXED_EN_G then
         master.wid := slave.wid;
      else
         master.wid := (others=>'0');
         master.wid(ID_BITS_C-1 downto 0) := din((ID_BITS_C+i)-1 downto i);
         i := i + ID_BITS_C;
      end if;

   end procedure;

   -- Convert resp record to slv
   function respToSlv (din : AxiWriteSlaveType) return slv is
      variable retValue : slv(RESP_FIFO_SIZE_C-1 downto 0);
      variable i        : integer;
   begin

      retValue(RESP_BITS_C-1 downto 0) := din.bresp;
      i := RESP_BITS_C;

      if ID_FIXED_EN_G = false then
         retValue((ID_BITS_C+i)-1 downto i) := din.bid(ID_BITS_C-1 downto 0);
         i := i + ID_BITS_C;
      end if;

      return(retValue);

   end function;

   -- Convert slv to resp record
   procedure slvToResp (din    : in    slv(RESP_FIFO_SIZE_C-1 downto 0);
                        valid  : in    sl; 
                        master : in    AxiWriteMasterType;
                        slave  : inout AxiWriteSlaveType  ) is
      variable i   : integer;
   begin

      -- Set valid, 
      slave.bvalid := valid;

      slave.bresp := din(RESP_BITS_C-1 downto 0);
      i := RESP_BITS_C;

      if ID_FIXED_EN_G then
         slave.bid := master.wid;
      else
         slave.bid := (others=>'0');
         slave.bid(ID_BITS_C-1 downto 0) := din((ID_BITS_C+i)-1 downto i);
         i := ID_BITS_C;
      end if;

   end procedure;

   signal addrFifoWrite    : sl;
   signal addrFifoDin      : slv(ADDR_FIFO_SIZE_C-1 downto 0);
   signal addrFifoDout     : slv(ADDR_FIFO_SIZE_C-1 downto 0);
   signal addrFifoValid    : sl;
   signal addrFifoAFull    : sl;
   signal addrFifoRead     : sl;
   signal dataFifoWrite    : sl;
   signal dataFifoDin      : slv(DATA_FIFO_SIZE_C-1 downto 0);
   signal dataFifoDout     : slv(DATA_FIFO_SIZE_C-1 downto 0);
   signal dataFifoValid    : sl;
   signal dataFifoAFull    : sl;
   signal dataFifoRead     : sl;
   signal respFifoWrite    : sl;
   signal respFifoDin      : slv(RESP_FIFO_SIZE_C-1 downto 0);
   signal respFifoDout     : slv(RESP_FIFO_SIZE_C-1 downto 0);
   signal respFifoValid    : sl;
   signal respFifoAFull    : sl;
   signal respFifoRead     : sl;

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
         RST_ASYNC_G        => false,
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
         FULL_THRES_G       => 1,
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
         prog_full     => open,
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
         RST_ASYNC_G        => false,
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
         FULL_THRES_G       => DATA_FIFO_PAUSE_THRESH_G,
         EMPTY_THRES_G      => 1
         )
      port map (
         rst           => sAxiRst,
         wr_clk        => sAxiClk,
         wr_en         => dataFifoWrite,
         din           => dataFifoDin,
         wr_data_count => open,
         wr_ack        => open,
         overflow      => sAxiCtrl.overflow,
         prog_full     => sAxiCtrl.pause,
         almost_full   => dataFifoAFull,
         full          => open,
         not_full      => open,
         rd_clk        => mAxiClk,
         rd_en         => dataFifoRead,
         dout          => dataFifoDout,
         rd_data_count => open,
         valid         => dataFifoValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open
         );

   U_RespFifo : entity work.FifoCascade
      generic map (
         TPD_G              => TPD_G,
         CASCADE_SIZE_G     => RESP_CASCADE_SIZE_G,
         LAST_STAGE_ASYNC_G => true,
         RST_POLARITY_G     => '1',
         RST_ASYNC_G        => false,
         GEN_SYNC_FIFO_G    => GEN_SYNC_FIFO_G,
         BRAM_EN_G          => RESP_BRAM_EN_G,
         FWFT_EN_G          => true,
         USE_DSP48_G        => "no",
         ALTERA_SYN_G       => ALTERA_SYN_G,
         ALTERA_RAM_G       => ALTERA_RAM_G,
         USE_BUILT_IN_G     => USE_BUILT_IN_G,
         XIL_DEVICE_G       => XIL_DEVICE_G,
         SYNC_STAGES_G      => 3,
         DATA_WIDTH_G       => RESP_FIFO_SIZE_C,
         ADDR_WIDTH_G       => RESP_FIFO_ADDR_WIDTH_G,
         INIT_G             => "0",
         FULL_THRES_G       => 1,
         EMPTY_THRES_G      => 1
         )
      port map (
         rst           => sAxiRst,
         wr_clk        => mAxiClk,
         wr_en         => respFifoWrite,
         din           => respFifoDin,
         wr_data_count => open,
         wr_ack        => open,
         overflow      => open,
         prog_full     => open,
         almost_full   => respFifoAFull,
         full          => open,
         not_full      => open,
         rd_clk        => sAxiClk,
         rd_en         => respFifoRead,
         dout          => respFifoDout,
         rd_data_count => open,
         valid         => respFifoValid,
         underflow     => open,
         prog_empty    => open,
         almost_empty  => open,
         empty         => open
         );


   -------------------------
   -- Fifo Inputs
   -------------------------

   addrFifoDin   <= addrToSlv(sAxiWriteMaster);
   addrFifoWrite <= sAxiWriteMaster.awvalid and (not addrFifoAFull);

   dataFifoDin   <= dataToSlv(sAxiWriteMaster);
   dataFifoWrite <= sAxiWriteMaster.wvalid and (not dataFifoAFull);

   respFifoDin   <= respToSlv(mAxiWriteSlave);
   respFifoWrite <= mAxiWriteSlave.bvalid and (not respFifoAFull);

   -------------------------
   -- Fifo Reads
   -------------------------
   addrFifoRead <= mAxiWriteSlave.awready and addrFifoValid;
   dataFifoRead <= mAxiWriteSlave.wready and dataFifoValid;
   respFifoRead <= sAxiWriteMaster.bready and respFifoValid;

   -------------------------
   -- Fifo Outputs
   -------------------------

   process ( sAxiWriteMaster, mAxiWriteSlave, 
             addrFifoDout, addrFifoAFull, addrFifoValid,
             dataFifoDout, dataFifoAFull, dataFifoValid,
             respFifoDout, respFifoAFull, respFifoValid ) is

      variable imAxiWriteMaster : AxiWriteMasterType;
      variable isAxiWriteSlave  : AxiWriteSlaveType;

   begin

      imAxiWriteMaster := AXI_WRITE_MASTER_INIT_C;
      isAxiWriteSlave  := AXI_WRITE_SLAVE_INIT_C;

      slvToAddr(addrFifoDout, addrFifoValid, sAxiWriteMaster, imAxiWriteMaster);
      slvToData(dataFifoDout, dataFifoValid, sAxiWriteMaster, imAxiWriteMaster);
      slvToResp(respFifoDout, respFifoValid, sAxiWriteMaster, isAxiWriteSlave);

      isAxiWriteSlave.awready := not addrFifoAFull;
      isAxiWriteSlave.wready  := not dataFifoAFull;
      imAxiWriteMaster.bready := not respFifoAFull;

      sAxiWriteSlave  <= isAxiWriteSlave;
      mAxiWriteMaster <= imAxiWriteMaster;

   end process;

end rtl;

