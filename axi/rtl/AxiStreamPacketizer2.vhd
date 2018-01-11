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

entity AxiStreamPacketizer2 is

   generic (
      TPD_G                : time             := 1 ns;
      CRC_EN_G             : boolean          := false;
      CRC_POLY_G           : slv(31 downto 0) := x"04C11DB7";
      MAX_PACKET_BYTES_G   : integer          := 256*8;  -- Must be a multiple of 8
      OUTPUT_SSI_G         : boolean          := true;
      INPUT_PIPE_STAGES_G  : integer          := 0;
      OUTPUT_PIPE_STAGES_G : integer          := 0);
   port (
      -- AXI-Lite Interface for local registers 
      axisClk : in sl;
      axisRst : in sl;

      rearbitrate : out sl;
      sAxisMaster : in  AxiStreamMasterType;
      sAxisSlave  : out AxiStreamSlaveType;

      mAxisMaster : out AxiStreamMasterType;
      mAxisSlave  : in  AxiStreamSlaveType);

end entity AxiStreamPacketizer2;

architecture rtl of AxiStreamPacketizer2 is

   -- Packetizer constants
   constant MAX_WORD_COUNT_C : integer := (MAX_PACKET_BYTES_G / 8) - 1;

   constant AXIS_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 8,
      TDEST_BITS_C  => 0,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_NORMAL_C,
      TUSER_BITS_C  => ite(OUTPUT_SSI_G, 2, 0),
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);

   type StateType is (HEADER_S, MOVE_S, TAIL_S);

   type RegType is record
      state            : StateType;
      packetNumber     : slv(15 downto 0);
      packetActive     : sl;
      activeTDest      : slv(7 downto 0);
      ramWe            : sl;
      wordCount        : slv(bitSize(MAX_WORD_COUNT_C)-1 downto 0);
      eof              : sl;
      lastByteCount    : slv(3 downto 0);
      tUserLast        : slv(7 downto 0);
      rearbitrate      : sl;
      crcDataValid     : sl;
      crcDataWidth     : slv(2 downto 0);
      crcReset         : sl;
      inputAxisSlave   : AxiStreamSlaveType;
      outputAxisMaster : AxiStreamMasterType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state            => HEADER_S,
      packetNumber     => (others => '0'),
      packetActive     => '0',
      activeTDest      => (others => '0'),
      ramWe            => '0',
      wordCount        => (others => '0'),
      eof              => '0',
      lastByteCount    => (others => '0'),
      tUserLast        => (others => '0'),
      rearbitrate      => '0',
      crcDataValid     => '0',
      crcDataWidth     => (others => '0'),
      crcReset         => '0',
      inputAxisSlave   => AXI_STREAM_SLAVE_INIT_C,
      outputAxisMaster => axiStreamMasterInit(AXIS_CONFIG_C));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal packetNumberOut : slv(15 downto 0);
   signal packetActiveOut : sl;

   signal inputAxisMaster  : AxiStreamMasterType;
   signal inputAxisSlave   : AxiStreamSlaveType;
   signal outputAxisMaster : AxiStreamMasterType;
   signal outputAxisSlave  : AxiStreamSlaveType;

   signal crcOut : slv(31 downto 0);

begin

   assert ((MAX_PACKET_BYTES_G rem 8) = 0)
      report "MAX_PACKET_BYTES_G must be a multiple of 8" severity error;

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
         DATA_WIDTH_G => 17,
         ADDR_WIDTH_G => 8)
      port map (
         clka               => axisClk,                -- [in]
         rsta               => axisRst,                -- [in]
         wea                => r.ramWe,                -- [in]
         addra              => r.activeTDest,          -- [in]
         dina(15 downto 0)  => r.packetNumber,         -- [in]
         dina(16)           => r.packetActive,         -- [in]
         clkb               => axisClk,                -- [in]
         rstb               => axisRst,                -- [in]
         addrb              => inputAxisMaster.tDest,  -- [in]
         doutb(15 downto 0) => packetNumberOut,        -- [out]
         doutb(16)          => packetActiveOut);       --[out]

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

   -------------------------------------------------------------------------------------------------
   -- Accumulation sequencing, DMA ring buffer, and AXI-Lite logic
   -------------------------------------------------------------------------------------------------
   comb : process (axisRst, crcOut, inputAxisMaster, outputAxisSlave, packetActiveOut,
                   packetNumberOut, r) is
      variable v : RegType;
   begin
      v := r;

      if (outputAxisSlave.tReady = '1') then
         v.outputAxisMaster.tValid := '0';
      end if;

      -- Don't accept new data by default
      v.inputAxisSlave.tReady := '0';

      -- Don't write new packet number by default
      v.ramWe := '0';

      -- Don't activate CRC by default
      v.crcDataValid := '0';

      -- Main state machine
      case r.state is
         when HEADER_S =>
            -- Place header on output when new data arrived
            v.wordCount := (others => '0');
            v.crcReset  := '1';
            if (inputAxisMaster.tValid = '1' and v.outputAxisMaster.tValid = '0') then
               v.outputAxisMaster                     := axiStreamMasterInit(AXIS_CONFIG_C);
               v.outputAxisMaster.tValid              := inputAxisMaster.tValid;
               v.outputAxisMaster.tData(7 downto 0)   := inputAxisMaster.tUser(7 downto 0);
               v.outputAxisMaster.tData(15 downto 8)  := inputAxisMaster.tDest(7 downto 0);
               v.outputAxisMaster.tData(23 downto 16) := inputAxisMaster.tId(7 downto 0);
               v.outputAxisMaster.tData(24)           := not packetActiveOut;
               v.outputAxisMaster.tData(47 downto 32) := packetNumberOut;
               -- Frame ID on 63:48?
               axiStreamSetUserBit(AXIS_CONFIG_C, v.outputAxisMaster, SSI_SOF_C, '1', 0);  -- SOF
               v.packetNumber                         := packetNumberOut + 1;
               v.packetActive                         := '1';
               v.activeTDest                          := inputAxisMaster.tDest;
               v.state                                := MOVE_S;
            end if;

         when MOVE_S =>
            v.crcReset      := '0';
            v.lastByteCount := "1000";
            v.crcDataWidth  := "111";
            if (inputAxisMaster.tvalid = '1' and v.outputAxisMaster.tValid = '0') then
               -- Accept the data
               v.inputAxisSlave.tReady := '1';

               -- Send data through
               v.outputAxisMaster       := inputAxisMaster;
               v.outputAxisMaster.tUser := (others => '0');
               v.outputAxisMaster.tDest := (others => '0');
               v.outputAxisMaster.tId   := (others => '0');

               -- Increment word count with each txn
               v.wordCount := r.wordCount + 1;

               -- Reach max packet size. Append tail.
               if (r.wordCount = MAX_WORD_COUNT_C) then
                  v.state := TAIL_S;
                  v.ramWe := '1';
               end if;

               -- Upstream interleave detected, append tail
               if (inputAxisMaster.tDest /= r.activeTDest) then
                  v.state                   := TAIL_S;
                  v.ramWe                   := '1';
                  v.inputAxisSlave.tReady   := '0';  -- Hold acceptance of new data
                  v.outputAxisMaster        := r.outputAxisMaster;
                  v.outputAxisMaster.tValid := '0';  -- And transmission
               end if;

               -- End of frame, append tail
               if (inputAxisMaster.tLast = '1') then
                  v.ramWe                  := '1';
                  v.packetNumber           := (others => '0');
                  v.packetActive           := '0';
                  v.state                  := TAIL_S;
                  v.tUserLast              := inputAxisMaster.tUser(7 downto 0);
                  v.eof                    := '1';
                  v.lastByteCount          := toSlv(getTKeep(inputAxisMaster.tKeep), 4);
--                  v.crcDataWidth           := toSlv(getTKeep(inputAxisMaster.tKeep)-1, 3);
                  v.outputAxisMaster.tLast := '0';
               end if;

               v.crcDataValid := v.outputAxisMaster.tValid;
            end if;

         when TAIL_S =>
            -- Insert tail when master side is ready for it
            if (v.outputAxisMaster.tValid = '0') then
               v.outputAxisMaster.tValid              := '1';
               v.outputAxisMaster.tKeep               := X"00FF";
               v.outputAxisMaster.tData               := (others => '0');
               v.outputAxisMaster.tData(8)            := r.eof;
               v.outputAxisMaster.tData(7 downto 0)   := r.tUserLast;
               v.outputAxisMaster.tData(19 downto 16) := r.lastByteCount;
               v.outputAxisMaster.tData(63 downto 32) := ite(CRC_EN_G, crcOut, X"00000000");
               -- Myabe set tuser when SSI enabled?
               v.outputAxisMaster.tUser               := (others => '0');
               v.outputAxisMaster.tLast               := '1';
               v.eof                                  := '0';       -- Clear EOF for next frame
               v.tUserLast                            := (others => '0');
               v.state                                := HEADER_S;  -- Go to idle and wait for new data
            end if;

      end case;

      v.outputAxisMaster.tStrb := v.outputAxisMaster.tKeep;

      ----------------------------------------------------------------------------------------------
      -- Reset and output assignment
      ----------------------------------------------------------------------------------------------
      if (axisRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      inputAxisSlave   <= v.inputAxisSlave;
      outputAxisMaster <= r.outputAxisMaster;
      rearbitrate      <= r.rearbitrate;

   end process comb;

   seq : process (axisClk) is
   begin
      if (rising_edge(axisClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
   -- Output pipeline
   -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
   U_AxiStreamPipeline_Output : entity work.AxiStreamPipeline
      generic map (
         TPD_G         => TPD_G,
         PIPE_STAGES_G => OUTPUT_PIPE_STAGES_G)
      port map (
         axisClk     => axisClk,           -- [in]
         axisRst     => axisRst,           -- [in]
         sAxisMaster => outputAxisMaster,  -- [in]
         sAxisSlave  => outputAxisSlave,   -- [out]
         mAxisMaster => mAxisMaster,       -- [out]
         mAxisSlave  => mAxisSlave);       -- [in]


end architecture rtl;

