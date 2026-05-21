-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Cocotb-facing wrapper for surf.AxiStreamBytePacker
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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;

entity AxiStreamBytePackerWrapper is
   generic (
      TPD_G       : time    := 1 ns;
      RST_ASYNC_G : boolean := false);
   port (
      axisClk       : in  sl;
      axisRst       : in  sl;
      S_AXIS_TVALID : in  sl;
      S_AXIS_TDATA  : in  slv(31 downto 0);
      S_AXIS_TKEEP  : in  slv(3 downto 0);
      S_AXIS_TLAST  : in  sl;
      S_AXIS_TDEST  : in  slv(7 downto 0);
      S_AXIS_TID    : in  slv(7 downto 0);
      S_AXIS_TUSER  : in  slv(31 downto 0);
      S_AXIS_TREADY : out sl;
      M_AXIS_TVALID : out sl;
      M_AXIS_TDATA  : out slv(63 downto 0);
      M_AXIS_TKEEP  : out slv(7 downto 0);
      M_AXIS_TLAST  : out sl;
      M_AXIS_TDEST  : out slv(7 downto 0);
      M_AXIS_TID    : out slv(7 downto 0);
      M_AXIS_TUSER  : out slv(63 downto 0);
      M_AXIS_TREADY : in  sl);
end entity AxiStreamBytePackerWrapper;

architecture rtl of AxiStreamBytePackerWrapper is

   constant SLAVE_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 4,
      TDEST_BITS_C  => 0,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_COMP_C,
      TUSER_BITS_C  => 8,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);

   constant MASTER_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 8,
      TDEST_BITS_C  => 0,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_COMP_C,
      TUSER_BITS_C  => 8,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);

   signal sAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;

begin

   ---------------
   -- Bus shims --
   ---------------
   comb : process (S_AXIS_TDATA, S_AXIS_TDEST, S_AXIS_TID, S_AXIS_TKEEP,
                   S_AXIS_TLAST, S_AXIS_TUSER,
                   S_AXIS_TVALID, mAxisMaster) is
      variable vS : AxiStreamMasterType;
   begin
      vS                    := AXI_STREAM_MASTER_INIT_C;
      vS.tValid             := S_AXIS_TVALID;
      vS.tData              := (others => '0');
      vS.tData(31 downto 0) := S_AXIS_TDATA;
      vS.tStrb              := (others => '0');
      vS.tStrb(3 downto 0)  := S_AXIS_TKEEP;
      vS.tKeep              := (others => '0');
      vS.tKeep(3 downto 0)  := S_AXIS_TKEEP;
      vS.tLast              := S_AXIS_TLAST;
      vS.tDest(7 downto 0)  := S_AXIS_TDEST;
      vS.tId(7 downto 0)    := S_AXIS_TID;
      vS.tUser              := (others => '0');
      vS.tUser(31 downto 0) := S_AXIS_TUSER;

      sAxisMaster <= vS;

      S_AXIS_TREADY <= '1';
      M_AXIS_TVALID <= mAxisMaster.tValid;
      M_AXIS_TDATA  <= mAxisMaster.tData(63 downto 0);
      M_AXIS_TKEEP  <= mAxisMaster.tKeep(7 downto 0);
      M_AXIS_TLAST  <= mAxisMaster.tLast;
      M_AXIS_TDEST  <= mAxisMaster.tDest(7 downto 0);
      M_AXIS_TID    <= mAxisMaster.tId(7 downto 0);
      M_AXIS_TUSER  <= mAxisMaster.tUser(63 downto 0);
   end process comb;

   ---------------------
   -- DUT instancing  --
   ---------------------
   U_DUT : entity surf.AxiStreamBytePacker
      generic map (
         TPD_G           => TPD_G,
         RST_ASYNC_G     => RST_ASYNC_G,
         SLAVE_CONFIG_G  => SLAVE_CONFIG_C,
         MASTER_CONFIG_G => MASTER_CONFIG_C)
      port map (
         axiClk      => axisClk,
         axiRst      => axisRst,
         sAxisMaster => sAxisMaster,
         mAxisMaster => mAxisMaster);

end architecture rtl;
