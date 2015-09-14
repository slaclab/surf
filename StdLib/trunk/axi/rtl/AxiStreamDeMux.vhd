-------------------------------------------------------------------------------
-- Title      : AXI Stream De-Multiplexer
-- Project    : General Purpose Core
-------------------------------------------------------------------------------
-- File       : AxiStreamDeMux.vhd
-- Author     : Ryan Herbst, rherbst@slac.stanford.edu
-- Created    : 2014-04-25
-- Last update: 2015-08-20
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-- Block to connect a single incoming AXI stream to multiple outgoing AXI
-- streams based upon the incoming tDest value.
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
use ieee.NUMERIC_STD.all;
use work.StdRtlPkg.all;
use work.ArbiterPkg.all;
use work.AxiStreamPkg.all;

entity AxiStreamDeMux is
   generic (
      TPD_G         : time                  := 1 ns;
      NUM_MASTERS_G : integer range 1 to 32 := 12;
      MODE_G : string := "INDEXED";     -- Or "ROUTED"
      TDEST_HIGH_G  : integer range 0 to 7  := 7;
      TDEST_LOW_G   : integer range 0 to 7  := 0;
      TDEST_ROUTES_G : slv8Array := (0 => "--------")  -- Only used in ROUTED mode
      );
   port (

      -- Clock and reset
      axisClk : in sl;
      axisRst : in sl;

      -- Slave
      sAxisMaster : in  AxiStreamMasterType;
      sAxisSlave  : out AxiStreamSlaveType;

      -- Masters
      mAxisMasters : out AxiStreamMasterArray(NUM_MASTERS_G-1 downto 0);
      mAxisSlaves  : in  AxiStreamSlaveArray(NUM_MASTERS_G-1 downto 0)
      );
end AxiStreamDeMux;

architecture structure of AxiStreamDeMux is

   type RegType is record
      slave   : AxiStreamSlaveType;
      masters : AxiStreamMasterArray(NUM_MASTERS_G-1 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      slave   => AXI_STREAM_SLAVE_INIT_C,
      masters => (others => AXI_STREAM_MASTER_INIT_C)
      );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   assert (MODE_G /= "INDEXED" or (TDEST_HIGH_G - TDEST_LOW_G + 1 >= log2(NUM_MASTERS_G)))
      report "In INDEXED mode, TDest range " & integer'image(TDEST_HIGH_G) & " downto " & integer'image(TDEST_LOW_G) &
      " is too small for NUM_MASTERS_G=" & integer'image(NUM_MASTERS_G)
      severity error;

   assert (MODE_G /= "ROUTED" or (TDEST_ROUTES_G'length = NUM_MASTERS_G))
      report "In ROUTED mode, length of TDEST_ROUTES_G: " & integer'image(TDEST_ROUTES_G'length) &
      " must equal NUM_MASTERS_G: " & integer'image(NUM_MASTERS_G)
      severity error;

   comb : process (axisRst, r, sAxisMaster, mAxisSlaves) is
      variable v   : RegType;
      variable idx : integer;
   begin
      v := r;

      -- Update output registers 
      for i in 0 to NUM_MASTERS_G-1 loop
         if mAxisSlaves(i).tReady = '1' then
            v.masters(i).tValid := '0';
         end if;
      end loop;

      -- Decode destination
      if (MODE_G = "INDEXED") then
         -- TDEST indicates the output port
         idx := conv_integer(sAxisMaster.tDest(TDEST_HIGH_G downto TDEST_LOW_G));
      elsif (MODE_G = "ROUTED") then
         -- Output port determined by TDEST_ROUTES_G
         -- Set to invalid idx first, if non match then frame will be dumped
         idx := NUM_MASTERS_G;
         -- Search for a matching MASK in ascending order of mask array
         for i in 0 to NUM_MASTERS_G-1 loop
            if (std_match(sAxisMaster.tDest, TDEST_ROUTES_G(i))) then
               idx := i;
            end if;
         end loop;
      end if;

      -- Invalid destination, dump data
      if idx >= NUM_MASTERS_G then
         v.slave.tReady := '1';

      -- Target is ready
      elsif v.masters(idx).tValid = '0' then
         v.slave.tReady := '1';
         v.masters(idx) := sAxisMaster;

      -- Not ready
      else
         v.slave.tReady := '0';
      end if;

      if (axisRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      sAxisSlave   <= v.slave;
      mAxisMasters <= r.masters;

   end process comb;

   seq : process (axisClk) is
   begin
      if (rising_edge(axisClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end structure;

