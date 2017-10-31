-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Formats an AXI-Stream for a transport link.
-- Sideband fields are placed into the data stream in a header.
-- Long frames are broken into smaller packets.
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
use work.AxiStreamPacketizer2Pkg.all;

entity AxiStreamDepacketizer2 is

   generic (
      TPD_G               : time             := 1 ns;
      CRC_EN_G            : boolean          := true;
      CRC_POLY_G          : slv(31 downto 0) := x"04C11DB7";
      INPUT_PIPE_STAGES_G : integer          := 0);
   port (
      -- AXI-Lite Interface for local registers 
      axisClk : in sl;
      axisRst : in sl;

      sAxisMaster : in  AxiStreamMasterType;
      sAxisSlave  : out AxiStreamSlaveType;

      linkGood : in  sl;
      debug    : out Packetizer2DebugType;

      mAxisMaster : out AxiStreamMasterType;
      mAxisSlave  : in  AxiStreamSlaveType);

end entity AxiStreamDepacketizer2;

architecture rtl of AxiStreamDepacketizer2 is

   constant AXIS_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 8,
      TDEST_BITS_C  => 8,
      TID_BITS_C    => 8,
      TKEEP_MODE_C  => TKEEP_COMP_C,
      TUSER_BITS_C  => 8,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);

   type StateType is (HEADER_S, MOVE_S, TERMINATE_S);

   type RegType is record
      state            : StateType;
      activeTDest      : slv(7 downto 0);
      packetNumber     : slv(15 downto 0);
      packetActive     : sl;
      sentEofe         : sl;
      ramWe            : sl;
      sideband         : sl;
      crcDataValid     : sl;
      crcDataWidth     : slv(2 downto 0);
      crcReset         : sl;
      debug            : Packetizer2DebugType;
      inputAxisSlave   : AxiStreamSlaveType;
      outputAxisMaster : AxiStreamMasterArray(1 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      state            => HEADER_S,
      activeTDest      => (others => '0'),
      packetNumber     => (others => '0'),
      packetActive     => '0',
      sentEofe         => '0',
      ramWe            => '0',
      sideband         => '0',
      crcDataValid     => '0',
      crcDataWidth     => "111",
      crcReset         => '1',
      debug            => PACKETIZER2_DEBUG_INIT_C,
      inputAxisSlave   => AXI_STREAM_SLAVE_INIT_C,
      outputAxisMaster => (others => axiStreamMasterInit(AXIS_CONFIG_C)));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal packetNumberRam : slv(15 downto 0);
   signal packetActiveRam : sl;
   signal sentEofeRam     : sl;

   signal crcOut : slv(31 downto 0);

   signal inputAxisMaster  : AxiStreamMasterType;
   signal inputAxisSlave   : AxiStreamSlaveType;
   signal outputAxisMaster : AxiStreamMasterType;
   signal outputAxisSlave  : AxiStreamSlaveType;

begin

   -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
   -- Input pipeline
   -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
   U_AxiStreamPipeline_Input : entity work.AxiStreamPipeline
      generic map (
         TPD_G         => TPD_G,
         PIPE_STAGES_G => INPUT_PIPE_STAGES_G)
      port map (
         axisClk     => axisClk,          -- [in]
         axisRst     => axisRst,          -- [in]
         sAxisMaster => sAxisMaster,      -- [in]
         sAxisSlave  => sAxisSlave,       -- [out]
         mAxisMaster => inputAxisMaster,  -- [out]
         mAxisSlave  => inputAxisSlave);  -- [in]

   -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
   -- Output pipeline
   -- Output kinda stutters awkwardly without this
   -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
   U_AxiStreamPipeline_Output : entity work.AxiStreamPipeline
      generic map (
         TPD_G         => TPD_G,
         PIPE_STAGES_G => 1)
      port map (
         axisClk     => axisClk,           -- [in]
         axisRst     => axisRst,           -- [in]
         sAxisMaster => outputAxisMaster,  -- [in]
         sAxisSlave  => outputAxisSlave,   -- [out]
         mAxisMaster => mAxisMaster,       -- [out]
         mAxisSlave  => mAxisSlave);       -- [in]

   -------------------------------------------------------------------------------------------------
   -- Packet Count ram
   -- track current frame number, packet count and physical channel for each tDest
   -------------------------------------------------------------------------------------------------
   U_DualPortRam_1 : entity work.DualPortRam
      generic map (
         TPD_G        => TPD_G,
         BRAM_EN_G    => false,
         REG_EN_G     => false,
         DOA_REG_G    => false,
         DOB_REG_G    => false,
         BYTE_WR_EN_G => false,
         DATA_WIDTH_G => 18,
         ADDR_WIDTH_G => 8)
      port map (
         clka               => axisClk,           -- [in]
         rsta               => axisRst,           -- [in]
         wea                => rin.ramWe,         -- [in]
         addra              => rin.activeTDest,   -- [in]
         dina(15 downto 0)  => rin.packetNumber,  -- [in]
         dina(16)           => rin.packetActive,  -- [in]
         dina(17)           => rin.sentEofe,      -- [in]
--          clkb               => axisClk,                             -- [in]
--          rstb               => axisRst,                             -- [in]
--          addrb              => inputAxisMaster.tData(15 downto 8),  -- [in]
         douta(15 downto 0) => packetNumberRam,   -- [out]
         douta(16)          => packetActiveRam,   -- [out]
         douta(17)          => sentEofeRam);      -- [out]
                
   ETH_CRC : if (CRC_POLY_G = x"04C11DB7") generate         
      U_Crc32 : entity work.Crc32Parallel
         generic map (
            TPD_G            => TPD_G,
            INPUT_REGISTER_G => false,
            BYTE_WIDTH_G     => 8,
            CRC_INIT_G       => X"FFFFFFFF")
         port map (
            crcOut       => crcOut,                              -- [out]
            crcClk       => axisClk,                             -- [in]
            crcDataValid => rin.crcDataValid,                    -- [in]
            crcDataWidth => rin.crcDataWidth,                    -- [in]
            crcIn        => inputAxisMaster.tData(63 downto 0),  -- [in]
            crcReset     => rin.crcReset);                       -- [in]
   end generate;
   
   GEN_CRC : if (CRC_POLY_G /= x"04C11DB7") generate         
      U_Crc32 : entity work.Crc32
         generic map (
            TPD_G            => TPD_G,
            INPUT_REGISTER_G => false,
            BYTE_WIDTH_G     => 8,
            CRC_INIT_G       => X"FFFFFFFF",
            CRC_POLY_G       => CRC_POLY_G)
         port map (
            crcOut       => crcOut,                              -- [out]
            crcClk       => axisClk,                             -- [in]
            crcDataValid => rin.crcDataValid,                    -- [in]
            crcDataWidth => rin.crcDataWidth,                    -- [in]
            crcIn        => inputAxisMaster.tData(63 downto 0),  -- [in]
            crcReset     => rin.crcReset);                       -- [in]
   end generate;         
   
   comb : process (axisRst, crcOut, linkGood, sentEofeRam, inputAxisMaster, outputAxisSlave,
                   packetActiveRam, packetNumberRam, r) is
      variable v         : RegType;
      variable sof       : sl;
      variable lastBytes : integer;
   begin
      v := r;

      v.debug := PACKETIZER2_DEBUG_INIT_C;

      v.ramWe := '0';

      v.crcDataValid := '0';
      v.crcDataWidth := "111";

      if (linkGood = '0') then
         v.state := TERMINATE_S;
      end if;

      if (outputAxisSlave.tReady = '1') then
         v.outputAxisMaster(1).tValid := '0';
         v.outputAxisMaster(0).tValid := '0';
      end if;

      case r.state is
         when HEADER_S =>
            -- The header data won't be pushed to the output this cycle, so accept by default
            v.inputAxisSlave.tready := '1';
            v.outputAxisMaster(1)   := axiStreamMasterInit(AXIS_CONFIG_C);

            -- Reset the CRC for the next packet
            v.crcReset := '1';

            -- Advance the output pipeline
            if (r.outputAxisMaster(1).tValid = '1' and v.outputAxisMaster(0).tValid = '0') then
               v.outputAxisMaster(0) := r.outputAxisMaster(1);
            end if;


            -- Process an incomming transaction
            if (inputAxisMaster.tValid = '1' and v.outputAxisMaster(1).tValid = '0') then
               -- Must be an SSI SOF
               -- If txn is not a header, data will be dumped by doing nothing here
               -- This is all we can do, since we don't know which tdest the data belongs to
               if (ssiGetuserSof(AXIS_CONFIG_C, inputAxisMaster) = '1') then

                  -- Assign sideband fields
                  v.outputAxisMaster(1).tDest(7 downto 0) := inputAxisMaster.tData(15 downto 8);
                  v.outputAxisMaster(1).tId(7 downto 0)   := inputAxisMaster.tData(23 downto 16);
                  v.outputAxisMaster(1).tUser(7 downto 0) := inputAxisMaster.tData(7 downto 0);

                  sof            := inputAxisMaster.tData(24);
                  v.packetNumber := inputAxisMaster.tData(47 downto 32);

                  v.activeTDest := v.outputAxisMaster(1).tDest(7 downto 0);

                  -- Assert SSI SOF if SOF header bit set
                  axiStreamSetUserBit(AXIS_CONFIG_C, v.outputAxisMaster(1), SSI_SOF_C, sof, 0);  -- SOF


                  if (sof = not packetActiveRam and v.packetNumber = packetNumberRam) then
                     -- Header metadata as expected
                     v.state    := MOVE_S;
                     v.sideband := '1';

                     -- Set packetActive in ram for this tdest
                     -- v.packetNumber is already correct
                     v.packetActive := '1';
                     v.sentEofe     := '0';  -- Clear any frame error
                     v.ramWe        := '1';
                     v.debug.sop    := '1';
                     v.debug.sof    := sof;
                  else
                     -- There was a missing packet!
                     if (sentEofeRam = '0') then
                        -- Haven't yet sent an EOFE for this frame. Do so now.
                        ssiSetUserEofe(AXIS_CONFIG_C, v.outputAxisMaster(1), '1');
                        v.outputAxisMaster(1).tLast  := '1';
                        v.outputAxisMaster(1).tValid := '1';
                        v.debug.eof                  := '1';
                        v.debug.eofe                 := '1';
                     end if;
                     v.packetNumber      := (others => '0');
                     v.packetActive      := '0';
                     v.sentEofe          := '1';
                     v.ramWe             := '1';
                     v.debug.packetError := '1';
                  end if;

               end if;
            end if;

         when MOVE_S =>
            v.inputAxisSlave.tReady      := outputAxisSlave.tReady;
            v.outputAxisMaster(1).tvalid := r.outputAxisMaster(1).tvalid;

            v.crcReset := '0';

            if (inputAxisMaster.tValid = '1' and v.outputAxisMaster(0).tValid = '0') then
               -- Advance the pipeline
               v.outputAxisMaster(1)       := inputAxisMaster;
               -- Keep sideband data from header
               v.outputAxisMaster(1).tDest := r.outputAxisMaster(1).tDest;
               v.outputAxisMaster(1).tId   := r.outputAxisMaster(1).tId;
               if (r.sideband = '1') then
                  -- But tUser only for first output txn
                  v.outputAxisMaster(1).tUser := r.outputAxisMaster(1).tUser;
                  v.sideband                  := '0';
               end if;
               v.crcDataValid := '1';

               v.outputAxisMaster(0) := r.outputAxisMaster(1);

               -- End of packet
               if (inputAxisMaster.tLast = '1') then
                  v.state                      := HEADER_S;
                  v.outputAxisMaster(1).tValid := '0';
                  v.crcDataValid               := '0';

                  -- Append EOF metadata to previous txn which has been held
                  lastBytes                   := conv_integer(inputAxisMaster.tData(19 downto 16));
                  axiStreamSetUserField(AXIS_CONFIG_C, v.outputAxisMaster(0), inputAxisMaster.tData(7 downto 0), lastBytes);
                  v.outputAxisMaster(0).tLast := inputAxisMaster.tData(8);
                  v.outputAxisMaster(0).tKeep := genTkeep(conv_integer(inputAxisMaster.tData(19 downto 16)));

                  -- Verify the CRC. Set EOFE if fail.
                  if (crcOut /= inputAxisMaster.tData(63 downto 32) and CRC_EN_G) then
                     axiStreamSetUserBit(AXIS_CONFIG_C, v.outputAxisMaster(0), SSI_EOFE_C, '1', lastBytes);
                  end if;


                  if (inputAxisMaster.tData(8) = '1') then
                     -- If EOF, reset packetActive and packetNumber                     
                     v.packetActive := '0';
                     v.packetNumber := (others => '0');
                     v.sentEofe     := '0';
                     v.ramWe        := '1';
                     v.debug.eof    := '1';
                     v.debug.eop    := '1';
                  elsif (axiStreamGetUserBit(AXIS_CONFIG_C, v.outputAxisMaster(0), SSI_EOFE_C, lastBytes) = '1') then
                     -- EOP with error, do EOFE
                     v.outputAxisMaster(0).tLast := '1';
                     v.packetActive              := '0';
                     v.packetNumber              := (others => '0');
                     v.sentEofe                  := '1';
                     v.ramWe                     := '1';
                     v.debug.eof                 := '1';
                     v.debug.eofe                := '1';
                     v.debug.eop                 := '1';
                  else
                     -- else increment packetNumber and set packetActive
                     v.packetActive := '1';
                     v.packetNumber := r.packetNumber + 1;
                     v.sentEofe     := '0';
                     v.ramWe        := '1';
                     v.debug.eop    := '1';
                  end if;

                  v.debug.packetError := axiStreamGetUserBit(AXIS_CONFIG_C, v.outputAxisMaster(0), SSI_EOFE_C, lastBytes);

               end if;
            end if;

         when TERMINATE_S =>
            -- Advance the output pipeline
            if (r.outputAxisMaster(1).tValid = '1' and v.outputAxisMaster(0).tValid = '0') then
               v.outputAxisMaster(0) := r.outputAxisMaster(1);
            end if;

            -- Terminate any open frames with EOFE
            if (v.outputAxisMaster(1).tValid = '0') then
               v.activeTDest  := r.activeTDest + 1;
               v.packetActive := '0';
               v.sentEofe     := '0';   -- Clear any frame error
               v.packetNumber := (others => '0');
               v.ramWe        := '1';

               ssiSetUserEofe(AXIS_CONFIG_C, v.outputAxisMaster(1), '1');
               v.outputAxisMaster(1).tLast             := '1';
               v.outputAxisMaster(1).tValid            := packetActiveRam;
               v.outputAxisMaster(1).tDest(7 downto 0) := v.activeTDest;
               v.debug.eof                             := packetActiveRam;
               v.debug.eofe                            := packetActiveRam;
            end if;

            -- Stop when link comes back
            if (linkGood = '1') then
               v.state := HEADER_S;
            end if;

      end case;

      ----------------------------------------------------------------------------------------------
      -- Reset and output assignment
      ----------------------------------------------------------------------------------------------
      if (axisRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      inputAxisSlave <= v.inputAxisSlave;

      outputAxisMaster <= r.outputAxisMaster(0);
      debug            <= r.debug;

   end process comb;

   seq : process (axisClk) is
   begin
      if (rising_edge(axisClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;

