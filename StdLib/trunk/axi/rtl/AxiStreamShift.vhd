-------------------------------------------------------------------------------
-- Title      : AXI Stream Data Shifter
-- Project    : General Purpose Core
-------------------------------------------------------------------------------
-- File       : AxiStreamShift.vhd
-- Author     : Ryan Herbst, rherbst@slac.stanford.edu
-- Created    : 2014-04-25
-- Last update: 2014-05-05
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-- Block to shift data bytes within an AXI stream. Both left and right shifting
-- are allowed. This block will move a packet at a time. Transfer of a new packet
-- will pause until a new shift command is provided.
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

entity AxiStreamShift is
   generic (
      TPD_G         : time := 1 ns;
      AXIS_CONFIG_G : AxiStreamConfigType := AXI_STREAM_CONFIG_INIT_C
   );
   port (

      -- Clock and reset
      axisClk : in sl;
      axisRst : in sl;

      -- Start control
      axiStart    : in  sl;
      axiShiftDir : in  sl; -- 0 = left (lsb to msb)
      axiShiftCnt : in  slv(3 downto 0);

      -- Slaves
      sAxisMaster : in  AxiStreamMasterType;
      sAxisSlave  : out AxiStreamSlaveType;

      -- Master
      mAxisMaster : out AxiStreamMasterType;
      mAxisSlave  : in  AxiStreamSlaveType
   );
end AxiStreamShift;

architecture structure of AxiStreamShift is

   type StateType is (S_IDLE_C, S_FIRST_C, S_SHIFT_C, S_LAST_C);

   type RegType is record
      state      : StateType;
      shiftDir   : sl;
      shiftBytes : slv(3 downto 0);
      slave      : AxiStreamSlaveType;
      master     : AxiStreamMasterType;
      delay      : AxiStreamMasterType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state      => S_IDLE_C,
      shiftDir   => '0',
      shiftBytes => (others=>'0'),
      slave      => AXI_STREAM_SLAVE_INIT_C,
      master     => AXI_STREAM_MASTER_INIT_C,
      delay      => AXI_STREAM_MASTER_INIT_C
      );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (axisRst, mAxisSlave, r, sAxisMaster, axiStart, axiShiftDir, axiShiftCnt ) is
      variable v       : RegType;
      variable shift   : integer;
      variable data    : integer;
      variable user    : integer;
      variable sMaster : AxiStreamMasterType;
   begin
      v := r;

      shift := conv_integer(r.shiftBytes);
      data  := AXIS_CONFIG_G.TDATA_BYTES_C;
      user  := AXIS_CONFIG_G.TUSER_BITS_C;

      -- Init Ready
      v.slave.tReady := '0';

      -- No Shift
      if r.shiftBytes = 0 then
         sMaster := sAxisMaster;

      -- Left shift
      elsif r.shiftDir = '0' then

         -- Data / Control / User
         sMaster.tData((data*8)-1 downto (shift*8)) := sAxisMaster.tData(((data-shift)*8)-1 downto 0);
         sMaster.tData((shift*8)-1 downto 0)        := r.delay.tData((data*8)-1 downto (data-shift)*8);

         sMaster.tStrb(data-1 downto shift) := sAxisMaster.tStrb(data-shift-1 downto 0);
         sMaster.tStrb(shift-1 downto 0)    := r.delay.tStrb(data-1 downto data-shift);

         sMaster.tKeep(data-1 downto shift) := sAxisMaster.tKeep(data-shift-1 downto 0);
         sMaster.tKeep(shift-1 downto 0)    := r.delay.tKeep(data-1 downto data-shift);

         sMaster.tUser((data*user)-1 downto (shift*user)) := sAxisMaster.tUser(((data-shift)*user)-1 downto 0);
         sMaster.tUser((shift*user)-1 downto 0)           := r.delay.tUser((data*user)-1 downto (data-shift)*user);

         -- First shift is special
         if r.state = S_FIRST_C then
            sMaster.tId                     := sAxisMaster.tId;
            sMaster.tDest                   := sAxisMaster.tDest;
            sMaster.tStrb(shift-1 downto 0) := (others=>'0');
            sMaster.tKeep(shift-1 downto 0) := (others=>'0');
         else
            sMaster.tId    := r.delay.tId;
            sMaster.tDest  := r.delay.tDest;
         end if;

         -- Ending on bytes from input stream, input stream must be valid
         if sAxisMaster.tValid = '1' and sAxisMaster.tLast = '1' and sAxisMaster.tKeep(data-1 downto data-shift) = 0 then
            sMaster.tLast  := '1';
            sMaster.tValid := '1';

         -- Ending on bytes from delayed stream, delayed stream must be valid
         elsif r.delay.tValid = '1' and r.delay.tLast = '1' and r.delay.tKeep(data-1 downto data-shift) /= 0 then
            sMaster.tStrb(data-1 downto shift) := (others=>'0');
            sMaster.tKeep(data-1 downto shift) := (others=>'0');
            sMaster.tLast  := '1';
            sMaster.tValid := '1';
         else
            sMaster.tLast  := '0';
            sMaster.tValid := sAxisMaster.tValid;
         end if;

      -- Right shift
      else

         -- ID/Dest
         sMaster.tId   := r.delay.tId;
         sMaster.tDest := r.delay.tDest;

         -- Data / Control / User
         sMaster.tData((data*8)-1 downto (data-shift)*8) := sAxisMaster.tData((shift*8)-1 downto 0);
         sMaster.tData(((data-shift)*8)-1 downto 0)      := r.delay.tData((data*8)-1 downto (shift*8));

         sMaster.tStrb(data-1 downto data-shift):= sAxisMaster.tStrb(shift-1 downto 0);
         sMaster.tStrb(data-shift-1 downto 0)   := r.delay.tStrb(data-1 downto shift);

         sMaster.tKeep(data-1 downto data-shift):= sAxisMaster.tKeep(shift-1 downto 0);
         sMaster.tKeep(data-shift-1 downto 0)   := r.delay.tKeep(data-1 downto shift);

         sMaster.tUser((data*user)-1 downto (data-shift)*user) := sAxisMaster.tUser((shift*user)-1 downto 0);
         sMaster.tUser(((data-shift)*user)-1 downto 0)         := r.delay.tUser((data*user)-1 downto (shift*user));

         -- Ending on bytes from input stream, input stream must be valid
         if sAxisMaster.tValid = '1' and sAxisMaster.tLast = '1' and sAxisMaster.tKeep(data-1 downto shift) = 0 then
            sMaster.tLast  := '1';
            sMaster.tValid := '1';

         -- Ending on bytes from delayed stream, delayed stream must be valid
         elsif r.delay.tValid = '1' and r.delay.tLast = '1' and r.delay.tKeep(data-1 downto shift) /= 0 then
            sMaster.tStrb(data-1 downto data-shift) := (others=>'0');
            sMaster.tKeep(data-1 downto data-shift) := (others=>'0');
            sMaster.tLast  := '1';
            sMaster.tValid := '1';
         else
            sMaster.tLast  := '0';
            sMaster.tValid := sAxisMaster.tValid;
         end if;

      end if;

      -- State machine
      case r.state is

         -- IDLE
         when S_IDLE_C =>
            v.slave  := AXI_STREAM_SLAVE_INIT_C;
            v.master := AXI_STREAM_MASTER_INIT_C;
            v.delay  := AXI_STREAM_MASTER_INIT_C;

            -- Shift start request
            if axiStart = '1' then
               v.shiftDir   := axiShiftDir;
               v.shiftBytes := axiShiftCnt;
               v.state      := S_FIRST_C;
            end if;

         -- First shift
         when S_FIRST_C =>
            v.slave.tReady := '1';

            if sAxisMaster.tValid = '1' then
               v.delay := sAxisMaster;
               v.state := S_SHIFT_C;

               -- Left or no shift
               if r.shiftDir = '0' or r.shiftBytes = 0 then
                  v.master := sMaster;

                  -- Frame is done
                  if sMaster.tLast = '1' then
                     v.state := S_LAST_C;
                  end if;
               end if;
            end if;

         -- Move a frame until tLast
         when S_SHIFT_C =>

            -- Advance pipeline
            if r.master.tValid = '0' or mAxisSlave.tReady = '1' then
               v.slave.tReady := '1';

               if sAxisMaster.tValid = '1' then
                  v.delay  := sAxisMaster;
                  v.master := sMaster;
               else
                  v.master.tValid := '0';
               end if;

               -- Frame is done
               if sMaster.tLast = '1' then
                  v.master := sMaster;

                  -- Last is is delayed block
                  if r.delay.tLast = '1' then
                     v.slave.tReady := '0';
                  end if;

                  v.state := S_LAST_C;
               end if;
            end if;

         -- Last transfer
         when S_LAST_C =>
            if mAxisSlave.tReady = '1' then
               v.state         := S_IDLE_C;
               v.master.tValid := '0';
            end if;
      end case;

      if (axisRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      sAxisSlave  <= v.slave;
      mAxisMaster <= r.master;

   end process comb;

   seq : process (axisClk) is
   begin
      if (rising_edge(axisClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end structure;
