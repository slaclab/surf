-------------------------------------------------------------------------------
-- File       : AxiStreamGearboxPack
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-09-29
-- Last update: 2016-07-13
-------------------------------------------------------------------------------
-- Description: AXI stream Packer Module 
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

entity AxiStreamGearboxPack is
   
   generic (
      TPD_G               : time := 1 ns;
      AXI_STREAM_CONFIG_G : AxiStreamConfigType := SSI_CONFIG_INIT_C;
      RANGE_HIGH_G        : integer := 13;
      RANGE_LOW_G         : integer := 2);
   port (
      axisClk : in sl;
      axisRst : in sl;

      rawAxisMaster : in  AxiStreamMasterType;
      rawAxisSlave  : out AxiStreamSlaveType;
      rawAxisCtrl   : out AxiStreamCtrlType;

      packedAxisMaster : out AxiStreamMasterType;
      packedAxisSlave  : in  AxiStreamSlaveType;
      packedAxisCtrl   : in  AxiStreamCtrlType

      );

end entity AxiStreamGearboxPack;

architecture rtl of AxiStreamGearboxPack is


   constant STREAM_WIDTH_C    : integer := AXI_STREAM_CONFIG_G.TDATA_BYTES_C*8;
   constant PACK_SIZE_C       : integer := RANGE_HIGH_G-RANGE_LOW_G+1;
   constant SIZE_DIFFERENCE_C : integer := STREAM_WIDTH_C-PACK_SIZE_C;

   -- Vivado chokes if you try to calculate these on the fly inside the comb process.
   -- Precompute all of the assignment indicies instead
   function computeIndicies      return IntegerArray is
      variable ret : IntegerArray(0 to STREAM_WIDTH_C/SIZE_DIFFERENCE_C-1);
   begin
      for i in ret'range loop
         ret(i) := STREAM_WIDTH_C - (i*SIZE_DIFFERENCE_C);
      end loop;
      return ret;
   end function computeIndicies;

   constant ASSIGNMENT_INDECIES_C : IntegerArray := computeIndicies;

   type RegType is record
      packedSsiMaster : SsiMasterType;
      rawSsiSlave     : SsiSlaveType;
      data            : slv(STREAM_WIDTH_C*2-1 downto 0);
      index           : slv(log2(STREAM_WIDTH_C/SIZE_DIFFERENCE_C)-1 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      packedSsiMaster => ssiMasterInit(AXI_STREAM_CONFIG_G),
      rawSsiSlave     => ssiSlaveInit(AXI_STREAM_CONFIG_G),
      data            => (others => '0'),
      index           => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal rawSsiMaster   : SsiMasterType;
   signal packedSsiSlave : SsiSlaveType;

begin

   -- Convert AXI-Stream signals to SSI
   packedSsiSlave <= axis2ssiSlave(AXI_STREAM_CONFIG_G, packedAxisSlave, packedAxisCtrl);
   rawSsiMaster   <= axis2SsiMaster(AXI_STREAM_CONFIG_G, rawAxisMaster);

   comb : process (axisRst, r, rawSsiMaster) is
      variable v        : RegType;
      variable indexInt : integer;
   begin
      v := r;

      v.packedSsiMaster.sof   := '0';
      v.packedSsiMaster.eof   := '0';
      v.packedSsiMaster.eofe  := '0';
      v.packedSsiMaster.valid := '0';

      v.rawSsiSlave.ready    := '1';
      v.rawSsiSlave.pause    := '0';
      v.rawSsiSlave.overflow := '0';


      if (rawSsiMaster.valid = '1') then
         if (rawSsiMaster.sof = '1') then
            -- Frame header goes through unmodified
            v.data                            := (others => '0');
            v.data(STREAM_WIDTH_C-1 downto 0) := rawSsiMaster.data(STREAM_WIDTH_C-1 downto 0);
            v.packedSsiMaster.valid           := '1';
            v.packedSsiMaster.sof             := '1';
            v.index                           := (others => '0');

         else
            -- Pack all other txns
            v.packedSsiMaster.eof  := rawSsiMaster.eof;
            v.packedSsiMaster.eofe := rawSsiMaster.eofe;


            -- Shift the data over
            v.data(STREAM_WIDTH_C-1 downto 0) := r.data(STREAM_WIDTH_C*2-1 downto STREAM_WIDTH_C);

            -- Assign new data at proper index
            indexInt := ASSIGNMENT_INDECIES_C(conv_integer(r.index));
            v.data(indexInt+PACK_SIZE_C-1 downto indexInt) := rawSsiMaster.data(RANGE_HIGH_G downto RANGE_LOW_G);

            -- Disable write until we have enough data
--            v.packedSsiMaster.valid := toSl(indexInt+PACK_SIZE_C >= STREAM_WIDTH_C);
            v.packedSsiMaster.valid := toSl(r.index /= 0) or rawSsiMaster.eofe or rawSsiMaster.eof;


            -- Increment index
            v.index := r.index + 1;

            
         end if;
      end if;

      v.packedSsiMaster.data(STREAM_WIDTH_C-1 downto 0) := v.data(STREAM_WIDTH_C-1 downto 0);

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
      packedAxisMaster <= ssi2AxisMaster(AXI_STREAM_CONFIG_G, r.packedSsiMaster);
      rawAxisSlave     <= ssi2AxisSlave(r.rawSsiSlave);
      rawAxisCtrl      <= ssi2AxisCtrl(r.rawSsiSlave);

   end process comb;

   seq : process (axisClk) is
   begin
      if (rising_edge(axisClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
