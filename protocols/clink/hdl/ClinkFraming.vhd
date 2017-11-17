-------------------------------------------------------------------------------
-- File       : ClinkFraming.vhd
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

entity ClinkFraming is
   generic (
      TPD_G              : time                := 1 ns;
      DATA_AXIS_CONFIG_G : AxiStreamConfigType := AXI_STREAM_CONFIG_INIT_C);
   port (
      -- System clock and reset
      sysClk       : in  sl;
      sysRst       : in  sl;
      -- Config and status
      linkMode     : in  slv(3 downto 0);
      dataMode     : in  slv(3 downto 0);
      frameCount   : out slv(31 downto 0);
      dropCount    : out slv(31 downto 0);
      -- Data interface
      locked       : in  slv(2 downto 0);
      running      : out sl;
      parData      : in  Slv28Array(2 downto 0);
      parValid     : in  slv(2 downto 0);
      parReady     : out sl;
      -- Camera data
      dataMaster   : out AxiStreamMasterType;
      dataSlave    : in  AxiStreamSlaveType;
end ClinkFraming;

architecture structure of ClinkFraming is

   constant INT_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 16, -- 128 bits
      TDEST_BITS_C  => 0,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_COMP_C,
      TUSER_BITS_C  => 2,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);

   type RegType is record
      ready      : sl;
      running    : sl;
      portData   : ClDataType;
      byteData   : ClDataType;
      bytes      : integer range 1 to 10;
      inFrame    : sl;
      dump       : sl;
      frameCount : slv(31 downto 0);
      dropCount  : slv(31 downto 0);
      master     : AxiStreamMasterType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      ready      => '0',
      running    => '0',
      portData   => CL_DATA_INIT_C,
      byteData   => CL_DATA_INIT_C,
      bytes      => 1,
      inFrame    => '0',
      dump       => '0',
      frameCount => (others=>'0'),
      dropCount  => (others=>'0'),
      master     => AXI_STREAM_MASTER_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal intCtrl    : AxiStreamCtrlType;
   signal packMaster : AxiStreamMasterType;

begin

   comb : process (r, sysRst, linkMode, dataMode, locked, intCtrl, parData, parValid) is
      variable v : RegType;
   begin
      v := r;

      -- Init data
      v.running  := '0';
      v.portData := CL_DATA_INIT_C;

      -- Determine running mode and check valids
      -- Extract data, and alignment markers
      case linkMode is 

         -- Base mode, 24 bits
         when CLM_BASE_C =>
            v.running        := locked(0);
            v.portData.valid := parValid(0);

            clMapBasePorts ( dataMode, parData, v.bytes, v.portData );
            clMapBytes ( dataMode, r.portData, true, v.byteData );

         -- Medium mode, 48 bits
         when CLM_MEDM_C =>
            v.running        := uAnd(locked(1 downto 0));
            v.portData.valid := uAnd(parValid(1 downto 0));

            clMapMedmPorts ( dataMode, parData, v.bytes, v.portData );
            clMapBytes ( dataMode, r.portData, true, v.byteData );

         -- Full mode, 64 bits
         when CLM_FULL_C =>
            v.running        := uAnd(locked);
            v.portData.valid := uAnd(parValid);

            clMapFullPorts ( dataMode, parData, v.bytes, v.portData );
            clMapBytes ( dataMode, r.portData, true, v.byteData );

         -- DECA mode, 80 bits
         when CLM_DECA_C =>
            v.running        := uAnd(locked);
            v.portData.valid := uAnd(parValid);

            clMapDecaPorts ( dataMode, parData, v.bytes, v.portData );
            clMapBytes ( dataMode, r.portData, false, v.byteData );

      end case;

      -- Drive ready, dump when not running
      v.ready := v.portData.valid or (not r.running);

      -- Format data
      v.master       := AXI_STREAM_MASTER_INIT_C;
      v.master.tKeep := (others=>'0');

      -- Setup output data
      for i in 0 to r.bytes-1 loop
         v.master.tData((i*8)+7 downto i*8) := r.byteData(i);
         v.master.tKeep(i) := '1';
      end loop;

      -- Set start of frame
      ssiSetUserSof ( INT_CONFIG_C, v.master, not r.inFrame );

      -- Move data
      if r.portData.valid = '1' and r.byteData.valid = '1' and r.byteData.fv = '1' then

         -- Valid data in byte record
         if r.dump = '0' and r.byteData.dv = '1' and r.byteData.lv = '1' then
            v.inFrame       := '1';
            v.master.tValid := '1';
         end if;

         -- Backpressure
         if intCtrl.pause = '1' then
            v.dump := '1';
         end if;

         -- End of frame
         if r.byteData.fv = '1' and r.portData.fv = '0' then

            -- Frame was dumped, or bad end markers
            if r.dump = '1' or r.inFrame = '0' or r.byteData.dv = '0' or r.byteData.lv = '0' then
               ssiSetUserEofe ( INT_CONFIG_C, v.master, '1' );
               v.dropCount := r.dropCount + 1;
            else
               v.frameCount := r.frameCount + 1;
            end if;

            v.master.tValid := r.inFrame;
            v.master.tLast  := '1';

            v.inFrame := '0';
            v.dump    := '0';
         end if;
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
   -- Frame Packing
   ---------------------------------
   packMaster <= r.master;

   ---------------------------------
   -- Data FIFO
   ---------------------------------
   U_DataFifo: entity work.AxiStreamFifoV2
      generic map (
         TPD_G               => TPD_G,
         SLAVE_READY_EN_G    => false,
         GEN_SYNC_FIFO_G     => true,
         FIFO_ADDR_WIDTH_G   => 9,
         FIFO_PAUSE_THRESH_G => 500,
         SLAVE_AXI_CONFIG_G  => INT_CONFIG_C,
         MASTER_AXI_CONFIG_G => DATA_AXIS_CONFIG_G)
      port map (
         sAxisClk    => sysClk,
         sAxisRst    => sysRst,
         sAxisMaster => packMaster,
         sAxisCtrl   => intCtrl,
         mAxisClk    => sysClk,
         mAxisRst    => sysRst,
         mAxisMaster => dataMaster,
         mAxisSlave  => dataSlave);

end architecture rtl;

