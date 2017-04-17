-------------------------------------------------------------------------------
-- File       : SlvArraytoAxiLite.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-07-21
-- Last update: 2016-07-21
-------------------------------------------------------------------------------
-- Description: SLV array to AXI-Lite Master Bridge 
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

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiLiteMasterPkg.all;

entity SlvArraytoAxiLite is
   generic (
      TPD_G        : time       := 1 ns;
      COMMON_CLK_G : boolean    := false;  -- Set true if axilClk = clk
      SIZE_G       : positive   := 1;
      ADDR_G       : Slv32Array := (0 => x"00000000"));
   port (
      -- SLV Array Interface
      clk             : in  sl;
      rst             : in  sl;
      input           : in  Slv32Array(SIZE_G-1 downto 0);
      -- AXI-Lite Master Interface
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : out AxiLiteReadMasterType;
      axilReadSlave   : in  AxiLiteReadSlaveType;
      axilWriteMaster : out AxiLiteWriteMasterType;
      axilWriteSlave  : in  AxiLiteWriteSlaveType);    
end entity SlvArraytoAxiLite;

architecture rtl of SlvArraytoAxiLite is

   type StateType is (
      IDLE_S,
      WAIT_S); 

   type RegType is record
      cnt   : natural range 0 to SIZE_G-1;
      valid : slv(SIZE_G-1 downto 0);
      inSlv : Slv32Array(SIZE_G-1 downto 0);
      req   : AxiLiteMasterReqType;
      state : StateType;
   end record;

   constant REG_INIT_C : RegType := (
      cnt   => 0,
      valid => (others => '0'),
      inSlv => (others => (others => '0')),
      req   => AXI_LITE_MASTER_REQ_INIT_C,
      state => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal inSlv : Slv32Array(SIZE_G-1 downto 0);
   signal ack   : AxiLiteMasterAckType;

   -- attribute dont_touch      : string;
   -- attribute dont_touch of r : signal is "true";

begin

   GEN_VEC :
   for i in (SIZE_G-1) downto 0 generate
      SyncFifo : entity work.SynchronizerFifo
         generic map (
            TPD_G        => TPD_G,
            COMMON_CLK_G => COMMON_CLK_G,
            DATA_WIDTH_G => 32)
         port map (
            -- Write Ports (wr_clk domain)
            wr_clk => clk,
            din    => input(i),
            -- Read Ports (rd_clk domain)
            rd_clk => axilClk,
            dout   => inSlv(i));
   end generate GEN_VEC;

   AxiLiteMaster : entity work.AxiLiteMaster
      generic map (
         TPD_G => TPD_G)
      port map (
         req             => r.req,
         ack             => ack,
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave);  

   comb : process (ack, axilRst, inSlv, r) is
      variable v : RegType;
      variable i : natural;
   begin
      -- Latch the current value
      v := r;

      -- Loop through the SLV array
      for i in (SIZE_G-1) downto 0 loop
         -- Check for changes in the bus
         if inSlv(i) /= r.inSlv(i) then
            -- Set the flag
            v.valid(i) := '1';
         end if;
      end loop;

      -- Update the registered value
      v.inSlv := inSlv;

      -- State Machine
      case (r.state) is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Increment the counter
            if r.cnt = (SIZE_G-1) then
               v.cnt := 0;
            else
               v.cnt := r.cnt + 1;
            end if;
            -- Check the valid flag and transaction completed
            if (r.valid(r.cnt) = '1') and (ack.done = '0') then
               -- Reset the flag
               v.valid(r.cnt) := '0';
               -- Setup the AXI-Lite Master request
               v.req.request  := '1';
               v.req.rnw      := '0';   -- Write operation
               v.req.address  := ADDR_G(r.cnt);
               v.req.wrData   := r.inSlv(r.cnt);
               -- Next state
               v.state        := WAIT_S;
            end if;
         ----------------------------------------------------------------------
         when WAIT_S =>
            -- Wait for DONE to set
            if ack.done = '1' then
               -- Reset the flag
               v.req.request := '0';
               -- Next state
               v.state       := IDLE_S;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Synchronous Reset
      if (axilRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;
      
   end process comb;

   seq : process (axilClk) is
   begin
      if (rising_edge(axilClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
