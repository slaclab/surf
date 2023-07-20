-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- Byte packer for AXI-Stream.
-- Accepts an incoming stream and packs data into the outbound stream.
-- Similar to AxiStreamResize, but allows an input and output width to have
-- non multiples and for the input size to be dynamic.
-- This module does not downsize and creates more complex combinatorial logic
-- than in AxiStreamResize.
-- Ready handshaking is not supported.
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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;

entity AxiStreamBytePacker is
   generic (
      TPD_G           : time    := 1 ns;
      RST_ASYNC_G     : boolean := false;
      SLAVE_CONFIG_G  : AxiStreamConfigType;
      MASTER_CONFIG_G : AxiStreamConfigType);
   port (
      -- System clock and reset
      axiClk       : in  sl;
      axiRst       : in  sl;
      -- Inbound frame
      sAxisMaster  : in  AxiStreamMasterType;
      -- Outbound frame
      mAxisMaster  : out AxiStreamMasterType);
end AxiStreamBytePacker;

architecture rtl of AxiStreamBytePacker is

   constant SLV_TUSER_BITS_C : natural := ite(SLAVE_CONFIG_G.TUSER_BITS_C/=0,SLAVE_CONFIG_G.TUSER_BITS_C,1);

   constant MAX_IN_BYTE_C  : integer := SLAVE_CONFIG_G.TDATA_BYTES_C-1;
   constant MAX_OUT_BYTE_C : integer := MASTER_CONFIG_G.TDATA_BYTES_C-1;

   type RegType is record
      byteCount  : integer range 0 to MAX_OUT_BYTE_C;
      inTop      : integer range 0 to MAX_IN_BYTE_C;
      inMaster   : AxiStreamMasterType;
      curMaster  : AxiStreamMasterType;
      nxtMaster  : AxiStreamMasterType;
      outMaster  : AxiStreamMasterType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      byteCount  => 0,
      inTop      => 0,
      inMaster   => AXI_STREAM_MASTER_INIT_C,
      curMaster  => AXI_STREAM_MASTER_INIT_C,
      nxtMaster  => AXI_STREAM_MASTER_INIT_C,
      outMaster  => AXI_STREAM_MASTER_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- attribute MARK_DEBUG      : string;
   -- attribute MARK_DEBUG of r : signal is "TRUE";

begin

   comb : process (r, axiRst, sAxisMaster ) is
      variable v     : RegType;
      variable valid : sl;
      variable last  : sl;
      variable user  : slv(SLV_TUSER_BITS_C-1 downto 0);
      variable data  : slv(7 downto 0);
   begin
      v := r;

      -- Register input and compute size
      v.inMaster := sAxisMaster;
      v.inTop    := getTKeep(sAxisMaster.tKeep(MAX_IN_BYTE_C downto 0),SLAVE_CONFIG_G)-1;

      -- Pending output from current
      if r.curMaster.tValid = '1' then
         v.outMaster := r.curMaster;
         v.curMaster := r.nxtMaster;
         v.nxtMaster := AXI_STREAM_MASTER_INIT_C;
         v.nxtMaster.tKeep := (others=>'0');
      else
         v.outMaster := AXI_STREAM_MASTER_INIT_C;
      end if;

      -- Data is valid
      if r.inMaster.tValid = '1' then

         -- Process each input byte
         for i in 0 to MAX_IN_BYTE_C loop
            if i <= r.inTop then

               -- Extract values for each iteration
               last  := r.inMaster.tLast and toSl(i=r.inTop);
               valid := toSl(v.byteCount = MAX_OUT_BYTE_C) or last;
               user  := axiStreamGetUserField ( SLAVE_CONFIG_G, r.inMaster, i );
               data  := r.inMaster.tData(i*8+7 downto i*8);

               -- Still filling current data
               if v.curMaster.tValid = '0' then

                  v.curMaster.tData(v.byteCount*8+7 downto v.byteCount*8) := data;
                  v.curMaster.tKeep(v.byteCount) := '1';
                  v.curMaster.tValid := valid;
                  v.curMaster.tLast  := last;

                  -- Copy user field
                  axiStreamSetUserField( MASTER_CONFIG_G, v.curMaster, user, v.ByteCount);

               -- Filling next data
               elsif v.nxtMaster.tValid = '0' then

                  v.nxtMaster.tData(v.byteCount*8+7 downto v.byteCount*8) := data;
                  v.nxtMaster.tKeep(v.byteCount) := '1';
                  v.nxtMaster.tValid := valid;
                  v.nxtMaster.tLast  := last;

                  -- Copy user field
                  axiStreamSetUserField( MASTER_CONFIG_G, v.nxtMaster, user, v.ByteCount);

               end if;

               if v.byteCount = MAX_OUT_BYTE_C or last = '1' then
                  v.byteCount := 0;
               else
                  v.byteCount := v.byteCount + 1;
               end if;
            end if;
         end loop;
      end if;

      -- Reset
      if (RST_ASYNC_G = false and axiRst = '1') then
         v := REG_INIT_C;
         v.curMaster.tKeep := (others=>'0');
         v.nxtMaster.tKeep := (others=>'0');
      end if;

      rin <= v;

      mAxisMaster <= r.outMaster;

   end process;

   seq : process (axiClk, axiRst) is
   begin
      if (RST_ASYNC_G and axiRst = '1') then
         r <= REG_INIT_C after TPD_G;
      elsif rising_edge(axiClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
