-------------------------------------------------------------------------------
-- Title      : HTSP: https://confluence.slac.stanford.edu/x/pQmODw
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: HTSP Ethernet Receiver
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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;
use surf.HtspPkg.all;

entity HtspRx is
   generic (
      TPD_G    : time                  := 1 ns;
      NUM_VC_G : integer range 1 to 16 := 4);
   port (
      -- Ethernet Configuration
      remoteMac      : out slv(47 downto 0);
      localMac       : in  slv(47 downto 0);
      broadcastMac   : in  slv(47 downto 0);
      etherType      : in  slv(15 downto 0);
      -- User interface
      htspClk        : in  sl;
      htspRst        : in  sl;
      htspRxIn       : in  HtspRxInType;
      htspRxOut      : out HtspRxOutType;
      htspRxMasters  : out AxiStreamMasterArray(NUM_VC_G-1 downto 0);
      -- Status of local receive FIFOs
      remRxFifoCtrl  : out AxiStreamCtrlArray(NUM_VC_G-1 downto 0);
      remRxLinkReady : out sl;
      locRxLinkReady : out sl;
      -- PHY interface
      phyRxRdy       : in  sl;
      phyRxMaster    : in  AxiStreamMasterType);
end entity HtspRx;

architecture rtl of HtspRx is

   type StateType is (
      IDLE_S,
      PAYLOAD_S);

   type RegType is record
      aliveCnt       : slv(23 downto 0);
      sof            : sl;
      locRxLinkReady : sl;
      remRxLinkReady : sl;
      tid            : slv(7 downto 0);
      tDest          : slv(7 downto 0);
      remoteMac      : slv(47 downto 0);
      htspRxOut      : HtspRxOutType;
      remRxFifoCtrl  : AxiStreamCtrlArray(NUM_VC_G-1 downto 0);
      htspRxMasters  : AxiStreamMasterArray(1 downto 0);
      state          : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      aliveCnt       => (others => '0'),
      sof            => '0',
      locRxLinkReady => '0',
      remRxLinkReady => '0',
      tid            => (others => '0'),
      tDest          => (others => '0'),
      remoteMac      => (others => '0'),
      htspRxOut      => HTSP_RX_OUT_INIT_C,
      remRxFifoCtrl  => (others => AXI_STREAM_CTRL_INIT_C),
      htspRxMasters  => (others => AXI_STREAM_MASTER_INIT_C),
      state          => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal htspRxMaster : AxiStreamMasterType;

   attribute dont_touch      : string;
   attribute dont_touch of r : signal is "TRUE";

begin

   comb : process (broadcastMac, etherType, htspRst, localMac, phyRxMaster,
                   phyRxRdy, r) is
      variable v       : RegType;
      variable eofe    : sl;
      variable hdrXsum : slv(15 downto 0);
   begin
      -- Latch the current value
      v := r;

      -- Update variables
      eofe    := ssiGetUserEofe(HTSP_AXIS_CONFIG_C, phyRxMaster);
      hdrXsum := (others => '0');

      -- Update/Reset the flags
      v.htspRxOut.phyRxActive    := phyRxRdy;
      v.htspRxOut.linkReady      := r.locRxLinkReady;
      v.htspRxOut.frameRx        := '0';
      v.htspRxOut.frameRxErr     := '0';
      v.htspRxOut.linkDown       := '0';
      v.htspRxOut.opCodeEn       := '0';
      v.htspRxOut.remRxLinkReady := r.remRxLinkReady;
      v.htspRxMasters(0).tValid  := '0';

      -- Check for PHY not ready
      if (phyRxRdy = '0') then
         -- Close the connection
         v.aliveCnt           := (others => '0');
         v.locRxLinkReady     := '0';
         v.htspRxOut.linkDown := r.locRxLinkReady;

      -- Check for roll over
      elsif (r.aliveCnt = 0) then
         -- Set the flag
         v.locRxLinkReady := '0';

      -- Else the link is up
      else
         -- Set the flag
         v.locRxLinkReady := '1';
         -- Decrement the counter
         v.aliveCnt       := r.aliveCnt - 1;
      end if;

      -- Check for link down event
      if (v.aliveCnt = 0) and (r.aliveCnt /= 0) then
         -- Set the flag
         v.htspRxOut.linkDown := '1';
      end if;

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check if read to move data
            if (phyRxMaster.tValid = '1') and (phyRxRdy = '1') then

               -- Calculate the checksum
               for i in 29 downto 0 loop
                  hdrXsum := hdrXsum + phyRxMaster.tData(8*i+7 downto 8*i);
               end loop;
               for i in 63 downto 32 loop
                  hdrXsum := hdrXsum + phyRxMaster.tData(8*i+7 downto 8*i);
               end loop;
               hdrXsum := not(hdrXsum);  -- one's complement

               ---------------------------
               -- Check for a valid header
               ---------------------------
               if ((phyRxMaster.tData(47 downto 0) = localMac) or (phyRxMaster.tData(47 downto 0) = broadcastMac))  -- BYTE[5:0] = Destination MAC or Broadcast MAC
                  and (phyRxMaster.tData(111 downto 96) = etherType)  -- BYTE[13:12] = EtherType
                  and (phyRxMaster.tData(119 downto 112) = HTSP_VERSION_C) then  -- BYTE[14] = Version

                  -- Check for invalid checksum
                  if (phyRxMaster.tData(255 downto 240) /= hdrXsum) then  -- Valid checksum

                     -- Close the connection
                     v.aliveCnt           := (others => '0');
                     v.locRxLinkReady     := '0';
                     v.htspRxOut.linkDown := r.locRxLinkReady;

                     -- Set the flag
                     v.htspRxOut.frameRxErr := '1';

                  -- Else good checksum
                  else

                     -- Remote connection detected
                     v.aliveCnt := (others => '1');

                     -- BYTE[11:6] = Source MAC
                     v.remoteMac := phyRxMaster.tData(95 downto 48);

                     -- BYTE[15] = TID
                     v.tid := phyRxMaster.tData(127 downto 120);

                     -- BYTE[17:16] = Virtual Channel Pause
                     v.htspRxOut.remRxPause := phyRxMaster.tData(143 downto 128);

                     -- Check if not NULL marker (BYTE[18] != 0xFF)
                     if (phyRxMaster.tData(151 downto 144) /= x"FF") then

                        -- BYTE[18] = Virtual Channel Index
                        v.tDest := phyRxMaster.tData(151 downto 144);

                        -- BYTE[19] = SOF
                        v.sof := phyRxMaster.tData(152);

                     end if;

                     -- Check for BYTE[20] = OP-Code Enable
                     if (phyRxMaster.tData(160) = '1') then

                        -- BYTE[20] = OP-Code Enable
                        v.htspRxOut.opCodeEn := '1';

                        -- BYTE[47:32] = OpCodeData
                        v.htspRxOut.opCode := phyRxMaster.tData(383 downto 256);

                     end if;


                     -- Check for BYTE[21] = RxLinkReady
                     v.remRxLinkReady := phyRxMaster.tData(168);

                     -- BYTE[63:48] = LocalData
                     v.htspRxOut.remLinkData := phyRxMaster.tData(511 downto 384);

                     -- Check if not NULL marker (BYTE[18] != 0xFF) and not EOF
                     if (phyRxMaster.tData(151 downto 144) /= x"FF") and (phyRxMaster.tLast = '0') then

                        -- Reset the counter
                        v.htspRxOut.frameRxSize := (others => '0');

                        -- Next state
                        v.state := PAYLOAD_S;

                     end if;

                  end if;
               end if;
            end if;
         ----------------------------------------------------------------------
         when PAYLOAD_S =>
            -- Check if read to move data
            if (phyRxMaster.tValid = '1') and (phyRxRdy = '1') then

               -- Advance the output pipeline
               v.htspRxMasters(0) := r.htspRxMasters(1);

               -- Cache the data
               v.htspRxMasters(1) := phyRxMaster;

               -- Update the metadata
               v.htspRxMasters(1).tLast := '0';
               v.htspRxMasters(1).tKeep := (others => '1');
               v.htspRxMasters(1).tUser := (others => '0');
               v.htspRxMasters(1).tDest := r.tDest;
               ssiSetUserSof(HTSP_AXIS_CONFIG_C, v.htspRxMasters(1), r.sof);

               -- Reset the flag
               v.sof := '0';

               -- Check for last word (footer)
               if (phyRxMaster.tLast = '1') then

                  -- Stop the footer from getting in user data stream
                  v.htspRxMasters(1).tValid := '0';

                  -- Update the last data stream metadata
                  v.htspRxMasters(0).tKeep := genTKeep(conv_integer(phyRxMaster.tData(7 downto 0)));

                  -- Increment the counter
                  v.htspRxOut.frameRxSize := r.htspRxOut.frameRxSize + getTKeep(v.htspRxMasters(0).tKeep, HTSP_AXIS_CONFIG_C);

                  -- Check error checking
                  if (phyRxMaster.tKeep(63 downto 0) /= x"0000_0000_0000_003F") or  -- non-64-bit footer
                     (phyRxMaster.tData(47 downto 32) /= v.htspRxOut.frameRxSize) then  -- footer size doesn't match measured payload size

                     -- Terminate the frame with error
                     v.htspRxMasters(0).tLast := '1';
                     ssiSetUserEofe(HTSP_AXIS_CONFIG_C, v.htspRxMasters(0), '1');

                     -- Set the flag
                     v.htspRxOut.frameRxErr := '1';

                     -- Closing the connection
                     v.aliveCnt := (others => '0');

                  else

                     -- Set EOF (force EOF if EOFE detected)
                     v.htspRxMasters(0).tLast := phyRxMaster.tData(8) or phyRxMaster.tData(9);

                     -- Set EOFE
                     eofe := eofe or phyRxMaster.tData(9);
                     ssiSetUserEofe(HTSP_AXIS_CONFIG_C, v.htspRxMasters(0), eofe);

                     -- Set the flag
                     v.htspRxOut.frameRxErr := eofe;

                     -- Set the flag
                     v.htspRxOut.frameRx := v.htspRxMasters(0).tLast and not eofe;

                     -- BYTE[3:2] = Virtual Channel Pause
                     v.htspRxOut.remRxPause := phyRxMaster.tData(31 downto 16);

                  end if;

                  -- Next state
                  v.state := IDLE_S;

               -- Else payload data
               else

                  -- Monitor the Payload frame size
                  if (v.htspRxMasters(0).tValid = '1') then
                     -- Increment the counter
                     v.htspRxOut.frameRxSize := r.htspRxOut.frameRxSize + getTKeep(v.htspRxMasters(0).tKeep, HTSP_AXIS_CONFIG_C);
                  end if;

               end if;

            elsif (phyRxRdy = '0') then

               -- Next state
               v.state := IDLE_S;

            end if;
      ----------------------------------------------------------------------
      end case;

      -- Map the pause bits into the record type
      for i in NUM_VC_G-1 downto 0 loop
         v.remRxFifoCtrl(i).pause := v.htspRxOut.remRxPause(i);
      end loop;

      -- Check if link went down down
      if (r.htspRxOut.linkDown = '1') then
         -- Reset the remote mac
         v.remoteMac      := (others => '0');
         -- Reset the status flag
         v.remRxLinkReady := '0';
      end if;

      -- Outputs
      htspRxMaster   <= r.htspRxMasters(0);
      htspRxOut      <= r.htspRxOut;
      remoteMac      <= r.remoteMac;
      locRxLinkReady <= r.locRxLinkReady;
      remRxLinkReady <= r.remRxLinkReady;
      remRxFifoCtrl  <= r.remRxFifoCtrl;

      -- Reset
      if (htspRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (htspClk) is
   begin
      if rising_edge(htspClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   U_DeMux : entity surf.AxiStreamDeMux
      generic map (
         TPD_G         => TPD_G,
         NUM_MASTERS_G => NUM_VC_G,
         MODE_G        => "INDEXED",
         PIPE_STAGES_G => 0,
         TDEST_HIGH_G  => 7,
         TDEST_LOW_G   => 0)
      port map (
         axisClk      => htspClk,
         axisRst      => htspRst,
         sAxisMaster  => htspRxMaster,
         sAxisSlave   => open,
         mAxisMasters => htspRxMasters,
         mAxisSlaves  => (others => AXI_STREAM_SLAVE_FORCE_C));

end rtl;
