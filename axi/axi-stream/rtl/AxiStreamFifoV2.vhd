-------------------------------------------------------------------------------
-- File       : AxiStreamFifoV2.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-09-02
-- Last update: 2016-11-30
-------------------------------------------------------------------------------
-- Description:
-- Block to serve as an async FIFO for AXI Streams. This block also allows the
-- bus to be compress/expanded, allowing different standard sizes on each side
-- of the FIFO. Re-sizing is always little endian. 
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
use work.AxiStreamPkg.all;

entity AxiStreamFifoV2 is
   generic (

      -- General Configurations
      TPD_G             : time                  := 1 ns;
      INT_PIPE_STAGES_G : natural range 0 to 16 := 0;  -- Internal FIFO setting
      PIPE_STAGES_G     : natural range 0 to 16 := 1;
      SLAVE_READY_EN_G  : boolean               := true;

      -- Valid threshold should always be 1 when using interleaved tdest
      VALID_THOLD_G       : integer range 0 to (2**24) := 1;      -- =1 = normal operation
                                                                  -- =0 = only when frame ready
                                                                  -- >1 = only when frame ready or # entries
      VALID_BURST_MODE_G  : boolean                    := false;  -- only used in VALID_THOLD_G>1
      -- FIFO configurations
      BRAM_EN_G           : boolean                    := true;
      XIL_DEVICE_G        : string                     := "7SERIES";
      USE_BUILT_IN_G      : boolean                    := false;
      GEN_SYNC_FIFO_G     : boolean                    := false;
      ALTERA_SYN_G        : boolean                    := false;
      ALTERA_RAM_G        : string                     := "M9K";
      CASCADE_SIZE_G      : integer range 1 to (2**24) := 1;
      FIFO_ADDR_WIDTH_G   : integer range 4 to 48      := 9;
      FIFO_FIXED_THRESH_G : boolean                    := true;
      FIFO_PAUSE_THRESH_G : integer range 1 to (2**24) := 1;

      -- Internal FIFO width select, "WIDE", "NARROW" or "CUSTOM"
      -- WIDE uses wider of slave / master. NARROW  uses narrower.
      -- CUSOTM uses passed FIFO_DATA_WIDTH_G
      INT_WIDTH_SELECT_G : string                := "WIDE";
      INT_DATA_WIDTH_G   : natural range 1 to 16 := 16;

      -- If VALID_THOLD_G /=1, FIFO that stores on tLast txns can be smaller.
      -- Set to 0 for same size as primary fifo (default)
      -- Set >4 for custom size.
      -- Use at own risk. Overflow of tLast fifo is not checked      
      LAST_FIFO_ADDR_WIDTH_G : integer range 0 to 48 := 0;

      -- Index = 0 is output, index = n is input
      CASCADE_PAUSE_SEL_G : integer range 0 to (2**24) := 0;

      -- AXI Stream Port Configurations
      SLAVE_AXI_CONFIG_G  : AxiStreamConfigType := AXI_STREAM_CONFIG_INIT_C;
      MASTER_AXI_CONFIG_G : AxiStreamConfigType := AXI_STREAM_CONFIG_INIT_C
      );
   port (

      -- Slave Port
      sAxisClk    : in  sl;
      sAxisRst    : in  sl;
      sAxisMaster : in  AxiStreamMasterType;
      sAxisSlave  : out AxiStreamSlaveType;
      sAxisCtrl   : out AxiStreamCtrlType;

      -- FIFO status & config , synchronous to sAxisClk, be carefull when using with
      -- output pipeline stages
      fifoPauseThresh : in slv(FIFO_ADDR_WIDTH_G-1 downto 0) := (others => '1');

      -- Master Port
      mAxisClk    : in  sl;
      mAxisRst    : in  sl;
      mAxisMaster : out AxiStreamMasterType;
      mAxisSlave  : in  AxiStreamSlaveType;
      mTLastTUser : out slv(7 downto 0));  -- when VALID_THOLD_G /= 1, used to look ahead at tLast's tUser
end AxiStreamFifoV2;

architecture rtl of AxiStreamFifoV2 is

   constant LAST_FIFO_ADDR_WIDTH_C : integer range 4 to 48 :=
      ite(LAST_FIFO_ADDR_WIDTH_G < 4, FIFO_ADDR_WIDTH_G, LAST_FIFO_ADDR_WIDTH_G);

   -- Generate configuration for FIFO
   constant FIFO_CONFIG_C : AxiStreamConfigType := (

      -- Enable strobe only if used on both sides
      TSTRB_EN_C => SLAVE_AXI_CONFIG_G.TSTRB_EN_C and MASTER_AXI_CONFIG_G.TSTRB_EN_C,

      -- Determine FIFO data bytes
      TDATA_BYTES_C => ite(INT_WIDTH_SELECT_G = "CUSTOM", INT_DATA_WIDTH_G,
                           ite(INT_WIDTH_SELECT_G = "WIDE",

                               -- Using wider of the two
                               ite(SLAVE_AXI_CONFIG_G.TDATA_BYTES_C > MASTER_AXI_CONFIG_G.TDATA_BYTES_C,
                                   SLAVE_AXI_CONFIG_G.TDATA_BYTES_C, MASTER_AXI_CONFIG_G.TDATA_BYTES_C),

                               -- Use narrower of the two
                               ite(SLAVE_AXI_CONFIG_G.TDATA_BYTES_C > MASTER_AXI_CONFIG_G.TDATA_BYTES_C,
                                   MASTER_AXI_CONFIG_G.TDATA_BYTES_C, SLAVE_AXI_CONFIG_G.TDATA_BYTES_C))),

      -- Use the lesser of the two DEST widths
      TDEST_BITS_C => ite(SLAVE_AXI_CONFIG_G.TDEST_BITS_C > MASTER_AXI_CONFIG_G.TDEST_BITS_C,
                          MASTER_AXI_CONFIG_G.TDEST_BITS_C, SLAVE_AXI_CONFIG_G.TDEST_BITS_C),

      -- Use the lesser of the two ID widths
      TID_BITS_C => ite(SLAVE_AXI_CONFIG_G.TID_BITS_C > MASTER_AXI_CONFIG_G.TID_BITS_C,
                        MASTER_AXI_CONFIG_G.TID_BITS_C, SLAVE_AXI_CONFIG_G.TID_BITS_C),

      -- Use the lesser of the two USER widths
      TUSER_BITS_C => ite(SLAVE_AXI_CONFIG_G.TUSER_BITS_C > MASTER_AXI_CONFIG_G.TUSER_BITS_C,
                          MASTER_AXI_CONFIG_G.TUSER_BITS_C, SLAVE_AXI_CONFIG_G.TUSER_BITS_C),

      -- Use slave settings for tkeep and tuser mode
      TKEEP_MODE_C => SLAVE_AXI_CONFIG_G.TKEEP_MODE_C,
      TUSER_MODE_C => SLAVE_AXI_CONFIG_G.TUSER_MODE_C);

   constant FIFO_BITS_C : integer := getSlvSize(FIFO_CONFIG_C);

   constant FIFO_USER_BITS_C : integer := FIFO_CONFIG_C.TUSER_BITS_C;

   ----------------
   -- FIFO Signals
   ----------------

   signal fifoWriteMaster : AxiStreamMasterType;
   signal fifoWriteSlave  : AxiStreamSlaveType;
   signal fifoReadMaster  : AxiStreamMasterType;
   signal fifoReadSlave   : AxiStreamSlaveType;
   signal fifoDin         : slv(FIFO_BITS_C-1 downto 0);
   signal fifoWrite       : sl;
   signal fifoWriteLast   : sl;
   signal fifoWriteUser   : slv(maximum(FIFO_USER_BITS_C-1, 0) downto 0);
   signal fifoWrCount     : slv(FIFO_ADDR_WIDTH_G-1 downto 0);
   signal fifoRdCount     : slv(FIFO_ADDR_WIDTH_G-1 downto 0);
   signal fifoAFull       : sl;
   signal fifoReady       : sl;
   signal fifoPFull       : sl;
   signal fifoPFullVec    : slv(CASCADE_SIZE_G-1 downto 0);
   signal fifoDout        : slv(FIFO_BITS_C-1 downto 0);
   signal fifoRead        : sl;
   signal fifoReadLast    : sl;
   signal fifoReadUser    : slv(maximum(FIFO_USER_BITS_C-1, 0) downto 0);
   signal fifoValidInt    : sl;
   signal fifoValid       : sl;
   signal fifoValidLast   : sl;
   signal fifoInFrame     : sl;

   signal burstEn   : sl;
   signal burstLast : sl;
   signal burstCnt  : natural range 0 to VALID_THOLD_G := 0;

   ---------------
   -- Sync Signals
   ---------------
   signal axisMaster : AxiStreamMasterType;
   signal axisSlave  : AxiStreamSlaveType;

begin

   -- Cant use tkeep_fixed on master side when resizing or if not on slave side
   assert (not (MASTER_AXI_CONFIG_G.TKEEP_MODE_C = TKEEP_FIXED_C and
                SLAVE_AXI_CONFIG_G.TKEEP_MODE_C /= TKEEP_FIXED_C))
      report "AxiStreamFifoV2: Can't have TKEEP_MODE = TKEEP_FIXED on master side if not on slave side"
      severity error;

   -------------------------
   -- Slave Resize
   -------------------------
   U_SlaveResize : entity work.AxiStreamResize
      generic map (
         TPD_G               => TPD_G,
         READY_EN_G          => SLAVE_READY_EN_G,
         SLAVE_AXI_CONFIG_G  => SLAVE_AXI_CONFIG_G,
         MASTER_AXI_CONFIG_G => FIFO_CONFIG_C) 
         port map (
            axisClk     => sAxisClk,
            axisRst     => sAxisRst,
            sAxisMaster => sAxisMaster,
            sAxisSlave  => sAxisSlave,
            mAxisMaster => fifoWriteMaster,
            mAxisSlave  => fifoWriteSlave);

   -------------------------
   -- FIFO
   -------------------------

   -- Pause generation
   process (fifoPFullVec, sAxisClk) is
   begin
      if FIFO_FIXED_THRESH_G then
         sAxisCtrl.pause <= fifoPFullVec(CASCADE_PAUSE_SEL_G) after TPD_G;
      elsif (rising_edge(sAxisClk)) then
         if sAxisRst = '1' or fifoWrCount >= fifoPauseThresh then
            sAxisCtrl.pause <= '1' after TPD_G;
         else
            sAxisCtrl.pause <= '0' after TPD_G;
         end if;
      end if;
   end process;

   -- Is ready enabled?
   fifoReady <= (not fifoAFull) when SLAVE_READY_EN_G else '1';

   -- Map bits
   fifoDin       <= toSlv(fifoWriteMaster, FIFO_CONFIG_C);
   fifoWrite     <= fifoWriteMaster.tValid and fifoReady;
   fifoWriteLast <= fifoWriteMaster.tValid and fifoReady and fifoWriteMaster.tLast;
   fifoWriteUser <= ite(FIFO_USER_BITS_C > 0,
                        resize(axiStreamGetUserField(FIFO_CONFIG_C, fifoWriteMaster, -1), FIFO_USER_BITS_C),
                        "0");

   fifoWriteSlave.tReady <= fifoReady;

   U_Fifo : entity work.FifoCascade
      generic map (
         TPD_G              => TPD_G,
         CASCADE_SIZE_G     => CASCADE_SIZE_G,
         LAST_STAGE_ASYNC_G => true,
         PIPE_STAGES_G      => INT_PIPE_STAGES_G,
         RST_POLARITY_G     => '1',
         RST_ASYNC_G        => false,
         GEN_SYNC_FIFO_G    => GEN_SYNC_FIFO_G,
         BRAM_EN_G          => BRAM_EN_G,
         FWFT_EN_G          => true,
         USE_DSP48_G        => "no",
         ALTERA_SYN_G       => ALTERA_SYN_G,
         ALTERA_RAM_G       => ALTERA_RAM_G,
         USE_BUILT_IN_G     => USE_BUILT_IN_G,
         XIL_DEVICE_G       => XIL_DEVICE_G,
         SYNC_STAGES_G      => 3,
         DATA_WIDTH_G       => FIFO_BITS_C,
         ADDR_WIDTH_G       => FIFO_ADDR_WIDTH_G,
         INIT_G             => "0",
         FULL_THRES_G       => FIFO_PAUSE_THRESH_G,
         EMPTY_THRES_G      => 1)
      port map (
         rst           => sAxisRst,
         wr_clk        => sAxisClk,
         wr_en         => fifoWrite,
         din           => fifoDin,
         wr_data_count => fifoWrCount,
         overflow      => sAxisCtrl.overflow,
         prog_full     => fifoPFull,
         progFullVec   => fifoPFullVec,
         almost_full   => fifoAFull,
         rd_clk        => mAxisClk,
         rd_en         => fifoRead,
         dout          => fifoDout,
         rd_data_count => fifoRdCount,
         valid         => fifoValidInt);

   U_LastFifoEnGen : if VALID_THOLD_G /= 1 generate

      U_LastFifo : entity work.FifoCascade
         generic map (
            TPD_G              => TPD_G,
            CASCADE_SIZE_G     => CASCADE_SIZE_G,
            LAST_STAGE_ASYNC_G => true,
            PIPE_STAGES_G      => INT_PIPE_STAGES_G,
            RST_POLARITY_G     => '1',
            RST_ASYNC_G        => false,
            GEN_SYNC_FIFO_G    => GEN_SYNC_FIFO_G,
            BRAM_EN_G          => false,
            FWFT_EN_G          => true,
            USE_DSP48_G        => "no",
            ALTERA_SYN_G       => ALTERA_SYN_G,
            ALTERA_RAM_G       => ALTERA_RAM_G,
            USE_BUILT_IN_G     => false,
            XIL_DEVICE_G       => XIL_DEVICE_G,
            SYNC_STAGES_G      => 3,
            DATA_WIDTH_G       => maximum(FIFO_USER_BITS_C, 1),
            ADDR_WIDTH_G       => LAST_FIFO_ADDR_WIDTH_C,
            INIT_G             => "0",
            FULL_THRES_G       => 1,
            EMPTY_THRES_G      => 1)
         port map (
            rst    => sAxisRst,
            wr_clk => sAxisClk,
            wr_en  => fifoWriteLast,
            din    => fifoWriteUser,
            rd_clk => mAxisClk,
            rd_en  => fifoReadLast,
            dout   => fifoReadUser,
            valid  => fifoValidLast);

      U_PreFillMode : if ((VALID_BURST_MODE_G = false) or (VALID_THOLD_G = 0)) generate
         
         process (mAxisClk) is
         begin
            if (rising_edge(mAxisClk)) then

               -- Stop output if fifo valid goes away, wait until another block is ready
               if mAxisRst = '1' or fifoReadLast = '1' or fifoValidInt = '0' then
                  fifoInFrame <= '0' after TPD_G;

               -- Start output when a block or end of frame is available
               elsif fifoValidLast = '1' or (VALID_THOLD_G /= 0 and fifoRdCount >= VALID_THOLD_G) then
                  fifoInFrame <= '1' after TPD_G;
               end if;
            end if;
         end process;

      end generate;

      U_BurstMode : if ((VALID_BURST_MODE_G = true) and (VALID_THOLD_G /= 0)) generate
         
         process (mAxisClk) is
         begin
            if (rising_edge(mAxisClk)) then
               if (mAxisRst = '1') or (fifoReadLast = '1') then
                  -- Reset the flags
                  fifoInFrame <= '0' after TPD_G;
                  burstEn     <= '0' after TPD_G;
                  burstLast   <= '0' after TPD_G;
               else
                  -- Check if for burst mode
                  if (burstEn = '1') and (burstLast = '0') and (fifoRead = '1') then
                     -- Increment the counter
                     burstCnt <= burstCnt + 1 after TPD_G;
                     -- Check the counter
                     if burstCnt = (VALID_THOLD_G-1) then
                        -- Reset the flags
                        fifoInFrame <= '0' after TPD_G;
                        burstEn     <= '0' after TPD_G;
                     end if;
                  end if;
                  if (fifoValidLast = '1') or ((fifoRdCount >= VALID_THOLD_G) and (burstEn = '0')) then
                     -- Set the flags
                     burstEn     <= '1'           after TPD_G;
                     burstLast   <= fifoValidLast after TPD_G;
                     fifoInFrame <= '1'           after TPD_G;
                     -- Reset the counter
                     burstCnt    <= 0             after TPD_G;
                  end if;
               end if;
            end if;
         end process;
         
      end generate;

      fifoValid <= fifoValidInt and fifoInFrame;
      
   end generate;

   U_LastFifoDisGen : if VALID_THOLD_G = 1 generate
      fifoValidLast <= '0';
      fifoInFrame   <= '0';
      fifoReadUser  <= (others => '0');
      fifoValid     <= fifoValidInt;
   end generate;

   mTLastTUser <= resize(fifoReadUser, 8);

   -- Map output Signals
   fifoReadMaster <= toAxiStreamMaster (fifoDout, fifoValid, FIFO_CONFIG_C);

   fifoRead     <= fifoReadSlave.tReady and fifoValid;
   fifoReadLast <= fifoReadSlave.tReady and fifoValid and fifoReadMaster.tLast;

   -------------------------
   -- Master Resize
   -------------------------
   U_MasterResize : entity work.AxiStreamResize
      generic map (
         TPD_G               => TPD_G,
         READY_EN_G          => true,
         SLAVE_AXI_CONFIG_G  => FIFO_CONFIG_C,
         MASTER_AXI_CONFIG_G => MASTER_AXI_CONFIG_G) 
      port map (
            axisClk     => mAxisClk,
            axisRst     => mAxisRst,
            sAxisMaster => fifoReadMaster,
            sAxisSlave  => fifoReadSlave,
            mAxisMaster => axisMaster,
            mAxisSlave  => axisSlave);

   -------------------------
   -- Idle Generation
   -------------------------
   -- Synchronize master side tvalid back to slave side ctrl.idle
   -- This is a total hack
   Synchronizer_1 : entity work.Synchronizer
      generic map (
         TPD_G          => TPD_G,
         OUT_POLARITY_G => '0')         -- invert
      port map (
         clk     => sAxisClk,
         rst     => sAxisRst,
         dataIn  => axisMaster.tValid,
         dataOut => sAxisCtrl.idle);

   -------------------------
   -- Pipeline Logic
   -------------------------

   U_Pipe : entity work.AxiStreamPipeline
      generic map (
         TPD_G         => TPD_G,
         PIPE_STAGES_G => PIPE_STAGES_G)
      port map (
         -- Clock and Reset
         axisClk     => mAxisClk,
         axisRst     => mAxisRst,
         -- Slave Port
         sAxisMaster => axisMaster,
         sAxisSlave  => axisSlave,
         -- Master Port
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);

end rtl;

