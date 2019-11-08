-------------------------------------------------------------------------------
-- File       : AxiStreamMBytePacker.vhd.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- MultiByte packer for AXI-Stream. 
-- Accepts an incoming stream and packs data into the outbound stream.
-- Packs with granularity equal to a fixed multiple of bytes.
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

entity AxiStreamMBytePacker is
   generic (
      TPD_G           : time                := 1 ns;
      MBYTES_G        : integer             := 2;
      SLAVE_CONFIG_G  : AxiStreamConfigType := AXI_STREAM_CONFIG_INIT_C;
      MASTER_CONFIG_G : AxiStreamConfigType := AXI_STREAM_CONFIG_INIT_C);
   port (
      -- System clock and reset
      axiClk        : in  sl;
      axiRst        : in  sl;
      -- Inbound frame
      sAxisMaster   : in  AxiStreamMasterType;
      sAxisSlave    : out AxiStreamSlaveType;
      sAxisOverflow : out sl;
      -- Outbound frame
      mAxisMaster   : out AxiStreamMasterType;
      mAxisSlave    : in  AxiStreamSlaveType);
end AxiStreamMBytePacker;

architecture rtl of AxiStreamMBytePacker is

   signal taxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal taxisCtrl   : AxiStreamCtrlType   := AXI_STREAM_CTRL_INIT_C;

   signal mAxis : AxiStreamMasterArray(MBYTES_G-1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal sAxis : AxiStreamMasterArray(MBYTES_G-1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);

   signal sAxis_tdata : Slv128Array(MBYTES_G-1 downto 0) := (others => (others => '0'));
   signal mAxis_tdata : Slv128Array(MBYTES_G-1 downto 0) := (others => (others => '0'));


   type RegType is record
      axis  : AxiStreamMasterArray(MBYTES_G-1 downto 0);
      slave : AxiStreamSlaveType;
   end record;

   constant REG_INIT_C : RegType := (
      axis  => (others => AXI_STREAM_MASTER_INIT_C),
      slave => AXI_STREAM_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   constant STREAM_BYTES_C : integer := SLAVE_CONFIG_G.TDATA_BYTES_C/MBYTES_G;

   constant SLAVE_FRAG_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => STREAM_BYTES_C,
      TDEST_BITS_C  => SLAVE_CONFIG_G.TDEST_BITS_C,
      TID_BITS_C    => SLAVE_CONFIG_G.TID_BITS_C,
      TKEEP_MODE_C  => TKEEP_NORMAL_C,
      TUSER_BITS_C  => SLAVE_CONFIG_G.TUSER_BITS_C,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);

   constant MFRAG_C         : integer := MASTER_CONFIG_G.TDATA_BYTES_C/MBYTES_G;
   constant MSTREAM_BYTES_C : integer := MFRAG_C * wordCount(STREAM_BYTES_C, MFRAG_C);

   constant MASTER_FRAG_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => MSTREAM_BYTES_C,
      TDEST_BITS_C  => SLAVE_CONFIG_G.TDEST_BITS_C,
      TID_BITS_C    => SLAVE_CONFIG_G.TID_BITS_C,
      TKEEP_MODE_C  => TKEEP_NORMAL_C,
      TUSER_BITS_C  => SLAVE_CONFIG_G.TUSER_BITS_C,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);

   constant TAXIS_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => MSTREAM_BYTES_C * MBYTES_G,
      TDEST_BITS_C  => SLAVE_CONFIG_G.TDEST_BITS_C,
      TID_BITS_C    => SLAVE_CONFIG_G.TID_BITS_C,
      TKEEP_MODE_C  => TKEEP_NORMAL_C,
      TUSER_BITS_C  => SLAVE_CONFIG_G.TUSER_BITS_C,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);

   signal taxisMaster_tData : slv(255 downto 0);

begin

   sAxisOverflow     <= taxisCtrl.overflow;
   taxisMaster_tData <= taxisMaster.tData(255 downto 0);

   --
   --  Need taxisCtrl to protect fifo overflow
   --    ADDR_WIDTH_G = 4, PAUSE_THRESH =8, doesn't work
   --
   U_FIFO : entity work.AxiStreamFifoV2
      generic map (
         TPD_G               => TPD_G,
         SLAVE_AXI_CONFIG_G  => TAXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => MASTER_CONFIG_G,
         SLAVE_READY_EN_G    => false,
         GEN_SYNC_FIFO_G     => true,
         FIFO_FIXED_THRESH_G => true,   -- true => use generic FIFO_PAUSE_THRESH_G,
                                        -- false => use signal fifoPauseThresh
         FIFO_ADDR_WIDTH_G   => 5,
         FIFO_PAUSE_THRESH_G => 8)
      port map (                        -- Slave Port
         sAxisClk    => axiClk,
         sAxisRst    => axiRst,
         sAxisMaster => taxisMaster,
         sAxisSlave  => open,
         sAxisCtrl   => taxisCtrl,
         -- Master Port
         mAxisClk    => axiClk,
         mAxisRst    => axiRst,
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);

   taxisMaster.tValid <= mAxis(0).tValid;
   taxisMaster.tLast  <= mAxis(0).tLast;
   taxisMaster.tUser  <= mAxis(0).tUser;
   taxisMaster.tDest  <= mAxis(0).tDest;
   taxisMaster.tStrb  <= mAxis(0).tStrb;
   taxisMaster.tId    <= mAxis(0).tId;

   taxisMaster.tKeep(taxisMaster.tKeep'left downto MSTREAM_BYTES_C*MBYTES_G) <= (others => '0');

   GEN_PACKER : for i in 0 to MBYTES_G-1 generate
      saxis(i).tValid                                           <= sAxisMaster.tValid;
      saxis(i).tLast                                            <= sAxisMaster.tLast;
      saxis(i).tKeep(saxis(i).tKeep'left downto STREAM_BYTES_C) <= (others => '0');

      GEN_BYTE : for j in 0 to STREAM_BYTES_C-1 generate
         saxis(i).tData(8*j+7 downto 8*j) <= sAxisMaster.tData((MBYTES_G*j+i)*8+7 downto (MBYTES_G*j+i)*8);
         saxis(i).tKeep(j)                <= sAxisMaster.tKeep(MBYTES_G*j+i);
         mAxis_tdata(i)(j)                <= uOr(mAxis(i).tData(8*j+7 downto 8*j));
         saxis_tdata(i)(j)                <= uOr(saxis(i).tData(8*j+7 downto 8*j));
      end generate;

      GEN_MBYTE : for j in 0 to MSTREAM_BYTES_C-1 generate
         taxisMaster.tData((MBYTES_G*j+i)*8+7 downto (MBYTES_G*j+i)*8) <= mAxis(i).tData(8*j+7 downto 8*j);
         taxisMaster.tKeep(MBYTES_G*j+i)                               <= mAxis(i).tKeep(j);
      end generate;

      U_Packer : entity work.AxiStreamBytePackerDSP
         generic map (
            TPD_G           => TPD_G,
            SLAVE_CONFIG_G  => SLAVE_FRAG_CONFIG_C,
            MASTER_CONFIG_G => MASTER_FRAG_CONFIG_C)
         port map (
            axiClk      => axiClk,
            axiRst      => axiRst,
            sAxisMaster => r.axis(i),
            mAxisMaster => mAxis(i));
   end generate;

   comb : process (axiRst, r, saxis, taxisCtrl, sAxisMaster) is
      variable v     : RegType;
      variable k     : integer;
      variable sData : Slv8Array(sAxisMaster.tData'length/8-1 downto 0);
   begin
      v      := r;
      v.axis := saxis;
      for i in 0 to MBYTES_G-1 loop
         if sAxisMaster.tValid = '1' then
            sData := (others => (others => '0'));
            k     := STREAM_BYTES_C;
            for j in STREAM_BYTES_C-1 downto 0 loop
               sData(j) := saxis(i).tData(8*j+7 downto 8*j);
               if saxis(i).tKeep(j) = '1' then
                  k := j;
               end if;
            end loop;
            v.axis(i).tKeep := (others => '0');
            --  synthesis objects to non-constant range expressions
            --v.axis(i).tKeep(sAxisMaster.tKeep'left-1*k downto 0) := saxis(i).tKeep(sAxisMaster.tKeep'left downto 1*k);
            --v.axis(i).tData(sAxisMaster.tData'left-8*k downto 0) := saxis(i).tData(sAxisMaster.tData'left downto 8*k);
            for j in STREAM_BYTES_C-1 downto 0 loop
               v.axis(i).tKeep(j)                := saxis(i).tKeep(j+k);
               v.axis(i).tData(8*j+7 downto 8*j) := sData(j+k);
            end loop;
         end if;
         if taxisCtrl.pause = '1' then
            v.axis(i).tValid := '0';
         end if;
      end loop;
      if taxisCtrl.pause = '0' and sAxisMaster.tValid = '1' then
         v.slave.tReady := '1';
      else
         v.slave.tReady := '0';
      end if;

      sAxisSlave <= v.slave;

      if axiRst = '1' then
         v := REG_INIT_C;
      end if;

      rin <= v;
   end process;

   seq : process (axiClk) is
   begin
      if rising_edge(axiClk) then
         r <= rin;
      end if;
   end process;
end;
