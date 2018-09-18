-------------------------------------------------------------------------------
-- File       : AxiLiteAsync.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- Asynchronous bridge for AXI Lite bus. Allows AXI transactions to cross 
-- a clock boundary.
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

entity AxiLiteAsync is
   generic (
      TPD_G            : time                  := 1 ns;
      AXI_ERROR_RESP_G : slv(1 downto 0)       := AXI_RESP_SLVERR_C;
      SYNTH_MODE_G     : string                := "inferred";
      COMMON_CLK_G     : boolean               := false;
      NUM_ADDR_BITS_G  : natural               := 32;
      PIPE_STAGES_G    : integer range 0 to 16 := 0);
   port (
      -- Slave Port
      sAxiClk         : in  sl;
      sAxiClkRst      : in  sl;
      sAxiReadMaster  : in  AxiLiteReadMasterType;
      sAxiReadSlave   : out AxiLiteReadSlaveType;
      sAxiWriteMaster : in  AxiLiteWriteMasterType;
      sAxiWriteSlave  : out AxiLiteWriteSlaveType;
      -- Master Port
      mAxiClk         : in  sl;
      mAxiClkRst      : in  sl;
      mAxiReadMaster  : out AxiLiteReadMasterType;
      mAxiReadSlave   : in  AxiLiteReadSlaveType;
      mAxiWriteMaster : out AxiLiteWriteMasterType;
      mAxiWriteSlave  : in  AxiLiteWriteSlaveType);
end AxiLiteAsync;

architecture STRUCTURE of AxiLiteAsync is

   signal s2mRst : sl;                  -- Slave rst sync'd to master clk
   signal m2sRst : sl;                  -- Master rst sync'd to slave clk

   signal readSlaveToMastDin   : slv(NUM_ADDR_BITS_G+2 downto 0);
   signal readSlaveToMastDout  : slv(NUM_ADDR_BITS_G+2 downto 0);
   signal readSlaveToMastAFull : sl;
   signal readSlaveToMastValid : sl;
   signal readSlaveToMastRead  : sl;
   signal readSlaveToMastWrite : sl;

   signal readMastToSlaveDin   : slv(33 downto 0);
   signal readMastToSlaveDout  : slv(33 downto 0);
   signal readMastToSlaveAFull : sl;
   signal readMastToSlaveValid : sl;
   signal readMastToSlaveRead  : sl;
   signal readMastToSlaveWrite : sl;

   signal writeAddrSlaveToMastDin   : slv(NUM_ADDR_BITS_G+2 downto 0);
   signal writeAddrSlaveToMastDout  : slv(NUM_ADDR_BITS_G+2 downto 0);
   signal writeAddrSlaveToMastAFull : sl;
   signal writeAddrSlaveToMastValid : sl;
   signal writeAddrSlaveToMastRead  : sl;
   signal writeAddrSlaveToMastWrite : sl;

   signal writeDataSlaveToMastDin   : slv(35 downto 0);
   signal writeDataSlaveToMastDout  : slv(35 downto 0);
   signal writeDataSlaveToMastAFull : sl;
   signal writeDataSlaveToMastValid : sl;
   signal writeDataSlaveToMastRead  : sl;
   signal writeDataSlaveToMastWrite : sl;

   signal writeMastToSlaveDin   : slv(1 downto 0);
   signal writeMastToSlaveDout  : slv(1 downto 0);
   signal writeMastToSlaveAFull : sl;
   signal writeMastToSlaveValid : sl;
   signal writeMastToSlaveRead  : sl;
   signal writeMastToSlaveWrite : sl;

begin

   GEN_SYNC : if (COMMON_CLK_G = true) generate

      mAxiReadMaster  <= sAxiReadMaster;
      sAxiReadSlave   <= mAxiReadSlave;
      mAxiWriteMaster <= sAxiWriteMaster;
      sAxiWriteSlave  <= mAxiWriteSlave;

   end generate;

   GEN_ASYNC : if (COMMON_CLK_G = false) generate

      -- Synchronize each reset across to the other clock domain
      LOC_S2M_RstSync : entity work.RstSync
         generic map (
            TPD_G         => TPD_G,
            OUT_REG_RST_G => false)
         port map (
            clk      => mAxiClk,
            asyncRst => sAxiClkRst,
            syncRst  => s2mRst);

      LOC_M2S_RstSync : entity work.RstSync
         generic map (
            TPD_G         => TPD_G,
            OUT_REG_RST_G => false)
         port map (
            clk      => sAxiClk,
            asyncRst => mAxiClkRst,
            syncRst  => m2sRst);

      ------------------------------------
      -- Read: Slave to Master
      ------------------------------------

      -- Read Slave To Master FIFO
      U_ReadSlaveToMastFifo : entity work.Fifo
         generic map (
            TPD_G           => TPD_G,
            SYNTH_MODE_G    => SYNTH_MODE_G,
            MEMORY_TYPE_G   => "distributed",
            GEN_SYNC_FIFO_G => false,
            FWFT_EN_G       => true,
            PIPE_STAGES_G   => PIPE_STAGES_G,
            DATA_WIDTH_G    => NUM_ADDR_BITS_G+3,
            ADDR_WIDTH_G    => 4)
         port map (
            rst         => s2mRst,
            wr_clk      => sAxiClk,
            wr_en       => readSlaveToMastWrite,
            din         => readSlaveTomastDin,
            almost_full => readSlaveToMastAFull,
            rd_clk      => mAxiClk,
            rd_en       => readSlaveToMastRead,
            dout        => readSlaveTomastDout,
            valid       => readSlaveToMastValid);

      -- Data In
      readSlaveToMastDin(2 downto 0)                 <= sAxiReadMaster.arprot;
      readSlaveToMastDin(NUM_ADDR_BITS_G+2 downto 3) <= sAxiReadMaster.araddr(NUM_ADDR_BITS_G-1 downto 0);

      -- Write control and ready generation
      sAxiReadSlave.arready <= ite(m2sRst = '0', not readSlaveToMastAFull, '1');
      readSlaveToMastWrite  <= sAxiReadMaster.arvalid and (not readSlaveToMastAFull);

      -- Data Out
      mAxiReadMaster.arprot <= readSlaveToMastDout(2 downto 0);

      process (readSlaveToMastDout)
      begin
         mAxiReadMaster.araddr                             <= (others => '0');
         mAxiReadMaster.araddr(NUM_ADDR_BITS_G-1 downto 0) <= readSlaveToMastDout(NUM_ADDR_BITS_G+2 downto 3);
      end process;

      -- Read control and valid
      mAxiReadMaster.arvalid <= readSlaveToMastValid;
      readSlaveToMastRead    <= mAxiReadSlave.arready;


      ------------------------------------
      -- Read: Master To Slave
      ------------------------------------

      -- Read Master To Slave FIFO
      U_ReadMastToSlaveFifo : entity work.Fifo
         generic map (
            TPD_G           => TPD_G,
            SYNTH_MODE_G    => SYNTH_MODE_G,
            MEMORY_TYPE_G   => "distributed",
            GEN_SYNC_FIFO_G => false,
            FWFT_EN_G       => true,
            PIPE_STAGES_G   => PIPE_STAGES_G,
            DATA_WIDTH_G    => 34,
            ADDR_WIDTH_G    => 4)
         port map (
            rst         => m2sRst,
            wr_clk      => mAxiClk,
            wr_en       => readMastToSlaveWrite,
            din         => readMastToSlaveDin,
            almost_full => readMastToSlaveAFull,
            rd_clk      => sAxiClk,
            rd_en       => readMastToSlaveRead,
            dout        => readMastToSlaveDout,
            valid       => readMastToSlaveValid);

      -- Data In
      readMastToSlaveDin(1 downto 0)  <= mAxiReadSlave.rresp;
      readMastToSlaveDin(33 downto 2) <= mAxiReadSlave.rdata;

      -- Write control and ready generation
      mAxiReadMaster.rready <= ite(mAxiClkRst = '0', not readMastToSlaveAFull, '1');
      readMastToSlaveWrite  <= mAxiReadSlave.rvalid and (not readMastToSlaveAFull);

      -- Data Out
      sAxiReadSlave.rresp <= ite(m2sRst = '0', readMastToSlaveDout(1 downto 0), AXI_ERROR_RESP_G);
      sAxiReadSlave.rdata <= readMastToSlaveDout(33 downto 2);

      -- Read control and valid
      sAxiReadSlave.rvalid <= ite(m2sRst = '0', readMastToSlaveValid, '1');
      readMastToSlaveRead  <= sAxiReadMaster.rready;


      ------------------------------------
      -- Write Addr : Slave To Master
      ------------------------------------

      -- Write Addr Master To Slave FIFO
      U_WriteAddrSlaveToMastFifo : entity work.Fifo
         generic map (
            TPD_G           => TPD_G,
            SYNTH_MODE_G    => SYNTH_MODE_G,
            MEMORY_TYPE_G   => "distributed",
            GEN_SYNC_FIFO_G => false,
            FWFT_EN_G       => true,
            PIPE_STAGES_G   => PIPE_STAGES_G,
            DATA_WIDTH_G    => NUM_ADDR_BITS_G+3,
            ADDR_WIDTH_G    => 4)
         port map (
            rst         => s2mRst,
            wr_clk      => sAxiClk,
            wr_en       => writeAddrSlaveToMastWrite,
            din         => writeAddrSlaveToMastDin,
            almost_full => writeAddrSlaveToMastAFull,
            rd_clk      => mAxiClk,
            rd_en       => writeAddrSlaveToMastRead,
            dout        => writeAddrSlaveToMastDout,
            valid       => writeAddrSlaveToMastValid);

      -- Data In
      writeAddrSlaveToMastDin(2 downto 0)                 <= sAxiWriteMaster.awprot;
      writeAddrSlaveToMastDin(NUM_ADDR_BITS_G+2 downto 3) <= sAxiWriteMaster.awaddr(NUM_ADDR_BITS_G-1 downto 0);

      -- Write control and ready generation
      sAxiWriteSlave.awready    <= ite(m2sRst = '0', not writeAddrSlaveToMastAFull, '1');
      writeAddrSlaveToMastWrite <= sAxiWriteMaster.awvalid and (not writeAddrSlaveToMastAFull);

      -- Data Out
      mAxiWriteMaster.awprot <= writeAddrSlaveToMastDout(2 downto 0);

      process (writeAddrSlaveToMastDout)
      begin
         mAxiWriteMaster.awaddr                             <= (others => '0');
         mAxiWriteMaster.awaddr(NUM_ADDR_BITS_G-1 downto 0) <= writeAddrSlaveToMastDout(NUM_ADDR_BITS_G+2 downto 3);
      end process;

      -- Read control and valid
      mAxiWriteMaster.awvalid  <= writeAddrSlaveToMastValid;
      writeAddrSlaveToMastRead <= mAxiWriteSlave.awready;


      ------------------------------------
      -- Write Data : Slave to Master
      ------------------------------------

      -- Write Data Slave To Master FIFO
      U_WriteDataSlaveToMastFifo : entity work.Fifo
         generic map (
            TPD_G           => TPD_G,
            SYNTH_MODE_G    => SYNTH_MODE_G,
            MEMORY_TYPE_G   => "distributed",
            GEN_SYNC_FIFO_G => false,
            FWFT_EN_G       => true,
            PIPE_STAGES_G   => PIPE_STAGES_G,
            DATA_WIDTH_G    => 36,
            ADDR_WIDTH_G    => 4)
         port map (
            rst         => s2mRst,
            wr_clk      => sAxiClk,
            wr_en       => writeDataSlaveToMastWrite,
            din         => writeDataSlaveTomastDin,
            almost_full => writeDataSlaveToMastAFull,
            rd_clk      => mAxiClk,
            rd_en       => writeDataSlaveToMastRead,
            dout        => writeDataSlaveTomastDout,
            valid       => writeDataSlaveToMastValid);

      -- Data In
      writeDataSlaveToMastDin(3 downto 0)  <= sAxiWriteMaster.wstrb;
      writeDataSlaveToMastDin(35 downto 4) <= sAxiWriteMaster.wdata;

      -- Write control and ready generation
      sAxiWriteSlave.wready     <= ite(m2sRst = '0', not writeDataSlaveToMastAFull, '1');
      writeDataSlaveToMastWrite <= sAxiWriteMaster.wvalid and (not writeDataSlaveToMastAFull);

      -- Data Out
      mAxiWriteMaster.wstrb <= writeDataSlaveToMastDout(3 downto 0);
      mAxiWriteMaster.wdata <= writeDataSlaveToMastDout(35 downto 4);

      -- Read control and valid
      mAxiWriteMaster.wvalid   <= writeDataSlaveToMastValid;
      writeDataSlaveToMastRead <= mAxiWriteSlave.wready;


      ------------------------------------
      -- Write: Status Master To Slave
      ------------------------------------

      -- Write Status Master To Slave FIFO
      U_WriteMastToSlaveFifo : entity work.Fifo
         generic map (
            TPD_G           => TPD_G,
            SYNTH_MODE_G    => SYNTH_MODE_G,
            MEMORY_TYPE_G   => "distributed",
            GEN_SYNC_FIFO_G => false,
            FWFT_EN_G       => true,
            PIPE_STAGES_G   => PIPE_STAGES_G,
            DATA_WIDTH_G    => 2,
            ADDR_WIDTH_G    => 4)
         port map (
            rst         => m2sRst,
            wr_clk      => mAxiClk,
            wr_en       => writeMastToSlaveWrite,
            din         => writeMastToSlaveDin,
            almost_full => writeMastToSlaveAFull,
            rd_clk      => sAxiClk,
            rd_en       => writeMastToSlaveRead,
            dout        => writeMastToSlaveDout,
            valid       => writeMastToSlaveValid);

      -- Data In
      writeMastToSlaveDin <= mAxiWriteSlave.bresp;

      -- Write control and ready generation
      mAxiWriteMaster.bready <= not writeMastToSlaveAFull;
      writeMastToSlaveWrite  <= mAxiWriteSlave.bvalid and (not writeMastToSlaveAFull);

      -- Data Out
      sAxiWriteSlave.bresp <= ite(m2sRst = '0', writeMastToSlaveDout, AXI_ERROR_RESP_G);

      -- Read control and valid
      sAxiWriteSlave.bvalid <= ite(m2sRst = '0', writeMastToSlaveValid, '1');
      writeMastToSlaveRead  <= sAxiWriteMaster.bready;

   end generate;

end architecture STRUCTURE;
