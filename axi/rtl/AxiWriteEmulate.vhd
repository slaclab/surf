-------------------------------------------------------------------------------
-- File       : AxiWriteEmulate.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-04-02
-- Last update: 2016-04-26
-------------------------------------------------------------------------------
-- Description: AXI4 Write Emulation Module
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

entity AxiWriteEmulate is
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
      axiWriteMaster : in  AxiWriteMasterType;
      axiWriteSlave  : out AxiWriteSlaveType);
end AxiWriteEmulate;

architecture structure of AxiWriteEmulate is

   type StateType is (
      IDLE_S,
      DATA_S,
      WAIT_S,
      RESP_S);

   type RegType is record
      latency : natural range 0 to LATENCY_G;
      cnt     : slv(15 downto 0);
      state   : StateType;
      iMaster : AxiWriteMasterType;
      iSlave  : AxiWriteSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      latency => 0,
      cnt     => (others=>'0'),
      state   => IDLE_S,
      iMaster => AXI_WRITE_MASTER_INIT_C,
      iSlave  => AXI_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal intWriteMaster : AxiWriteMasterType;
   signal intWriteSlave  : AxiWriteSlaveType;

begin

   U_AxiWritePathFifo : entity work.AxiWritePathFifo
      generic map (
         TPD_G        => TPD_G,
         AXI_CONFIG_G => AXI_CONFIG_G) 
      port map (
         sAxiClk         => axiClk,
         sAxiRst         => axiRst,
         sAxiWriteMaster => axiWriteMaster,
         sAxiWriteSlave  => axiWriteSlave,
         mAxiClk         => axiClk,
         mAxiRst         => axiRst,
         mAxiWriteMaster => intWriteMaster,
         mAxiWriteSlave  => intWriteSlave);

   comb : process (axiRst, intWriteMaster, r) is
      variable v : RegType;
   begin
      -- Latch the current value  
      v := r;

      -- Reset the variables
      v.iSlave := AXI_WRITE_SLAVE_INIT_C;

      -- State machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            v.cnt     := (others=>'0');
            v.latency := 0;
            -- Check for a memory request
            if intWriteMaster.awvalid = '1' then
               -- Latch the value
               v.iMaster        := intWriteMaster;
               -- Accept the data
               v.iSlave.awready := '1';
               -- Next state
               v.state          := DATA_s;
            end if;
         ----------------------------------------------------------------------
         when DATA_s =>
            -- Check for data
            if intWriteMaster.wvalid = '1' then
               -- Write data channel
               v.iSlave.wready := '1';
               -- Increment counter
               v.cnt := r.cnt + AXI_CONFIG_G.DATA_BYTES_C;
               -- Show data
               print(SIM_DEBUG_G, "AxiWriteEmulate( addr:" & hstr(r.iMaster.awaddr+r.cnt) & ", data: " & hstr(intWriteMaster.wdata(AXI_CONFIG_G.DATA_BYTES_C-1 downto 0)) & ")");
               -- Detect last
               if intWriteMaster.wLast = '1' then
                  v.state := WAIT_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when WAIT_S =>
            -- Check the latency
            if r.latency = LATENCY_G then
               v.state := RESP_S;
            else
               -- Increment the counter
               v.latency := r.latency + 1;
            end if;
         ----------------------------------------------------------------------
         when RESP_s =>
            v.iSlave.bresp := (others=>'0');
            v.iSlave.bvalid  := '1';
            v.iSlave.bid     := r.iMaster.awid;
            if intWriteMaster.bready = '1' then
               v.state := IDLE_S;
            end if;
      end case;

      -- Reset
      if (axiRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle    
      rin <= v;

      -- Outputs 
      intWriteSlave <= v.iSlave;

   end process comb;

   seq : process (axiClk) is
   begin
      if (rising_edge(axiClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end structure;

