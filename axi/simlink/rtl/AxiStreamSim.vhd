-------------------------------------------------------------------------------
-- File       : AxiStreamSim.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-18
-- Last update: 2014-04-18
-------------------------------------------------------------------------------
-- Description: SSI Lib, Simulation Link
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

LIBRARY ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;

entity AxiStreamSim is 
   generic (
      TPD_G            : time                   := 1 ns;
      STREAM_ID_G      : integer range 0 to 255 := 1;
      AXIS_CONFIG_G    : AxiStreamConfigTYpe    := AXI_STREAM_CONFIG_INIT_C;
      EOFE_TUSER_EN_G  : boolean                := false;
      EOFE_TUSER_BIT_G : integer range 0 to 127 := 0;
      SOF_TUSER_EN_G   : boolean                := false;
      SOF_TUSER_BIT_G  : integer range 0 to 127 := 0
   );
   port ( 

      -- Slave, non-interleaved, 32-bit or 16-bit interface, tkeep not supported
      sAxisClk    : in  sl;
      sAxisRst    : in  sl;
      sAxisMaster : in  AxiStreamMasterType;
      sAxisSlave  : out AxiStreamSlaveType;

      -- Master, non-interleaved, 32-bit or 16-bit interface, tkeep not supported
      mAxisClk    : in  sl;
      mAxisRst    : in  sl;
      mAxisMaster : out AxiStreamMasterType;
      mAxisSlave  : in  AxiStreamSlaveType
   );
end AxiStreamSim;

-- Define architecture
architecture AxiStreamSim of AxiStreamSim is

   -- Local Signals
   signal ibValid    : sl;
   signal ibDest     : slv(3 downto 0);
   signal ibEof      : sl;
   signal ibEofe     : sl;
   signal ibData     : slv(31 downto 0);
   signal ibPos      : sl;
   signal obValid    : sl;
   signal obDest     : slv(3 downto 0);
   signal obEof      : sl;
   signal obData     : slv(31 downto 0);
   signal streamId   : slv(7 downto 0);

   type RegType is record
      master : AxiStreamMasterType;
      sof    : sl;
      ready  : sl;
      pos    : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      master => AXI_STREAM_MASTER_INIT_C,
      sof    => '1',
      ready  => '0',
      pos    => '0'
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   streamId <= conv_std_logic_vector(STREAM_ID_G,8);


   ------------------------------------
   -- Inbound
   ------------------------------------

   sAxisSlave.tReady <= '1';

   process (sAxisClk) 
   begin
      if rising_edge(sAxisClk) then
         if sAxisRst = '1' then
            ibValid <= '0'           after TPD_G;
            ibData  <= (others=>'0') after TPD_G;
            ibDest  <= (others=>'0') after TPD_G;
            ibEof   <= '0'           after TPD_G;
            ibEofe  <= '0'           after TPD_G;
            ibPos   <= '0'           after TPD_G;
         else

            if sAxisMaster.tValid = '1' then
               if AXIS_CONFIG_G.TDATA_BYTES_C = 4 then
                  ibValid <= sAxisMaster.tValid             after TPD_G;
                  ibData  <= sAxisMaster.tData(31 downto 0) after TPD_G;
                  ibDest  <= sAxisMaster.tDest(3 downto 0)  after TPD_G;
                  ibEof   <= sAxisMaster.tLast              after TPD_G;

                  if EOFE_TUSER_EN_G then
                     ibEofe  <= axiStreamGetUserBit(AXIS_CONFIG_G,sAxisMaster,EOFE_TUSER_BIT_G) after TPD_G;
                  end if;

               elsif ibPos = '0' then
                  ibPos               <= '1'                            after TPD_G;
                  ibValid             <= '0'                            after TPD_G;
                  ibData(15 downto 0) <= sAxisMaster.tData(15 downto 0) after TPD_G;

                  assert ( sAxisMaster.tLast = '0' )
                     report "Invalid tLast position in AXI stream sim" severity failure;

               else
                  ibPos                <= '0'                            after TPD_G;
                  ibValid              <= '1'                            after TPD_G;
                  ibData(31 downto 16) <= sAxisMaster.tData(15 downto 0) after TPD_G;
                  ibDest               <= sAxisMaster.tDest(3 downto 0)  after TPD_G;
                  ibEof                <= sAxisMaster.tLast              after TPD_G;

                  if EOFE_TUSER_EN_G then
                     ibEofe  <= axiStreamGetUserBit(AXIS_CONFIG_G,sAxisMaster,EOFE_TUSER_BIT_G) after TPD_G;
                  end if;
               end if;
            else
               ibValid <= '0' after TPD_G;
            end if;
         end if;
      end if;
   end process;

   U_SimIb: entity work.AxiStreamSimIb
      port map (
         ibClk    => sAxisClk,
         ibReset  => sAxisRst,
         ibValid  => ibValid,
         ibDest   => ibDest,
         ibEof    => ibEof,
         ibEofe   => ibEofe,
         ibData   => ibData,
         streamId => streamId
      );

   --assert ( sAxisRst = '1' or sAxisMaster.tValid = '0' or 
   --         (AXIS_CONFIG_G.TDATA_BYTES_C = 2 and sAxisMaster.tKeep(1 downto 0) = "11") or
   --         (AXIS_CONFIG_G.TDATA_BYTES_C = 4 and sAxisMaster.tKeep(3 downto 0) = "1111") )
   --   report "Invalid tKeep value in AXI stream sim" severity failure;

   ------------------------------------
   -- Outbound
   ------------------------------------

   comb : process (mAxisRst, r, mAxisSlave, obValid, obDest, obEof, obData ) is
      variable v        : RegType;
   begin
      v := r;

      v.master.tValid := '0';
      v.ready         := '0';

      -- Advance
      if mAxisSlave.tReady = '1' or r.master.tValid = '0' then

         -- 32-bit interface
         if AXIS_CONFIG_G.TDATA_BYTES_C = 4 then
            v.master.tValid             := obValid;
            v.master.tData(31 downto 0) := obData;
            v.master.tLast              := obEof;
            v.master.tDest(3  downto 0) := obDest;
            v.ready                     := '1';

         -- 16bit interface, low position
         elsif r.pos = '0' then
            v.master.tValid             := obValid;
            v.master.tData(15 downto 0) := obData(15 downto 0);
            v.master.tLast              := '0';
            v.master.tDest(3 downto 0)  := obDest;
            v.ready                     := '0';

            if ( obValid = '1') then
               v.pos := '1';
            end if;

         -- 16bit interface, high position
         else 
            v.pos                       := '0';
            v.master.tValid             := obValid;
            v.master.tData(15 downto 0) := obData(31 downto 16);
            v.master.tLast              := obEof;
            v.master.tDest(3 downto 0)  := obDest;
            v.ready                     := '1';

         end if;
      end if;

      if SOF_TUSER_EN_G then
         if r.master.tValid = '1' and mAxisSlave.tReady = '1' then
            -- Set the SOF bit on the master
            axiStreamSetUserBit(AXIS_CONFIG_G,v.master,SOF_TUSER_BIT_G,r.sof,0);
            -- Update the SOF bit
             v.sof := obEof;
         end if;
      end if;

      if (mAxisRst = '1') then
         v              := REG_INIT_C;
         axiStreamSetUserBit(AXIS_CONFIG_G,v.master,SOF_TUSER_BIT_G,'1',0);         
      end if;

      rin <= v;

      mAxisMaster <= r.master;

   end process comb;

   seq : process (mAxisClk) is
   begin
      if (rising_edge(mAxisClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   U_SimOb: entity work.AxiStreamSimOb
      port map (
         obClk    => mAxisClk,
         obReset  => mAxisRst,
         obValid  => obValid,
         obDest   => obDest,
         obEof    => obEof,
         obData   => obData,
         obReady  => rin.ready,
         streamId => streamId
      );

end AxiStreamSim;

