-------------------------------------------------------------------------------
-- File       : AxiStreamScatterGather.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-03-01
-- Last update: 2015-04-08
-------------------------------------------------------------------------------
-- Description: Takes 6 APV bursts with 128 channels of data each and
-- transforms them into 128 "MultiSamples" with 6 samples each.
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
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

entity AxiStreamScatterGather is
   
   generic (
      TPD_G                   : time                := 1 ns;
      AXIS_SLAVE_FRAME_SIZE_G : integer             := 129;
      SLAVE_AXIS_CONFIG_G     : AxiStreamConfigType := ssiAxiStreamConfig(2);
      MASTER_AXIS_CONFIG_G    : AxiStreamConfigType := ssiAxiStreamConfig(12));
   port (
      -- Master system clock, 125Mhz
      axiClk : in sl;
      axiRst : in sl;

      -- (optional) Axi Bus for status and debug
      axilReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave  : out AxiLiteWriteSlaveType;

      -- Input data
      sAxisMaster : in  AxiStreamMasterType;
      sAxisSlave  : out AxiStreamSlaveType;
      sAxisCtrl   : out AxiStreamCtrlType;

--      longWordCount : out slv(7 downto 0);
--      badWordCount  : out slv(7 downto 0);
--      longWords     : out slv(15 downto 0);
--      badWords      : out slv(15 downto 0);

      -- Output data
      mAxisMaster : out AxiStreamMasterType;
      mAxisSlave  : in  AxiStreamSlaveType;
      mAxisCtrl   : in  AxiStreamCtrlType);

end entity AxiStreamScatterGather;

architecture rtl of AxiStreamScatterGather is

   constant SEQUENCE_LENGTH_C    : integer := MASTER_AXIS_CONFIG_G.TDATA_BYTES_C/SLAVE_AXIS_CONFIG_G.TDATA_BYTES_C;
   constant SLAVE_DATA_LENGTH_C  : integer := SLAVE_AXIS_CONFIG_G.TDATA_BYTES_C*8;
   constant MASTER_DATA_LENGTH_C : integer := MASTER_AXIS_CONFIG_G.TDATA_BYTES_C*8;

   constant RAM_DEPTH_RAW_C   : integer := AXIS_SLAVE_FRAME_SIZE_G * SEQUENCE_LENGTH_C * 2;
   constant RAM_ADDR_LENGTH_C : integer := bitSize(RAM_DEPTH_RAW_C);
   constant RAM_DEPTH_C       : integer := 2**RAM_ADDR_LENGTH_C;

   -------------------------------------------------------------------------------------------------
   -- RAM
   -------------------------------------------------------------------------------------------------
   type RamType is array (0 to RAM_DEPTH_C-1) of slv(SLAVE_DATA_LENGTH_C-1 downto 0);
   signal ram         : RamType;
   signal txRamRdData : slv(SLAVE_DATA_LENGTH_C-1 downto 0);

   signal txFifoRdData : sl;
   signal txFifoValid  : sl;

   --------------------------------------------------------------------------------------------------
   type RegType is record
      rxRamWrEn     : sl;
      rxRamWrData   : slv(SLAVE_DATA_LENGTH_C-1 downto 0);
      rxRamWrAddr   : slv(RAM_ADDR_LENGTH_C-1 downto 0);
      rxSofAddr     : slv(RAM_ADDR_LENGTH_C-1 downto 0);
      rxFifoWrEn    : sl;
      rxWordCount   : slv(bitSize(AXIS_SLAVE_FRAME_SIZE_G)-1 downto 0);
      rxFrameNumber : slv(bitSize(SEQUENCE_LENGTH_C-1)-1 downto 0);
      rxError       : sl;

      mSsiMaster    : SsiMasterType;
      txRamRdAddr   : slv(RAM_ADDR_LENGTH_C-1 downto 0);
      txRamRdEn     : sl;
      txFifoRdEn    : sl;
      txWordCount   : slv(bitSize(AXIS_SLAVE_FRAME_SIZE_G-1)-1 downto 0);
      txFrameNumber : slv(bitSize(SEQUENCE_LENGTH_C-1)-1 downto 0);
      txSof         : sl;

      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;

      longWordCount : slv(7 downto 0);
      longWords     : slv(15 downto 0);
      badWordCount  : slv(7 downto 0);
      badWords      : slv(15 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      rxRamWrEn     => '0',
      rxRamWrData   => (others => '0'),
      rxRamWrAddr   => (others => '0'),
      rxSofAddr     => (others => '0'),
      rxFifoWrEn    => '0',
      rxWordCount   => (others => '0'),
      rxFrameNumber => (others => '0'),
      rxError       => '0',

      mSsiMaster    => ssiMasterInit(MASTER_AXIS_CONFIG_G),
      txRamRdAddr   => (others => '0'),
      txRamRdEn     => '0',
      txFifoRdEn    => '0',
      txWordCount   => (others => '0'),
      txFrameNumber => (others => '0'),
      txSof         => '1',

      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,

      longWordCount => (others => '0'),
      badWordCount  => (others => '0'),
      longWords     => (others => '0'),
      badWords      => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal sSsiMaster : SsiMasterType;

begin

   -------------------------------------------------------------------------------------------------
   -- Infer a RAM
   -------------------------------------------------------------------------------------------------
   ramProc : process (axiClk) is
   begin
      if (rising_edge(axiClk)) then
         txRamRdData <= ram(conv_integer(r.txRamRdAddr)) after TPD_G;
         if (r.rxRamWrEn = '1') then
            ram(conv_integer(r.rxRamWrAddr)) <= r.rxRamWrData after TPD_G;
         end if;
      end if;
   end process ramProc;

   -------------------------------------------------------------------------------------------------
   -- Use fifo to indicate to TX side that a new frame is ready
   -------------------------------------------------------------------------------------------------
   StatusFifo : entity work.Fifo
      generic map (
         TPD_G           => TPD_G,
         GEN_SYNC_FIFO_G => true,
         BRAM_EN_G       => false,
         FWFT_EN_G       => true,
         USE_BUILT_IN_G  => false,
         DATA_WIDTH_G    => 1,
         ADDR_WIDTH_G    => 4)
      port map (
         rst     => axiRst,
         wr_clk  => axiClk,
         wr_en   => r.rxFifoWrEn,
         din(0)  => r.rxError,
         full    => open,
         rd_clk  => axiClk,
         rd_en   => r.txFifoRdEn,
         dout(0) => txFifoRdData,
         valid   => txFifoValid);

   sSsiMaster <= axis2SsiMaster(SLAVE_AXIS_CONFIG_G, sAxisMaster);
   sAxisCtrl  <= AXI_STREAM_CTRL_UNUSED_C;
   sAxisSlave <= AXI_STREAM_SLAVE_FORCE_C;

   comb : process (axiRst, axilReadMaster, axilWriteMaster, r, sSsiMaster, txFifoRdData,
                   txFifoValid, txRamRdData) is
      variable v          : RegType;
      variable mDataLow   : integer;
      variable mDataHigh  : integer;
      variable axilStatus : AxiLiteStatusType;
   begin
      v := r;

      ----------------------------------------------------------------------------------------------
      -- Rx logic
      ----------------------------------------------------------------------------------------------
      v.rxRamWrEn   := '0';
      v.rxRamWrData := sSsiMaster.data(SLAVE_DATA_LENGTH_C-1 downto 0);
      v.rxFifoWrEn  := '0';

      if (sSsiMaster.valid = '1') then
         -- Default - Write to RAM and increment wr addr by sequence length
         v.rxWordCount := r.rxWordCount + 1;
         v.rxRamWrAddr := r.rxRamWrAddr + SEQUENCE_LENGTH_C;
         v.rxRamWrEn   := '1';

         -- Protect against long frames by freezing wr addr
         if (r.rxWordCount = AXIS_SLAVE_FRAME_SIZE_G) then
            v.rxRamWrAddr                    := r.rxRamWrAddr;
            v.rxError                        := '1';
            v.longWordCount                  := r.longWordCount + 1;
            v.longWords(r.rxWordCount'range) := r.rxWordCount;
         end if;

         -- Log start address on each sof to easily come back to it + 1 on next frame
         if (sSsiMaster.sof = '1') then
            v.rxRamWrAddr := r.rxSofAddr;
         end if;

         if (sSsiMaster.eof = '1' or sSsiMaster.eofe = '1') then
            v.rxFrameNumber := r.rxFrameNumber + 1;
            v.rxWordCount   := (others => '0');
            v.rxError       := r.rxError or sSsiMaster.eofe;

            v.rxSofAddr := r.rxSofAddr + 1;

            -- Check for proper number of words
            if (r.rxWordCount /= AXIS_SLAVE_FRAME_SIZE_G-1) then
               v.rxError                       := '1';
               v.badWordCount                  := r.badWordCount + 1;
               v.badWords(r.rxWordCount'range) := r.rxWordCount;
            end if;

            -- Check for end of frame sequence
            if (r.rxFrameNumber = SEQUENCE_LENGTH_C-1) then
               v.rxFrameNumber := (others => '0');
               v.rxFifoWrEn    := '1';
               v.rxSofAddr     := r.rxSofAddr + ((AXIS_SLAVE_FRAME_SIZE_G*SEQUENCE_LENGTH_C) - (SEQUENCE_LENGTH_C-1));

--               v.rxFifoWrData(0) := v.rxError;  -- Use v because it could be set this cycle
            end if;
         end if;
      end if;
      
      if (r.rxFifoWrEn = '1') then
         -- Reset rx error after each write.
         -- Need to check timing on this.
         v.rxError := '0';
      end if;

      ----------------------------------------------------------------------------------------------
      -- TX logic
      ----------------------------------------------------------------------------------------------
      v.mSsiMaster.valid := '0';
      v.mSsiMaster.sof   := '0';
      v.mSsiMaster.eof   := '0';
      v.mSsiMaster.eofe  := '0';
      v.txFifoRdEn       := '0';
      v.txRamRdEn        := '0';

      if (txFifoValid = '1' and r.txFifoRdEn = '0') then

         v.txRamRdEn   := '1';
         v.txRamRdAddr := r.txRamRdAddr + 1;

         if (r.txRamRdEn = '1') then
            v.txFrameNumber := r.txFrameNumber + 1;

            mDataHigh := ((conv_integer(r.txFrameNumber) + 1) * SLAVE_DATA_LENGTH_C) - 1;
            mDataLow  := (conv_integer(r.txFrameNumber) * SLAVE_DATA_LENGTH_C);
            for i in 0 to SLAVE_DATA_LENGTH_C-1 loop
               v.mSsiMaster.data(i+mDataLow) := txRamRdData(i);
            end loop;

            if (r.txFrameNumber = SEQUENCE_LENGTH_C-1) then
               v.mSsiMaster.valid := '1';
               v.mSsiMaster.sof   := r.txSof;
               v.mSsiMaster.eofe  := r.txSof and txFifoRdData;  -- Assert eofe without eof to indicate sofe
               v.txSof            := '0';
               v.txFrameNumber    := (others => '0');
               v.txWordCount      := r.txWordCount + 1;
               if (r.txWordCount = AXIS_SLAVE_FRAME_SIZE_G-1) then
                  v.txWordCount     := (others => '0');
                  v.txFifoRdEn      := '1';
                  v.mSsiMaster.eof  := '1';
                  v.mSsiMaster.eofe := txFifoRdData;
                  v.txRamRdAddr     := r.txRamRdAddr;
                  v.txSof           := '1';
               end if;
            end if;
            
         end if;
         
      end if;


      ----------------------------------------------------------------------------------------------
      -- Do reset here so that AXI logic can't be reset
      ----------------------------------------------------------------------------------------------
      if (axiRst = '1') then
         v                := REG_INIT_C;
         v.axilWriteSlave := r.axilWriteSlave;
         v.axilReadSlave  := r.axilReadSlave;
      end if;

      ----------------------------------------------------------------------------------------------
      -- AXI Interface
      ----------------------------------------------------------------------------------------------
      axiSlaveWaitTxn(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axilStatus);

      if (axilStatus.writeEnable = '1') then
         axiSlaveWriteResponse(v.axilWriteSlave);
      end if;

      if (axilStatus.readEnable = '1') then
         -- Decode address and assign read data
         v.axilReadSlave.rdata := (others => '0');
         case axilReadMaster.araddr(7 downto 0) is
            when X"00" =>
               v.axilReadSlave.rdata(r.rxRamWrAddr'range) := r.rxRamWrAddr;
            when X"04" =>
               v.axilReadSlave.rdata(r.rxSofAddr'range) := r.rxSofAddr;
            when X"08" =>
               v.axilReadSlave.rdata(r.rxWordCount'range) := r.rxWordCount;
            when X"0C" =>
               v.axilReadSlave.rdata(r.rxFrameNumber'range) := r.rxFrameNumber;
               v.axilReadSlave.rdata(31)                    := r.rxError;

            when X"10" =>
               v.axilReadSlave.rdata(r.txRamRdAddr'range) := r.txRamRdAddr;
            when X"14" =>
               v.axilReadSlave.rdata(r.txWordCount'range) := r.txWordCount;
            when X"18" =>
               v.axilReadSlave.rdata(r.txFrameNumber'range) := r.txFrameNumber;
            when X"1C" =>
               v.axilReadSlave.rdata(r.longWords'range) := r.longWords;
            when X"20" =>
               v.axilReadSlave.rdata(r.longWordCount'range) := r.longWordCount;
            when X"24" =>
               v.axilReadSlave.rdata(r.badWords'range) := r.badWords;
            when X"28" =>
               v.axilReadSlave.rdata(r.badWordCount'range) := r.badWordCount;
               
            when others => null;
         end case;
         axiSlaveReadResponse(v.axilReadSlave);
      end if;

      ----------------------------------------------------------------------------------------------
      -- Reset 
      ----------------------------------------------------------------------------------------------
--      if (axiRst = '1') then
--         v := REG_INIT_C;
--      end if;

      ----------------------------------------------------------------------------------------------
      -- Outputs
      ----------------------------------------------------------------------------------------------

      rin <= v;

      mAxisMaster    <= ssi2AxisMaster(MASTER_AXIS_CONFIG_G, r.mSsiMaster);
      axilWriteSlave <= r.axilWriteSlave;
      axilReadSlave  <= r.axilReadSlave;

--      longWordCount <= r.longWordCount;
--      badWordCount  <= r.badWordCount;
--      longWords     <= r.longWords;
--      badWords      <= r.badWords;
   end process comb;



   sync : process (axiClk) is
   begin
      if (rising_edge(axiClk)) then
         r <= rin after TPD_G;
      end if;
   end process sync;


end architecture rtl;
