-------------------------------------------------------------------------------
-- Title         : Generic Ethernet Filter
-- Project       : Ethernet MAC
-------------------------------------------------------------------------------
-- File          : EthMaxRxCsum.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 09/21/2015
-------------------------------------------------------------------------------
-- Description:
-- Generic frame filter for Ethernet MACs. 
-------------------------------------------------------------------------------
-- Copyright (c) 2008 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 09/21/2015: created.
-------------------------------------------------------------------------------

LIBRARY ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.AxiStreamPkg.all;
use work.StdRtlPkg.all;
use work.EthMacPkg.all;

entity EthMaxRxCsum is 
   generic (
      TPD_G : time := 1 ns
   );
   port ( 

      -- Ethernet Clock
      ethClk           : in  sl;
      ethClkRst        : in  sl;

      -- Imcoming data from MAC
      sAxisMaster      : in  AxiStreamMasterType;

      -- Outgoing data 
      mAxisMaster      : out AxiStreamMasterType;

      -- Configuration
      ipCsumEn         : in  sl;
      tcpCsumEn        : in  sl;
      udpCsumEn        : in  sl
   );
end EthMaxRxCsum;


-- Define architecture
architecture EthMaxRxCsum of EthMaxRxCsum is

   type StateType is ( WAIT_S, WORD0_S, WORD1_S, WORD2_S, WORD3_S, WORD4_S, WORD5_S, BODY_S);

   type RegType is record
      state      : StateType;
      vlanEn     : sl;
      ipEn       : sl;
      ipCsum     : slv(23 downto 0);
      doTcp      : sl;
      doUdp      : sl;
      payCsum    : slv(23 downto 0);
      regMaster  : AxiStreamMasterType;
      outMaster  : AxiStreamMasterType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state      => HEAD_S,
      vlanEn     => '0',
      ipEn       => '0',
      ipCsum     => (others=>'0'),
      doTcp      => '0',
      doUdp      => '0',
      payCsum    => (others=>'0'),
      regMaster  => AXI_STREAM_MASTER_INIT_C,
      outMaster  => AXI_STREAM_MASTER_INIT_C
   );

   signal r      : RegType := REG_INIT_C;
   signal rin    : RegType;

begin

   comb : process (ethClkRst, sAxisMaster, r, ipCsumEn, tcpCsumEn, udpCsumEn) is
      variable v : RegType;
   begin

      v := r;

      -- Pipeline
      v.regMaster := sAxisMaster;
      v.outMaster := r.regMaster;
      
      -- State
      case r.state is

         -- Waiting for header
         when HEAD_S =>
            v.count   := x"0001";
            v.vlanEn  := '0';
            v.ipEn    := '0';
            v.ipCsum  := (others=>'0');
            v.doTcp   := '0';
            v.tcpCsum := (others=>'0');
            v.doUdp   := '0';
            v.udpCsum := (others=>'0');

            -- Frame is present
            if r.regMaster.tValid = '1' then
               v.state := WORD1_S;
            end if;

         -- Word 1
         when WORD1_S =>
            v.state := WORD2_S;

            -- VLAN
            if r.regMaster.tData(47 downto 32) = x"0081" then
               v.vlanEn := '1';

            -- IP
            elsif r.regMaster.tData(47 downto 32) = x"0008" then
               v.ipEn   := ipCsumEn;
               v.ipCsum := r.regMaster.tData(63 downto 48);
            end if;

         -- Word 2
         when WORD2_S =>
            v.state := WORD3_S;

            -- VLAN
            if r.vlanEn = '1' then
               v.ipCSum  := r.ipCsum  + r.regmaster.tData(63 downto 48) + r.regMaster.tData(47 downto 32) + r.regMaster.tData(31 downto 16);
               v.payCSum := r.payCsum + r.regMaster.tData(47 downto 32);

            -- Not VLAN
            else
               v.ipCSum  := r.ipCsum  + r.regMaster.tData(63 downto 48) + r.regmaster.tData(47 downto 32) + 
                                        r.regMaster.tData(31 downto 16) + r.regMaster.tData(15 downto  0);
               v.payCSum := r.payCsum + (x"00" & r.regMaster.tData(63 downto 56) + r.regMaster.tData(15 downto 0);

               if r.regMaster.tData(63 downto 56) = x"00" then
                  v.tcpEn := tcpCsumEn;
               elsif r.regMaster.tData(63 downto 56) = x"00" then
                  v.udpEn := udpCsumEn;
               end if;
            end if;
               
         -- Word 3
         when WORD3_S =>
            v.state := WORD4_S;

            v.ipCSum  := r.ipCsum  + r.regMaster.tData(63 downto 48) + r.regmaster.tData(47 downto 32) + 
                                     r.regMaster.tData(31 downto 16) + r.regMaster.tData(15 downto  0);

            -- VLAN
            if r.vlanEn = '1' then
               v.payCSum := r.payCsum + r.regMaster.tData(63 downto 56) + (x"00" + r.regMaster.tData(31 downto 24));

               if r.regMaster.tData(31 downto 24) = x"00" then
                  v.tcpEn := tcpCsumEn;
               elsif r.regMaster.tData(31 downto 24) = x"00" then
                  v.udpEn := udpCsumEn;
               end if;

            -- Not VLAN
            else
               v.payCSum := r.payCsum + r.regMaster.tData(63 downto 48) + r.regMaster.tData(47 downto 32) + r.regMaster.tData(31 downto 16);
            end if;

         -- Word 4
         when WORD4_S =>
            v.state := WORD5_S;

            -- VLAN
            if r.vlanEn = '1' then
               v.ipCSum  := r.ipCsum  + r.regmaster.tData(47 downto 32) + 
                                        r.regMaster.tData(31 downto 16) + r.regMaster.tData(15 downto  0);
               v.payCSum := r.payCsum + r.regmaster.tData(47 downto 32) + 
                                        r.regMaster.tData(31 downto 16) + r.regMaster.tData(15 downto  0);

            -- Not VLAN
            else
               v.ipCSum  := r.ipCsum  + r.regMaster.tData(15 downto  0);
               v.payCSum := r.payCsum + r.regMaster.tData(63 downto 48) + r.regMaster.tData(15 downto  0);
            end if;

         -- Word 5
         when WORD5_S =>
            v.state := BODY_S;

            -- VLAN
            if r.vlanEn = '1' then
               v.payCSum := r.payCsum + r.regMaster.tData(63 downto 48) + r.regmaster.tData(47 downto 32) + 
                                        r.regMaster.tData(31 downto 16);

            -- Not VLAN
            else
               v.payCSum  := r.payCsum + r.regMaster.tData(63 downto 48) + r.regmaster.tData(47 downto 32) + 
                                         r.regMaster.tData(31 downto 16) + r.regMaster.tData(15 downto  0);
            end if;






















            if r.regMaster.tValid = '1' and r.regMaster.tLast = '1' then
               v.state := HEAD_S;
            end if;







         -- Pass frame
         when PASS_S =>
            if r.regMaster.tValid = '1' and r.regMaster.tLast = '1' then
               v.state := HEAD_S;
            end if;

         -- Default
         when others =>
            v.state := HEAD_S;

      end case;

      if ethClkRst = '1' then
         v := REG_INIT_C;
      end if;

      rin <= v;

      mAxisMaster  <= r.outMaster;

   end process;

   seq : process (ethClk) is
   begin
      if rising_edge(ethClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end EthMaxRxCsum;

