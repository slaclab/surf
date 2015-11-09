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
      TPD_G          : time := 1 ns;
      AXIS_CONFIG_G  : AxiStreamConfigType := AXI_STREAM_CONFIG_INIT_C;
      ADD_VALID_EN_G : boolean := false
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
                         shiftFirst : in    boolean;
                         mInput     : in    AxiStreamMasterType;
                         mDelay     : in    AxiStreamMasterType;
                         mOut       : inout AxiStreamMasterType ) is
      variable shiftInt  : positive;
      variable lDiv      : positive;
      variable rDiv      : positive;
      variable nextEmpty : boolean;
      constant user      : integer := AXIS_CONFIG_G.TUSER_BITS_C;
   begin

      mOut := AXI_STREAM_MASTER_INIT_C;

      if shiftBytes = 0 then
         mOut := mInput;
      else

         shiftInt := conv_integer(shiftBytes);

         if shiftDir = '0' then
            lDiv := shiftInt;
            rDiv := AXIS_CONFIG_G.TDATA_BYTES_C - shiftInt;
         else
            lDiv := AXIS_CONFIG_G.TDATA_BYTES_C - shiftInt;
            rDiv := shiftInt;
         end if;

         nextEmpty := true;

         for i in 0 to AXIS_CONFIG_G.TDATA_BYTES_C-1 loop
            if i < lDiv then
               mOut.tData((i*8)+7 downto (i*8))              := mDelay.tData(((i+rDiv)*8)+7 downto (i+rDiv)*8);
               mOut.tUser((i*user)+(user-1) downto (i*user)) := mDelay.tUser(((i+rDiv)*user)+(user-1) downto (i+rDiv)*user);

               if shiftFirst then
                  mOut.tStrb(i) := ite(ADD_VALID_EN_G = true,'1','0');
                  mOut.tKeep(i) := ite(ADD_VALID_EN_G = true,'1','0');
               else
                  mOut.tStrb(i) := mDelay.tStrb(i+rDiv);
                  mOut.tKeep(i) := mDelay.tKeep(i+rDiv);
               end if;

               -- There are valid values which will be taken from the delayed register.
               if mInput.tValid = '1' and mInput.tKeep(i+rDiv) = '1' then
                  nextEmpty := false;
               end if;
            else
               mOut.tData((i*8)+7 downto (i*8))              := mInput.tData(((i-lDiv)*8)+7 downto (i-lDiv)*8);
               mOut.tUser((i*user)+(user-1) downto (i*user)) := mInput.tUser(((i-lDiv)*user)+(user-1) downto (i-lDiv)*user);
               mOut.tStrb(i) := mInput.tStrb(i-lDiv) and (not mDelay.tLast);
               mOut.tKeep(i) := mInput.tKeep(i-lDiv) and (not mDelay.tLast);
            end if;
         end loop;

         -- Choose ID and Dest values
         if shiftFirst then
            mOut.tId   := mInput.tId;
            mOut.tDest := mInput.tDest;
         else
            mOut.tId   := mDelay.tId;
            mOut.tDest := mDelay.tDest;
         end if;

         -- Detect frame end from next register or current register
         if (mDelay.tValid = '1' and mDelay.tLast = '1') or (mInput.tValid = '1' and mInput.tLast = '1' and nextEmpty) then
            mOut.tLast  := '1';
            mOut.tValid := '1';
         else
            mOut.tLast  := '0';
            mOut.tValid := mInput.tValid;
         end if;
      end if;
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
      shiftData ( r.shiftBytes, r.shiftDir, (r.state = S_FIRST_C), sAxisMaster, r.delay, sMaster);

      -- State machine
      case r.state is

         -- IDLE
         when S_IDLE_C =>
            v.slave      := AXI_STREAM_SLAVE_INIT_C;
            v.master     := AXI_STREAM_MASTER_INIT_C;
            v.delay      := AXI_STREAM_MASTER_INIT_C;
            v.shiftDir   := axiShiftDir;
            v.shiftBytes := axiShiftCnt;

            -- Shift start request
            if axiStart = '1' then
               v.state := S_FIRST_C;
            end if;

         -- First shift
         when S_FIRST_C =>
            v.slave.tReady := '1';

            -- Keep sampling shift configuration if start is held
            if axiStart = '1' then
               v.shiftDir     := axiShiftDir;
               v.shiftBytes   := axiShiftCnt;
            end if;

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
