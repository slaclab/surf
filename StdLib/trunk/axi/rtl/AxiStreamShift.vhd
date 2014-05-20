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

   -- Set shift ranges
   procedure shiftData ( shiftBytes : in    slv(3 downto 0); 
                         shiftDir   : in    sl;
                         mInput     : in    AxiStreamMasterType;
                         mDelay     : in    AxiStreamMasterType;
                         mOut       : inout AxiStreamMasterType ) is
      variable shiftInt : positive;
      variable top      : positive;
      variable lDiv     : positive;
      variable rDiv     : positive;
      constant user     : integer := AXIS_CONFIG_G.TUSER_BITS_C;
   begin

--      if shiftBytes = 0 then
         mOut := mInput;
--      else
--
--         shiftInt := conv_integer(shiftBytes);
--         top      := AXIS_CONFIG_G.TDATA_BYTES_C - 1;
--
--         if shiftDir = '0' then
--            leftDiv  := shiftInt;
--            rightDiv := AXIS_CONFIG_G.TDATA_BYTES_C - shiftInt;
--         else
--            leftDiv  := AXIS_CONFIG_G.TDATA_BYTES_C - shiftInt;
--            rightDiv := shiftInt;
--         end if;
--
--         mOut.tData((top*8)-1 downto (lDiv*8)) := mInput.tData((rDiv*8)-1 downto 0);
--         mOut.tData((lDiv*8)-1 downto 0)       := mDelay.tData((top*8)-1 downto rDiv*8);
--
--         mOut.tStrb(top-1 downto lDiv) := mInput.tStrb(rDiv-1 downto 0);
--         mOut.tStrb(lDiv-1 downto 0)   := mDelay.tStrb(top-1 downto rDiv);
--
--         mOut.tKeep(top-1 downto lDiv) := mInput.tKeep(rDiv-1 downto 0);
--         mOut.tKeep(lDiv-1 downto 0)   := mDelay.tKeep(top-1 downto rDiv);
--
--         mOut.tUser((top*user)-1 downto (lDiv*user)) := mInput.tUser((rDiv*user)-1 downto 0);
--         mOut.tUser((lDiv*user)-1 downto 0)          := mDelay.tUser((top*user)-1 downto rDiv*user);
--
--         -- First shift is special
--         if r.state = S_FIRST_C then
--            mOut.tId                    := mInput.tId;
--            mOut.tDest                  := mInput.tDest;
--            mOut.tStrb(lDiv-1 downto 0) := (others=>'0');
--            mOut.tKeep(lDiv-1 downto 0) := (others=>'0');
--         else
--            mOut.tId   := mDelay.tId;
--            mOut.tDest := mDelay.tDest;
--         end if;
--
--         -- Ending on bytes from input stream, input stream must be valid
--         if mInput.tValid = '1' and mInput.tLast = '1' and mInput.tKeep(top-1 downto rDiv) = 0 then
--            mOut.tLast  := '1';
--            mOut.tValid := '1';
--
--         -- Ending on bytes from delayed stream, delayed stream must be valid
--         elsif mDelay.tValid = '1' and mDelay.tLast = '1' and mDelay.tKeep(top-1 downto rDiv) /= 0 then
--            mOut.tStrb(top-1 downto lDiv) := (others=>'0');
--            mOut.tKeep(top-1 downto lDiv) := (others=>'0');
--            mOut.tLast  := '1';
--            mOut.tValid := '1';
--         else
--            mOut.tLast  := '0';
--            mOut.tValid := mInput.tValid;
--         end if;
--      end if;
   end procedure;

begin

   comb : process (axisRst, mAxisSlave, r, sAxisMaster, axiStart, axiShiftDir, axiShiftCnt ) is
      variable v       : RegType;
      variable sMaster : AxiStreamMasterType;
   begin
      v := r;

      -- Init Ready
      v.slave.tReady := '0';

      -- Data shift
      shiftData ( r.shiftBytes, r.shiftDir, sAxisMaster, r.delay, sMaster);

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
