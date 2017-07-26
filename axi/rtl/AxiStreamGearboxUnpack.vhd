-------------------------------------------------------------------------------
-- File       : AxiStreamGearboxUnpack.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-09-26
-------------------------------------------------------------------------------
-- Description: Takes 8 80-bit (5x16) ADC frames and reformats them into
--              7 80 bit (5x14) frames.
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
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

entity AxiStreamGearboxUnpack is
   
   generic (
      TPD_G               : time := 1 ns;
      AXI_STREAM_CONFIG_G : AxiStreamConfigType := AXI_STREAM_CONFIG_INIT_C;
      RANGE_HIGH_G        : integer := 119;
      RANGE_LOW_G         : integer := 8);
--      PACK_SIZE_G         : integer);
   port (
      axisClk : in sl;
      axisRst : in sl;

      packedAxisMaster : in  AxiStreamMasterType;
      packedAxisSlave  : out AxiStreamSlaveType;
      packedAxisCtrl   : out AxiStreamCtrlType;

      rawAxisMaster : out AxiStreamMasterType;
      rawAxisSlave  : in  AxiStreamSlaveType;
      rawAxisCtrl   : in  AxiStreamCtrlType

      );

end entity AxiStreamGearboxUnpack;

architecture rtl of AxiStreamGearboxUnpack is
   
   constant STREAM_WIDTH_C    : integer                           := AXI_STREAM_CONFIG_G.TDATA_BYTES_C*8;
   constant PACK_SIZE_C       : integer                           := RANGE_HIGH_G-RANGE_LOW_G+1;
   constant SIZE_DIFFERENCE_C : integer                           := STREAM_WIDTH_C-PACK_SIZE_C;
   constant ZERO_C            : slv(SIZE_DIFFERENCE_C-1 downto 0) := slvZero(SIZE_DIFFERENCE_C);

   type RegType is record
      packedSsiSlave : SsiSlaveType;
      rawSsiMaster   : SsiMasterType;
      data           : slv(STREAM_WIDTH_C*2-1 downto 0);
      splitIndex     : slv(log2(STREAM_WIDTH_C)-1 downto 0);
      eof            : sl;
      eofe           : sl;
      doLast         : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      packedSsiSlave => ssiSlaveInit(AXI_STREAM_CONFIG_G),
      rawSsiMaster   => ssiMasterInit(AXI_STREAM_CONFIG_G),
      data           => (others => '0'),
      splitIndex     => (others => '0'),
      eof            => '0',
      eofe           => '0',
      doLast         => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal rawSsiSlave     : SsiSlaveType;
   signal packedSsiMaster : SsiMasterType;

   signal locRawAxisMaster : AxiStreamMasterType;
   signal locRawAxisSlave  : AxiStreamSlaveType;
   signal locRawAxisCtrl   : AxiStreamCtrlType;

begin

   -- Convert AXI-Stream signals to SSI
   packedSsiMaster <= axis2ssiMaster(AXI_STREAM_CONFIG_G, packedAxisMaster);
   rawSsiSlave     <= axis2ssiSlave(AXI_STREAM_CONFIG_G, locRawAxisSlave, locRawAxisCtrl);

   comb : process (axisRst, packedSsiMaster, r) is
      variable v             : RegType;
      variable splitIndexInt : integer;
      variable shiftIndexInt : integer;
      variable wrData        : slv(STREAM_WIDTH_C+SIZE_DIFFERENCE_C-1 downto 0);
   begin
      v := r;

      v.rawSsiMaster.sof   := '0';
      v.rawSsiMaster.eof   := '0';
      v.rawSsiMaster.eofe  := '0';
      v.rawSsiMaster.valid := '0';

      v.packedSsiSlave.ready    := '1';
      v.packedSsiSlave.pause    := '0';
      v.packedSsiSlave.overflow := '0';


      if (packedSsiMaster.valid = '1' and r.packedSsiSlave.ready = '1') then
         -- Shift leftover data from last txn down to the right for output
         v.data(STREAM_WIDTH_C-1 downto 0) := r.data(STREAM_WIDTH_C*2-1 downto STREAM_WIDTH_C);
         v.doLast                          := '1';

         if (packedSsiMaster.sof = '1') then
            -- SOF txns are not packed. Just send the input data straight out.
            v.data                            := (others => '0');
            v.data(STREAM_WIDTH_C-1 downto 0) := packedSsiMaster.data(STREAM_WIDTH_C-1 downto 0);
            v.rawSsiMaster.valid              := '1';
            v.rawSsiMaster.sof                := '1';
            v.splitIndex                      := (others => '0');
            v.splitIndex                      := v.splitIndex-SIZE_DIFFERENCE_C;

         else
            -- Each incomming txn contains part of the data from two outgoing txns.
            -- First we find the split index.
            -- On the first txn the split index is at STREAM_WIDTH_C-SIZE_DIFFERENCE_C.
            -- It then decrements by SIZE_DIFFERENCE_C on each subsequent txn.
--            splitIndexInt := STREAM_WIDTH_C - (conv_integer(r.seqNum)+1)*SIZE_DIFFERENCE_C;
            splitIndexInt := conv_integer(r.splitIndex);
            v.splitIndex  := r.splitIndex - SIZE_DIFFERENCE_C;

            -- Insert SIZE_DIFFERENCE_C zeros at the split index. Store in temporary variable.
            -- This is how it should look:
            -- wrData := packedSsiMaster.data(STREAM_WIDTH_C-1 downto zeroIndex) &
            --           ZERO_C & packedSsiMaster.data(splitIndexInt downto 0);
            -- But Vivado can't synthesize it that way, so we do this hack:
            wrData := (others => '0');
            wrData(STREAM_WIDTH_C+SIZE_DIFFERENCE_C-1 downto SIZE_DIFFERENCE_C) :=
               packedSsiMaster.data(STREAM_WIDTH_C-1 downto 0);
            wrData(splitIndexInt+SIZE_DIFFERENCE_C-1 downto splitIndexInt) :=
               ZERO_C;
            wrData(splitIndexInt-1 downto 0) :=
               packedSsiMaster.data(splitIndexInt-1 downto 0);


            -- Leftover bits from the previous txn have already by shifted to the far right of v.data.
            -- We don't want to overwrite these, so we assign our zero filled value to v.data with the proper
            -- offset to avoid doing so.
            shiftIndexInt := PACK_SIZE_C-splitIndexInt;

            v.data(shiftIndexInt + STREAM_WIDTH_C+SIZE_DIFFERENCE_C - 1 downto shiftIndexInt) := wrData;

            -- Now shift the output segment by RANGE_LOW_G to recover LSB zeros
            v.data(STREAM_WIDTH_C-1 downto 0) := v.data(STREAM_WIDTH_C-RANGE_LOW_G-1 downto 0) & slvZero(RANGE_LOW_G);

            -- Assert valid and pass any eof through
            v.rawSsiMaster.valid := '1';
            v.rawSsiMaster.eof   := packedSsiMaster.eof;
            v.rawSsiMaster.eofe  := packedSsiMaster.eofe;

            if (r.splitIndex = SIZE_DIFFERENCE_C) then
               -- This is the last txn of a group.
               -- Don't output eof yet, as we want it to go out with the 'extra' output txn.
               v.packedSsiSlave.ready := '0';
               v.rawSsiMaster.eof     := '0';
               v.rawSsiMaster.eofe    := '0';
               v.eof                  := packedSsiMaster.eof;
               v.eofe                 := packedSsiMaster.eofe;
            end if;

         end if;
      end if;

      if (r.splitIndex = 0 and r.doLast = '1') then
         -- When split index reaches zero, we have received all txns in a group
         -- We now have an extra txn that must be shifted out.
         v.data(STREAM_WIDTH_C-1 downto 0) := r.data(STREAM_WIDTH_C*2-RANGE_LOW_G-1 downto STREAM_WIDTH_C) & slvZero(RANGE_LOW_G);
         v.rawSsiMaster.valid              := '1';
         v.rawSsiMaster.eof                := r.eof;
         v.rawSsiMaster.eofe               := r.eofe;
         v.eof                             := '0';
         v.eofe                            := '0';
         v.doLast                          := '0';
         v.splitIndex                      := r.splitIndex - SIZE_DIFFERENCE_C;
      end if;

      -- Assign v.data to rawSsiMaster
      -- Synthesis will merge the r.data registers with r.rawSsiMaster.data
      v.rawSsiMaster.data(STREAM_WIDTH_C -1 downto 0) := v.data(STREAM_WIDTH_C-1 downto 0);


      ----------------------------------------------------------------------------------------------
      -- Reset
      ----------------------------------------------------------------------------------------------
      if (axisRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      ----------------------------------------------------------------------------------------------
      -- Outputs
      ----------------------------------------------------------------------------------------------
      locRawAxisMaster <= ssi2AxisMaster(AXI_STREAM_CONFIG_G, r.rawSsiMaster);
      packedAxisSlave  <= ssi2AxisSlave(r.packedSsiSlave);
      packedAxisCtrl   <= ssi2AxisCtrl(r.packedSsiSlave);

   end process comb;

   seq : process (axisClk) is
   begin
      if (rising_edge(axisClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   rawAxisMaster   <= locRawAxisMaster;
   locRawAxisSlave <= rawAxisSlave;
   locRawAxisCtrl  <= rawAxisCtrl;

   -- Could probably get rid of this
--   AxiStreamFifo_1 : entity work.AxiStreamFifoV2
--      generic map (
--         TPD_G               => TPD_G,
--         BRAM_EN_G           => false,
--         GEN_SYNC_FIFO_G     => true,
--         FIFO_ADDR_WIDTH_G   => 4,
--         FIFO_FIXED_THRESH_G => true,
--         FIFO_PAUSE_THRESH_G => 15,
--         SLAVE_AXI_CONFIG_G  => AXI_STREAM_CONFIG_G,
--         MASTER_AXI_CONFIG_G => AXI_STREAM_CONFIG_G)
--      port map (
--         sAxisClk    => axisClk,
--         sAxisRst    => axisRst,
--         sAxisMaster => locRawAxisMaster,
--         sAxisSlave  => locRawAxisSlave,
--         sAxisCtrl   => locRawAxisCtrl,
--         mAxisClk    => axisClk,
--         mAxisRst    => axisRst,
--         mAxisMaster => rawAxisMaster,
--         mAxisSlave  => rawAxisSlave);

end architecture rtl;
