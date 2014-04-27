-------------------------------------------------------------------------------
-- Title         : SSI Lib, Simulation Link
-- Project       : General Purpose Core
-------------------------------------------------------------------------------
-- File          : SimLink.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 04/18/2014
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- Copyright (c) 2014 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 04/18/2014: created.
-------------------------------------------------------------------------------

LIBRARY ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

entity SsiSimLink is 
   generic (
      TPD_G  : time := 1 ns
   );
   port ( 

      -- Inbound, interleave not supported
      ibAxiClk          : in  sl;
      ibAxiRst          : in  sl;
      ibAxiStreamMaster : in  AxiStreamMasterType;
      ibAxiStreamSlave  : out AxiStreamSlaveType;

      -- Outbound
      obAxiClk          : in  sl;
      obAxiRst          : in  sl;
      obAxiStreamMaster : out AxiStreamMasterType;
      obAxiStreamSlave  : in  AxiStreamSlaveType
   );

-- Define architecture
architecture SsiSimLink of SsiSimLink is

   -- Local Signals
   signal obValid  : sl;
   signal obSize   : sl;
   signal obDest   : slv(3 downto 0);
   signal obEof    : sl;
   signal obData   : slv(31 downto 0);
   signal obReady  : slv(15 downto 0);
   signal ibValid  : sl;
   signal ibDest   : slv(3 downto 0);
   signal ibEof    : sl;
   signal ibEofe   : sl;
   signal ibData   : slv(31 downto 0);

begin

   ------------------------------------
   -- Outbound
   ------------------------------------

   process ( obValid, obData, obEof, obDest ) begin
      obAxiStreamMaster <= AX_STREAM_MASTER_INIT_C;

      obAxiStreamMaster.tValid <= obValid;
      obAxiStreamMaster.tData(31 downto 0) <= obData;
      obAxiStreamMaster.tStrb(3  downto 0) <= "1111";
      obAxiStreamMaster.tKeep(3  downto 0) <= "1111";
      obAxiStreamMaster.tLast              <= obEof;
      obAxiStreamMaster.tDest(3  downto 0) <= obDest;

      obAxiStreamMaster.tUser(SSI_EOF_TUSER_BIT_C)  <= obEof;
      obAxiStreamMaster.tUser(SSI_EOFE_TUSER_BIT_C) <= '0';
   end process;

   obReady <= obAxiStreamSlave.tReady;

   U_SimLinkOb: entity work.SsiSimLinkOb
      port map (
         obClk   => obAxiClk,
         obReset => obAxiRst,
         obValid => obValid,
         obDest  => obDest,
         obEof   => obEof,
         obData  => obData,
         obReady => obReady
      );


   ------------------------------------
   -- Inbound
   ------------------------------------

   ibValid <= ibAxiStreamMaster.tValid;
   ibData  <= ibAxiStreamMaster.tData(31 downto 0);
   ibDest  <= ibAxiStreamMaster.tDest(3 downto 0);
   ibEof   <= ibAxiStreamMaster.tLast and ibAxiStreamMaster.tUser(SSI_EOF_TUSER_BIT_C);
   ibEofe  <= ibAxiStreamMaster.tLast and ibAxiStreamMaster.tUser(SSI_EOFE_TUSER_BIT_C);

   U_SimLinkIb: entity work.SsiSimLinkIb
      port map (
         ibClk   => ibAxiClk,
         ibReset => ibAxiRst,
         ibValid => ibValid,
         ibDest  => ibDest,
         ibEof   => ibEof,
         ibEofe  => ibEofe,
         ibData  => ibData
      );

   assert ( ibAxiStreamMaster.tDest < 4 )
      report "Invalid tDest value in inbound simLink" severity failure;

   assert ( ibAxiStreamMaster.tKeep(3 downto 0) = "1111" )
      report "Invalid tKeep value in inbound simLink" severity failure;

   ibAxiStreamSlave.tReady <= '1';

end SsiSimLink;

