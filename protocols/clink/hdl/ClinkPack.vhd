-------------------------------------------------------------------------------
-- File       : ClinkPack.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-11-13
-------------------------------------------------------------------------------
-- Description:
-- CameraLink data packer
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

entity ClinkPack is
   generic (
      TPD_G         : time                := 1 ns;
      AXIS_CONFIG_G : AxiStreamConfigType := AXI_STREAM_CONFIG_INIT_C);
   port (
      -- System clock and reset
      sysClk       : in  sl;
      sysRst       : in  sl;
      -- Inbound frame
      sAxisMaster  : in  AxiStreamMasterType;
      -- Outbound frame
      mAxisMaster  : out AxiStreamMasterType);
end ClinkPack;

architecture rtl of ClinkPack is

   constant MAX_BYTE_C : integer := AXIS_CONFIG_G.TDATA_BYTES_C-1;

   type RegType is record
      byteCount  : integer range 0 to MAX_BYTE_C;
      inTop      : integer range 0 to MAX_BYTE_C;
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

begin

   comb : process (r, sysRst, sAxisMaster ) is
      variable v     : RegType;
      variable valid : sl;
      variable last  : sl;
      variable user  : slv(AXIS_CONFIG_G.TUSER_BITS_C-1 downto 0);
   begin
      v := r;

      -- Register input and compute size
      v.inMaster := sAxisMaster;
      v.inTop    := getTKeep(sAxisMaster.tKeep(MAX_BYTE_C downto 0))-1;

      -- Pending output from current
      if r.curMaster.tValid = '1' then
         v.outMaster := r.curMaster;

         -- Shift next to current only if nxt is not full
         if r.nxtMaster.tValid = '0' then
            v.curMaster := r.nxtMaster;
            v.nxtMaster := AXI_STREAM_MASTER_INIT_C;
            v.nxtMaster.tKeep := (others=>'0');
         else
            v.curMaster := AXI_STREAM_MASTER_INIT_C;
            v.curMaster.tKeep := (others=>'0');
         end if;

      -- Next is full, send to out
      elsif r.nxtMaster.tValid = '1' then
         v.outMaster := r.nxtMaster;
         v.nxtMaster := AXI_STREAM_MASTER_INIT_C;
         v.nxtMaster.tKeep := (others=>'0');
      else
         v.outMaster := AXI_STREAM_MASTER_INIT_C;
      end if;

      -- Data is valid
      if r.inMaster.tValid = '1' then

         -- Process each input byte
         for i in 0 to r.inTop loop
            valid := toSl(v.byteCount = MAX_BYTE_C) or (r.inMaster.tLast and toSl(i=r.inTop));
            last  := r.inMaster.tLast and toSl(i=r.inTop);
            user  := axiStreamGetUserField ( AXIS_CONFIG_G, r.inMaster, i );

            -- Still filling current data
            if v.curMaster.tValid = '0' then 

               v.curMaster.tData(v.byteCount*8+7 downto v.byteCount*8) := r.inMaster.tData(i*8+7 downto i*8);
               v.curMaster.tKeep(v.byteCount) := r.inMaster.tKeep(i);
               v.curMaster.tValid := valid;
               v.curMaster.tLast  := last;

               -- Copy user field
               axiStreamSetUserField( AXIS_CONFIG_G, v.curMaster, user, v.ByteCount);

            -- Filling next data
            elsif v.nxtMaster.tValid = '0' then

               v.nxtMaster.tData(v.byteCount*8+7 downto v.byteCount*8) := r.inMaster.tData(i*8+7 downto i*8);
               v.nxtMaster.tKeep(v.byteCount) := r.inMaster.tKeep(i);
               v.nxtMaster.tValid := valid;
               v.nxtMaster.tLast  := last;

               -- Copy user field
               axiStreamSetUserField( AXIS_CONFIG_G, v.nxtMaster, user, v.ByteCount);

            end if;

            if v.byteCount = MAX_BYTE_C or last = '1' then
               v.byteCount := 0;
            else
               v.byteCount := v.byteCount + 1;
            end if;
         end loop;
      end if;

      -- Reset
      if (sysRst = '1') then
         v := REG_INIT_C;
         v.curMaster.tKeep := (others=>'0');
         v.nxtMaster.tKeep := (others=>'0');
      end if;

      rin <= v;

      mAxisMaster <= r.outMaster;

   end process;

   seq : process (sysClk) is
   begin  
      if (rising_edge(sysClk)) then
         r <= rin;
      end if;
   end process;

end architecture rtl;

