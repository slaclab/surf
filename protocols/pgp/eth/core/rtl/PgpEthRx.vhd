-------------------------------------------------------------------------------
-- Title      : PgpEth Receive Block
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
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
use work.SsiPkg.all;
use work.PgpEthPkg.all;

entity PgpEthRx is
   generic (
      TPD_G    : time                  := 1 ns;
      NUM_VC_G : integer range 1 to 16 := 4);
   port (
      -- Ethernet Configuration
      remoteMac      : out slv(47 downto 0);
      localMac       : in  slv(47 downto 0);
      broadcastMac   : in  slv(47 downto 0);
      etherType      : in  slv(15 downto 0);
      commMode       : in  sl;          -- '1': point-to-point, '0': Network
      -- User interface
      pgpClk         : in  sl;
      pgpRst         : in  sl;
      pgpRxIn        : in  PgpEthRxInType;
      pgpRxOut       : out PgpEthRxOutType;
      pgpRxMasters   : out AxiStreamMasterArray(NUM_VC_G-1 downto 0);
      -- Status of local receive FIFOs
      remRxFifoCtrl  : out AxiStreamCtrlArray(NUM_VC_G-1 downto 0);
      remRxLinkReady : out sl;
      locRxLinkReady : out sl;
      -- PHY interface
      phyRxRdy       : in  sl;
      phyRxMaster    : in  AxiStreamMasterType);
end entity PgpEthRx;

architecture rtl of PgpEthRx is

   type StateType is (
      IDLE_S,
      PAYLOAD_S);

   type RegType is record
      aliveCnt       : slv(23 downto 0);
      sof            : sl;
      locRxLinkReady : sl;
      remRxLinkReady : sl;
      tid            : slv(7 downto 0);
      remoteMac      : slv(47 downto 0);
      pgpRxOut       : PgpEthRxOutType;
      remRxFifoCtrl  : AxiStreamCtrlArray(NUM_VC_G-1 downto 0);
      pgpRxMasters   : AxiStreamMasterArray(1 downto 0);
      state          : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      aliveCnt       => (others => '0'),
      sof            => '0',
      locRxLinkReady => '0',
      remRxLinkReady => '0',
      tid            => (others => '0'),
      remoteMac      => (others => '0'),
      pgpRxOut       => PGP_ETH_RX_OUT_INIT_C,
      remRxFifoCtrl  => (others => AXI_STREAM_CTRL_INIT_C),
      pgpRxMasters   => (others => AXI_STREAM_MASTER_INIT_C),
      state          => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal pgpRxMaster : AxiStreamMasterType;

begin

   comb : process (broadcastMac, etherType, localMac, pgpRst, phyRxMaster,
                   phyRxRdy, r) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Update/Reset the flags
      v.pgpRxOut.phyRxActive    := phyRxRdy;
      v.pgpRxOut.linkReady      := r.locRxLinkReady;
      v.pgpRxOut.frameRx        := '0';
      v.pgpRxOut.frameRxErr     := '0';
      v.pgpRxOut.linkDown       := '0';
      v.pgpRxOut.opCodeEn       := '0';
      v.pgpRxOut.remRxLinkReady := r.remRxLinkReady;
      v.pgpRxMasters(0).tValid  := '0';

      -- Check for roll over
      if (r.aliveCnt = 0) then
         -- Set the flag
         v.locRxLinkReady := '0';
      else
         -- Set the flag
         v.locRxLinkReady := '1';
         -- Decrement the counter
         v.aliveCnt       := r.aliveCnt - 1;
      end if;

      -- Check for link down event 
      if (v.aliveCnt = 0) and (r.aliveCnt /= 0) then
         -- Set the flag
         v.pgpRxOut.linkDown := '1';
      end if;

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check if read to move data
            if (phyRxMaster.tValid = '1') then

               ---------------------------
               -- Check for a valid header
               ---------------------------
               if ((phyRxMaster.tData(47 downto 0) = localMac) or (phyRxMaster.tData(47 downto 0) = broadcastMac))  -- BYTE[5:0] = Destination MAC or Broadcast MAC
                  and (phyRxMaster.tData(111 downto 96) = etherType)  -- BYTE[13:12] = EtherType
                  and (phyRxMaster.tData(119 downto 112) = PGP_ETH_VERSION_C) then  -- BYTE[14] = Version

                  -- Remote connection detected
                  v.aliveCnt := (others => '1');

                  -- BYTE[11:6] = Source MAC
                  v.remoteMac := phyRxMaster.tData(95 downto 48);

                  -- BYTE[15] = TID
                  v.tid := phyRxMaster.tData(127 downto 120);

                  -- BYTE[17:16] = Virtual Channel Pause
                  v.pgpRxOut.remRxPause := phyRxMaster.tData(143 downto 128);

                  -- Check if not NULL marker (BYTE[18] != 0xFF)
                  if (phyRxMaster.tData(151 downto 144) /= x"FF") then

                     -- BYTE[18] = Virtual Channel Index
                     v.pgpRxMasters(1).tDest := phyRxMaster.tData(151 downto 144);

                     -- BYTE[19] = SOF 
                     v.sof := phyRxMaster.tData(152);

                  end if;

                  -- Check for BYTE[20] = OP-Code Enable
                  if (phyRxMaster.tData(160) = '1') then

                     -- BYTE[20] = OP-Code Enable
                     v.pgpRxOut.opCodeEn := '1';

                     -- BYTE[47:32] = OpCodeData
                     v.pgpRxOut.opCode := phyRxMaster.tData(383 downto 256);

                  end if;


                  -- Check for BYTE[21] = RxLinkReady
                  v.remRxLinkReady := phyRxMaster.tData(168);

                  -- BYTE[63:48] = LocalData
                  v.pgpRxOut.remLinkData := phyRxMaster.tData(511 downto 384);

                  -- Check if not NULL marker (BYTE[18] != 0xFF) and not EOF
                  if (phyRxMaster.tData(151 downto 144) /= x"FF") and (phyRxMaster.tLast = '0') then
                     -- Next state
                     v.state := PAYLOAD_S;
                  end if;

               end if;
            end if;
         ----------------------------------------------------------------------
         when PAYLOAD_S =>
            -- Check if read to move data
            if (phyRxMaster.tValid = '1') then

               -- Advance the output pipeline
               v.pgpRxMasters(0) := r.pgpRxMasters(1);

               -- Cache the data
               v.pgpRxMasters(1) := phyRxMaster;

               -- Update the metadata
               v.pgpRxMasters(1).tLast := '0';
               v.pgpRxMasters(1).tKeep := (others => '1');
               v.pgpRxMasters(1).tUser := (others => '0');
               ssiSetUserSof(PGP_ETH_AXIS_CONFIG_C, v.pgpRxMasters(1), r.sof);

               -- Reset the flag
               v.sof := '0';

               -- Check for last word
               if (phyRxMaster.tLast = '1') then

                  -- Stop the footer from getting in user data stream
                  v.pgpRxMasters(1).tValid := '0';

                  -- Check for a non-32-bit footer
                  if (phyRxMaster.tKeep(63 downto 0) /= x"0000_0000_0000_000F") then

                     -- Terminate the frame with error
                     v.pgpRxMasters(0).tLast := '1';
                     ssiSetUserEofe(PGP_ETH_AXIS_CONFIG_C, v.pgpRxMasters(0), '1');

                     -- Set the flag
                     v.pgpRxOut.frameRxErr := '1';

                     -- Closing the connection
                     v.aliveCnt := (others => '0');

                  else

                     -- Check for EOF
                     if (phyRxMaster.tData(8) = '1') then

                        -- Set EOF
                        v.pgpRxMasters(0).tLast := '1';

                        -- Set EOFE
                        ssiSetUserEofe(PGP_ETH_AXIS_CONFIG_C, v.pgpRxMasters(0), phyRxMaster.tData(9));

                        -- Update the last data stream metadata
                        v.pgpRxMasters(0).tKeep := genTKeep(conv_integer(phyRxMaster.tData(7 downto 0)));

                        -- Check for EOFE
                        if (phyRxMaster.tData(9) = '1') then
                           -- Set the flag
                           v.pgpRxOut.frameRxErr := '1';
                        else
                           -- Set the flag
                           v.pgpRxOut.frameRx := '1';
                        end if;

                     end if;

                     -- BYTE[3:2] = Virtual Channel Pause
                     v.pgpRxOut.remRxPause := phyRxMaster.tData(31 downto 16);

                  end if;

                  -- Next state
                  v.state := IDLE_S;

               end if;

            end if;
      ----------------------------------------------------------------------
      end case;

      for i in NUM_VC_G-1 downto 0 loop
         v.remRxFifoCtrl(i).pause := v.pgpRxOut.remRxPause(i);
      end loop;

      -- Outputs        
      pgpRxMaster    <= r.pgpRxMasters(0);
      pgpRxOut       <= r.pgpRxOut;
      remoteMac      <= r.remoteMac;
      locRxLinkReady <= r.locRxLinkReady;
      remRxLinkReady <= r.remRxLinkReady;
      remRxFifoCtrl  <= r.remRxFifoCtrl;

      -- Reset
      if (pgpRst = '1') or (phyRxRdy = '0') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (pgpClk) is
   begin
      if rising_edge(pgpClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   U_DeMux : entity work.AxiStreamDeMux
      generic map (
         TPD_G         => TPD_G,
         NUM_MASTERS_G => NUM_VC_G,
         MODE_G        => "INDEXED",
         PIPE_STAGES_G => 0,
         TDEST_HIGH_G  => 7,
         TDEST_LOW_G   => 0)
      port map (
         axisClk      => pgpClk,
         axisRst      => pgpRst,
         sAxisMaster  => pgpRxMaster,
         sAxisSlave   => open,
         mAxisMasters => pgpRxMasters,
         mAxisSlaves  => (others => AXI_STREAM_SLAVE_FORCE_C));

end rtl;
