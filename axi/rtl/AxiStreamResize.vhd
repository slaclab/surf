-------------------------------------------------------------------------------
-- File       : AxiStreamResize.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-06-16
-- Last update: 2016-06-16
-------------------------------------------------------------------------------
-- Description:
-- Block to resize AXI Streams. Re-sizing is always little endian. 
-- Resizer should not be used when interleaving tDests
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

entity AxiStreamResize is
   generic (

      -- General Configurations
      TPD_G      : time    := 1 ns;
      READY_EN_G : boolean := true;

      -- AXI Stream Port Configurations
      SLAVE_AXI_CONFIG_G  : AxiStreamConfigType := AXI_STREAM_CONFIG_INIT_C;
      MASTER_AXI_CONFIG_G : AxiStreamConfigType := AXI_STREAM_CONFIG_INIT_C
      );
   port (

      -- Clock and reset
      axisClk     : in  sl;
      axisRst     : in  sl;

      -- Slave Port
      sAxisMaster : in  AxiStreamMasterType;
      sAxisSlave  : out AxiStreamSlaveType;

      -- Master Port
      mAxisMaster : out AxiStreamMasterType;
      mAxisSlave  : in  AxiStreamSlaveType
   );
end AxiStreamResize;

architecture rtl of AxiStreamResize is

   constant SLV_BYTES_C : integer := SLAVE_AXI_CONFIG_G.TDATA_BYTES_C;
   constant MST_BYTES_C : integer := MASTER_AXI_CONFIG_G.TDATA_BYTES_C;

   constant SLV_USER_C : integer := SLAVE_AXI_CONFIG_G.TUSER_BITS_C;
   constant MST_USER_C : integer := MASTER_AXI_CONFIG_G.TUSER_BITS_C;

   constant COUNT_C : integer := ite(SLV_BYTES_C > MST_BYTES_C, SLV_BYTES_C / MST_BYTES_C, MST_BYTES_C / SLV_BYTES_C);

   type RegType is record
      count    : slv(bitSize(COUNT_C)-1 downto 0);
      obMaster : AxiStreamMasterType;
      ibSlave  : AxiStreamSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      count    => (others => '0'),
      obMaster => axiStreamMasterInit(MASTER_AXI_CONFIG_G),
      ibSlave  => AXI_STREAM_SLAVE_INIT_C
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   -- Make sure data widths are appropriate. 
   assert ((SLV_BYTES_C >= MST_BYTES_C and SLV_BYTES_C mod MST_BYTES_C = 0) or
           (MST_BYTES_C >= SLV_BYTES_C and MST_BYTES_C mod SLV_BYTES_C = 0))
      report "Data widths must be even number multiples of each other" severity failure;

   -- When going from a large bus to a small bus, ready is neccessary
   assert (SLV_BYTES_C <= MST_BYTES_C or READY_EN_G = true)  
      report "READY_EN_G must be true if slave width is great than master" severity failure;

   comb : process (mAxisSlave, sAxisMaster, r) is
      variable v       : RegType;
      variable ibM     : AxiStreamMasterType;
      variable idx     : integer; -- index version of counter
      variable byteCnt : integer; -- Number of valid bytes in incoming bus
      variable bytes   : integer; -- byte version of counter
   begin
      v       := r;
      idx     := conv_integer(r.count);
      bytes   := (idx+1) * MST_BYTES_C;
      byteCnt := getTKeep(sAxisMaster.tKeep);

      -- Init ready
      v.ibSlave.tReady := '0';

      -- Choose ready source and clear valid
      if READY_EN_G = false or mAxisSlave.tReady = '1' then
         v.obMaster.tValid := '0';
      end if;

      -- Inbound data with normalized user bits (8 user bits)
      ibM := sAxisMaster;
      ibM.tUser := (others=>'0');

      for i in 0 to 15 loop
         ibM.tUser((i*8)+(SLV_USER_C-1) downto (i*8)) := sAxisMaster.tUser((i*SLV_USER_C)+(SLV_USER_C-1) downto (i*SLV_USER_C));
      end loop;

      -- Pipeline advance
      if v.obMaster.tValid = '0' then

         -- Increasing size
         if MST_BYTES_C > SLV_BYTES_C then
            v.ibSlave.tReady := '1';

            -- init when count = 0
            if (r.count = 0) then
               v.obMaster := axiStreamMasterInit(MASTER_AXI_CONFIG_G);
               v.obMaster.tKeep := (others=>'0');
               v.obMaster.tStrb := (others=>'0');
            end if;

            v.obMaster.tData((SLV_BYTES_C*8*idx)+((SLV_BYTES_C*8)-1) downto (SLV_BYTES_C*8*idx)) := ibM.tData((SLV_BYTES_C*8)-1 downto 0);
            v.obMaster.tUser((SLV_BYTES_C*8*idx)+((SLV_BYTES_C*8)-1) downto (SLV_BYTES_C*8*idx)) := ibM.tUser((SLV_BYTES_C*8)-1 downto 0);
            v.obMaster.tStrb((SLV_BYTES_C*idx)+(SLV_BYTES_C-1) downto (SLV_BYTES_C*idx))         := ibM.tStrb(SLV_BYTES_C-1 downto 0);
            v.obMaster.tKeep((SLV_BYTES_C*idx)+(SLV_BYTES_C-1) downto (SLV_BYTES_C*idx))         := ibM.tKeep(SLV_BYTES_C-1 downto 0);

            v.obMaster.tId   := ibM.tId;
            v.obMaster.tDest := ibM.tDest;
            v.obMaster.tLast := ibM.tLast;

            -- Determine if we move data
            if ibM.tValid = '1' then
               if r.count = (COUNT_C-1) or ibM.tLast = '1' then
                  v.obMaster.tValid := '1';
                  v.count           := (others => '0');
               else
                  v.count := r.count + 1;
               end if;
            end if;

         -- Decreasing size
         else

            v.obMaster := axiStreamMasterInit(MASTER_AXI_CONFIG_G);

            v.obMaster.tData((MST_BYTES_C*8)-1 downto 0) := ibM.tData((MST_BYTES_C*8*idx)+((MST_BYTES_C*8)-1) downto (MST_BYTES_C*8*idx));
            v.obMaster.tUser((MST_BYTES_C*8)-1 downto 0) := ibM.tUser((MST_BYTES_C*8*idx)+((MST_BYTES_C*8)-1) downto (MST_BYTES_C*8*idx));
            v.obMaster.tStrb(MST_BYTES_C-1 downto 0)     := ibM.tStrb((MST_BYTES_C*idx)+(MST_BYTES_C-1) downto (MST_BYTES_C*idx));
            v.obMaster.tKeep(MST_BYTES_C-1 downto 0)     := ibM.tKeep((MST_BYTES_C*idx)+(MST_BYTES_C-1) downto (MST_BYTES_C*idx));

            v.obMaster.tId   := ibM.tId;
            v.obMaster.tDest := ibM.tDest;

            -- Determine if we move data
            if ibM.tValid = '1' then
               if (r.count = (COUNT_C-1)) or ((bytes >= byteCnt) and (ibM.tLast = '1')) then
                  v.count          := (others => '0');
                  v.ibSlave.tReady := '1';
                  v.obMaster.tLast := ibM.tLast;
               else
                  v.count          := r.count + 1;
                  v.ibSlave.tReady := '0';
                  v.obMaster.tLast := '0';
               end if;
            end if;

            -- Drop transfers with no tKeep bits set, except on tLast
            v.obMaster.tValid := ibM.tValid and (uOr(v.obMaster.tKeep(COUNT_C-1 downto 0)) or v.obMaster.tLast);

         end if;
      end if;

      -- Resize disabled
      if SLV_BYTES_C = MST_BYTES_C then
         sAxisSlave  <= mAxisSlave;
         mAxisMaster <= sAxisMaster;
      else
         sAxisSlave  <= v.ibSlave;

         -- Outbound data with proper user bits
         mAxisMaster       <= r.obMaster;
         mAxisMaster.tUser <= (others=>'0');

         for i in 0 to 15 loop
            mAxisMaster.tUser((i*MST_USER_C)+(MST_USER_C-1) downto (i*MST_USER_C)) <= r.obMaster.tUser((i*8)+(MST_USER_C-1) downto (i*8));
         end loop;
      end if;

      rin <= v;

   end process comb;

   seq : process (axisClk) is
   begin
      if (rising_edge(axisClk)) then
         if axisRst = '1' or (SLV_BYTES_C = MST_BYTES_C) then
            r <= REG_INIT_C after TPD_G;
         else
            r <= rin after TPD_G;
         end if;
      end if;
   end process seq;

end rtl;

