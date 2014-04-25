-------------------------------------------------------------------------------
-- Title      : AXI Stream Multiplexer
-- Project    : General Purpose Core
-------------------------------------------------------------------------------
-- File       : AxiStreamMux.vhd
-- Author     : Ryan Herbst, rherbst@slac.stanford.edu
-- Created    : 2014-04-25
-- Last update: 2014-04-25
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-- Block to connect multiple incoming AXI streams into a single encoded
-- outbound stream. The destination field is upated accordingly.
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
      NUM_SLAVES_G  : integer range 1 to 32 := 4
   ); port (

      -- VC clock and reset
      axiClk        : in sl;
      axiRst        : in sl;

      -- Slaves
      slvAxiStreamMasters : in  AxiStreamMasterArray(NUM_SLAVES_G-1 downto 0);
      slvAxiStreamSlaves  : out AxiStreamSlaveArray(NUM_SLAVES_G-1 downto 0);

      -- Master
      mstAxiStreamMaster  : out AxiStreamMasterType;
      mstAxiStreamSlave   : in  AxiStreamSlaveType
   );
end AxiStreamMux;

architecture structure of AxiStreamMux is

   constant ACK_NUM_SIZE_C : integer := bitSize(NUM_SLAVES_G-1);

   type StateType is ( S_IDLE_C, S_MOVE_C, S_LAST_C );

   type RegType is record
      state  : StateType;
      acks   : slv(NUM_SLAVES_G-1 downto 0);
      ackNum : slv(ACK_NUM_SIZE_C-1 downto 0);
      valid  : sl;
      slaves : AxiStreamSlaveArray(NUM_SLAVES_G-1 downto 0);
      master : AxiStreamMasterType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state  => S_IDLE_C,
      acks   => (others=>'0'),
      ackNum => (others=>'0'),
      valid  => '0',
      slaves => (others=>AXI_STREAM_SLAVE_INIT_C),
      master => AXI_STREAM_MASTER_INIT_C
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (axiRst, r, slvAxiStreamMasters, mstAxiStreamSlave ) is
      variable v        : RegType;
      variable requests : slv(NUM_SLAVES_G-1 downto 0);
      variable selData  : AxiStreamMasterType;
   begin
      v := r;

      -- Init Ready
      for i in 0 to (NUM_SLAVES_G-1) loop
         v.slaves(i).tReady := '0';
      end loop;

      -- Select source
      selData       := slvAxiStreamMasters(conv_integer(r.ackNum));
      selData.tDest := conv_std_logic_vector(conv_integer(r.ackNum),128);

      -- Format requests
      for i in 0 to (NUM_SLAVES_G-1) loop
         requests(i) := slvAxiStreamMasters(i).tValid;
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
            v.slaves(conv_integer(r.ackNum)).tReady := mstAxiStreamSlave.tReady;

            -- Advance pipeline 
            if r.master.tValid = '0' or mstAxiStreamSlave.tReady = '1' then
               v.master := selData;

               -- tLast to be presented
               if selData.tLast = '1' and selData.tValid = '1' then
                  v.state := S_LAST_C;
               end if;
            end if;

         -- Laster transfer
         when S_LAST_C =>
            if mstAxiStreamSlave.tReady = '1' then
               v.master.tValid := '0';
               v.state         := S_IDLE_C;
            end if;

      end case;

      if (axiRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      slvAxiStreamSlaves <= v.slaves;
      mstAxiStreamMaster <= r.master;

   end process comb;

   seq : process (axiClk) is
   begin
      if (rising_edge(axiClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end structure;

