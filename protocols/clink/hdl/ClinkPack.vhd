-------------------------------------------------------------------------------
-- File       : ClinkPack.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-11-13
-------------------------------------------------------------------------------
-- Description:
-- CameraLink framing module
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
use work.ClinkPkg.all;
library unisim;
use unisim.vcomponents.all;

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

architecture structure of ClinkPack is

   type RegType is record
      byteCount  : integer range 0 to 127;
      curMaster  : AxiStreamMasterType;
      nxtMaster  : AxiStreamMasterType;
      outMaster  : AxiStreamMasterType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      byteCount  => 0,
      curMaster  => AXI_STREAM_MASTER_INIT_C,
      nxtMaster  => AXI_STREAM_MASTER_INIT_C,
      outMaster  => AXI_STREAM_MASTER_INIT_C);
   end record RegType;

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (r, sysRst, sAxisMaster ) is
      variable v : RegType;
   begin
      v := r;

      -- Init
      v.curMaster.tValid := '0';
      v.nxtMaster.tValid := '0';
      v.outMaster.tValid := '0';

      -- Pending output
      if r.curMaster.tValid := '1' then
         v.outMaster := r.curMaster;

         if r.nxtMaster.tValid = '1' then
            v.curMaster := r.nxtMaster;
         end if;

      elsif r.nxtMaster.tValid = '1' then
         v.outMaster := r.nxtMaster;
      end if;

      -- Data is valid
      if sAxisMaster.tValid = '1' then

         -- Process each output byte
         for i in 0 to AXIS_CONFIG_G.DATA_BYTES_C-1 loop

               -- Still filling current data
               if v.curMaster.tValid = '0' then 

                  v.curMaster.tData(v.byteCount*8+7 downto v.byteCount*8) := sAxisMaster.tData(i*8+7 downto i*8);
                  v.curMaster.tKeep(v.outByte) := sAxisMaster.tKeep(i);
                  v.curMaster.tValid := toSl(v.byteCount = 15) or sAxisMaster.tLast;
                  v.curMaster.tLast  := sAxisMaster.tLast;

                  -- Copy user field
                  axiStreamSetUserField( AXIS_CONFIG_G, v.curMaster, axiStreamGetUserField ( AXIS_CONFIG_G, sAxisMaster, i ), v.ByteCount);

               -- Filling next data
               else

                  v.nxtMaster.tData(v.byteCount*8+7 downto v.byteCount*8) := sAxisMaster.tData(i*8+7 downto i*8);
                  v.nxtMaster.tKeep(v.outByte) := sAxisMaster.tKeep(i);
                  v.nxtMaster.tValid := toSl(v.byteCount = 15);
                  v.nxtMaster.tLast  := sAxisMaster.tLast;

                  -- Copy user field
                  axiStreamSetUserField( AXIS_CONFIG_G, v.nxtMaster, axiStreamGetUserField ( AXIS_CONFIG_G, sAxisMaster, i ), v.ByteCount);

               end if;

            if v.outByte = 15 then
               v.outByte := 0;
            end if;
         end loop;
      end if;



      -- Reset
      if (sysRst = '1') then
         v := REG_INIT_C;
      end if;

      rin        <= v;
      parReady   <= v.ready;
      running    <= r.running;
      frameCount <= r.frameCount;
      dropCount  <= r.dropCount;

   end process;

   seq : process (sysClk) is
   begin  
      if (rising_edge(sysClk)) then
         r <= rin;
      end if;
   end process;

   ---------------------------------
   -- Data FIFO
   ---------------------------------
   U_DataFifo: entity work.AxiStreamFifoV2
      generic map (
         TPD_G               => TPD_G,
         SLAVE_READY_EN_G    => false,
         GEN_SYNC_FIFO_G     => true,
         FIFO_ADDR_WIDTH_G   => 9,
         SLAVE_AXI_CONFIG_G  => INT_CONFIG_C,
         MASTER_AXI_CONFIG_G => DATA_AXIS_CONFIG_G)
      port map (
         sAxisClk    => sysClk,
         sAxisRst    => sysRst,
         sAxisMaster => r.Master,
         sAxisCtrl   => intCtrl,
         mAxisClk    => sysClk,
         mAxisRst    => sysRst,
         mAxisMaster => dataMaster,
         mAxisSlave  => dataSlave);

end architecture rtl;

