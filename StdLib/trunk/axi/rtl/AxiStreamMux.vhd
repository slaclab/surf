-------------------------------------------------------------------------------
-- Title      : AXI Stream Multiplexer
-- Project    : General Purpose Core
-------------------------------------------------------------------------------
-- File       : AxiStreamMux.vhd
-- Author     : Ryan Herbst, rherbst@slac.stanford.edu
-- Created    : 2014-04-25
-- Last update: 2015-06-02
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-- Block to connect multiple incoming AXI streams into a single encoded
-- outbound stream. The destination field is updated accordingly.
-------------------------------------------------------------------------------
-- Copyright (c) 2014 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 04/25/2014: created.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.ArbiterPkg.all;
use work.AxiStreamPkg.all;

entity AxiStreamMux is
   generic (
      TPD_G         : time                  := 1 ns;
      NUM_SLAVES_G  : integer range 1 to 32 := 4;
      PIPE_STAGES_G : integer range 0 to 16 := 0;  -- mux be > 1 if cascading muxes
      TDEST_HIGH_G  : integer range 0 to 7  := 7;
      TDEST_LOW_G   : integer range 0 to 7  := 0);
   port (

      -- Clock and reset
      axisClk : in sl;
      axisRst : in sl;

      -- Slaves
      sAxisMasters : in  AxiStreamMasterArray(NUM_SLAVES_G-1 downto 0);
      sAxisSlaves  : out AxiStreamSlaveArray(NUM_SLAVES_G-1 downto 0);

      -- MUX Address
      sAxisAuto : in sl                                      := '1';  -- '1' for AUTO MUX, '0' for manual MUX
      sAxisAddr : in slv(bitSize(NUM_SLAVES_G-1)-1 downto 0) := (others => '0');  -- manual MUX address

      -- Master
      mAxisMaster : out AxiStreamMasterType;
      mAxisSlave  : in  AxiStreamSlaveType
      );
end AxiStreamMux;

architecture structure of AxiStreamMux is

   constant DEST_SIZE_C : integer := bitSize(NUM_SLAVES_G-1);
   constant ARB_BITS_C  : integer := 2**DEST_SIZE_C;

   type StateType is (S_IDLE_C, S_MOVE_C, S_LAST_C);

   type RegType is record
      state  : StateType;
      acks   : slv(ARB_BITS_C-1 downto 0);
      ackNum : slv(DEST_SIZE_C-1 downto 0);
      valid  : sl;
      slaves : AxiStreamSlaveArray(NUM_SLAVES_G-1 downto 0);
      master : AxiStreamMasterType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state  => S_IDLE_C,
      acks   => (others => '0'),
      ackNum => (others => '0'),
      valid  => '0',
      slaves => (others => AXI_STREAM_SLAVE_INIT_C),
      master => AXI_STREAM_MASTER_INIT_C
      );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal pipeAxisMaster : AxiStreamMasterType;
   signal pipeAxisSlave  : AxiStreamSlaveType;
   
begin
   
   assert (TDEST_HIGH_G - TDEST_LOW_G + 1 >= log2(NUM_SLAVES_G))
      report "TDest range " & integer'image(TDEST_HIGH_G) & " downto " & integer'image(TDEST_LOW_G) &
      " is too small for NUM_MASTERS_G=" & integer'image(NUM_SLAVES_G) severity error;
   
   comb : process (axisRst, pipeAxisSlave, r, sAxisAddr, sAxisAuto, sAxisMasters) is
      variable v        : RegType;
      variable requests : slv(ARB_BITS_C-1 downto 0);
      variable selData  : AxiStreamMasterType;
   begin
      v := r;

      -- Init Ready
      for i in 0 to (NUM_SLAVES_G-1) loop
         v.slaves(i).tReady := '0';
      end loop;

      -- Select source
      selData                             := sAxisMasters(conv_integer(r.ackNum));
      selData.tDest(7 downto TDEST_LOW_G) := (others => '0');

      selData.tDest(DEST_SIZE_C+TDEST_LOW_G-1 downto TDEST_LOW_G) := r.ackNum;

      -- Format requests
      requests := (others => '0');
      for i in 0 to (NUM_SLAVES_G-1) loop
         -- Check for automatic MUX'ing
         if sAxisAuto = '1' then
            requests(i) := sAxisMasters(i).tValid;
         else
            -- While in manual MUX'ing mode,
            -- only pass requests from respective address pointer
            if i = conv_integer(sAxisAddr) then
               requests(i) := sAxisMasters(i).tValid;
            else
               requests(i) := '0';
            end if;
         end if;
      end loop;

      -- State machine
      case r.state is

         -- IDLE
         when S_IDLE_C =>
            v.master.tValid := '0';

            -- Aribrate between requesters
            if r.valid = '0' then
               arbitrate(requests, r.ackNum, v.ackNum, v.valid, v.acks);
            end if;

            -- Valid request
            if r.valid = '1' then
               v.state := S_MOVE_C;
            end if;

         -- Move a frame until tLast
         when S_MOVE_C =>
            v.valid := '0';

            -- Pass ready
            v.slaves(conv_integer(r.ackNum)).tReady := pipeAxisSlave.tReady;

            -- Advance pipeline 
            if r.master.tValid = '0' or pipeAxisSlave.tReady = '1' then
               v.master := selData;

               -- tLast to be presented
               if selData.tLast = '1' and selData.tValid = '1' then
                  v.state := S_LAST_C;
               end if;
            end if;

         -- Laster transfer
         when S_LAST_C =>
            if pipeAxisSlave.tReady = '1' then
               v.master.tValid := '0';
               v.state         := S_IDLE_C;
            end if;

      end case;

      if (axisRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      sAxisSlaves    <= v.slaves;
      pipeAxisMaster <= r.master;

   end process comb;

   AxiStreamPipeline_1 : entity work.AxiStreamPipeline
      generic map (
         TPD_G         => TPD_G,
         PIPE_STAGES_G => PIPE_STAGES_G)
      port map (
         axisClk     => axisClk,
         axisRst     => axisRst,
         sAxisMaster => pipeAxisMaster,
         sAxisSlave  => pipeAxisSlave,
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);

   seq : process (axisClk) is
   begin
      if (rising_edge(axisClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end structure;
