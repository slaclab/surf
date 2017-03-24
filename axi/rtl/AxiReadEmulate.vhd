-------------------------------------------------------------------------------
-- File       : AxiReadEmulate.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-04-02
-- Last update: 2016-04-26
-------------------------------------------------------------------------------
-- Description: AXI4 Read Emulation Module
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.TextUtilPkg.all;
use work.StdRtlPkg.all;
use work.AxiPkg.all;

entity AxiReadEmulate is
   generic (
      TPD_G        : time          := 1 ns;
      LATENCY_G    : natural       := 31;
      AXI_CONFIG_G : AxiConfigType := AXI_CONFIG_INIT_C;
      SIM_DEBUG_G  : boolean       := false);
   port (
      -- Clock/Reset
      axiClk        : in  sl;
      axiRst        : in  sl;
      -- AXI Interface
      axiReadMaster : in  AxiReadMasterType;
      axiReadSlave  : out AxiReadSlaveType);
end AxiReadEmulate;

architecture structure of AxiReadEmulate is

   type StateType is (
      IDLE_S,
      DATA_S);

   type RegType is record
      latency : natural range 0 to LATENCY_G;
      state   : StateType;
      cnt     : slv(31 downto 0);
      iMaster : AxiReadMasterType;
      iSlave  : AxiReadSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      latency => 0,
      state   => IDLE_S,
      cnt     => (others => '0'),
      iMaster => AXI_READ_MASTER_INIT_C,
      iSlave  => AXI_READ_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal intReadMaster : AxiReadMasterType;
   signal intReadSlave  : AxiReadSlaveType;

begin

   U_AxiReadPathFifo : entity work.AxiReadPathFifo
      generic map (
         TPD_G        => TPD_G,
         AXI_CONFIG_G => AXI_CONFIG_G) 
      port map (
         sAxiClk        => axiClk,
         sAxiRst        => axiRst,
         sAxiReadMaster => axiReadMaster,
         sAxiReadSlave  => axiReadSlave,
         mAxiClk        => axiClk,
         mAxiRst        => axiRst,
         mAxiReadMaster => intReadMaster,
         mAxiReadSlave  => intReadSlave);

   comb : process (axiRst, intReadMaster, r) is
      variable v    : RegType;
   begin
      -- Latch the current value  
      v := r;

      -- Reset the variables
      v.iSlave := AXI_READ_SLAVE_INIT_C;

      -- State machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Reset the counter
            v.cnt := (others => '0');
            -- Check the latency
            if r.latency = LATENCY_G then
               -- Reset the counter
               v.latency := 0;
               -- Check for a memory request
               if intReadMaster.arvalid = '1' then
                  -- Latch the value
                  v.iMaster        := intReadMaster;
                  -- Accept the data
                  v.iSlave.arready := '1';
                  -- Next state
                  v.state          := DATA_s;
               end if;
            else
               -- Increment the counter
               v.latency := r.latency + 1;
            end if;
         ----------------------------------------------------------------------
         when DATA_s =>
            -- Check if ready to move data
            if intReadMaster.rready = '1' then
               -- Move the data
               v.iSlave.rvalid := '1';
               -- Send counter data
               for i in 0 to (2**conv_integer(r.iMaster.arsize))-1 loop
                  v.iSlave.rdata(i*8+7 downto i*8) := v.cnt(7 downto 0);
                  v.cnt                            := v.cnt + 1;
               end loop;
               print(SIM_DEBUG_G, "AxiReadEmulate( addr:" & hstr(r.iMaster.araddr+r.cnt) & ", data: " & hstr(v.iSlave.rdata(AXI_CONFIG_G.DATA_BYTES_C-1 downto 0)) & ")");

               -- Echo the read ID
               v.iSlave.rid := r.iMaster.arid;
               -- Check if transaction is completed
               if r.iMaster.arlen = 0 then
                  -- Set the flag
                  v.iSlave.rlast := '1';
                  -- Check if request in pipeline
                  if intReadMaster.arvalid = '1' then
                     -- Preset the counter
                     v.latency := LATENCY_G;
                  end if;
                  -- Next state
                  v.state        := IDLE_S;
               else
                  v.iMaster.arlen := r.iMaster.arlen - 1;
               end if;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Reset
      if (axiRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle    
      rin <= v;

      -- Outputs 
      intReadSlave <= v.iSlave;

   end process comb;

   seq : process (axiClk) is
   begin
      if (rising_edge(axiClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end structure;

