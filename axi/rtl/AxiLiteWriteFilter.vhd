-------------------------------------------------------------------------------
-- File       : AxiLiteWriteFilter.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-11-13
-- Last update: 2017-11-14
-------------------------------------------------------------------------------
-- Description: Module for filtering write access
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

entity AxiLiteWriteFilter is
   generic (
      TPD_G            : time            := 1 ns;
      FILTER_SIZE_G    : positive        := 1;  -- Number of filter addresses
      FILTER_ADDR_G    : Slv32Array      := (0 => x"00000000");  -- Filter addresses that will be allowed through
      AXI_ERROR_RESP_G : slv(1 downto 0) := AXI_RESP_DECERR_C);
   port (
      -- Clock and reset
      axilClk          : in  sl;
      axilRst          : in  sl;
      enFilter         : in  sl := '1';
      blockAll         : in  sl := '1';  -- overrides enFilter, '1' blocks all transactions
      -- AXI-Lite Slave Interface
      sAxilWriteMaster : in  AxiLiteWriteMasterType;
      sAxilWriteSlave  : out AxiLiteWriteSlaveType;
      -- AXI-Lite Master Interface
      mAxilWriteMaster : out AxiLiteWriteMasterType;
      mAxilWriteSlave  : in  AxiLiteWriteSlaveType);
end entity AxiLiteWriteFilter;

architecture rtl of AxiLiteWriteFilter is

   type StateType is (
      IDLE_S,
      LOOP_ARRAY_S,
      CHECK_FLAG_S,
      MOVE_S,
      BUS_RESP_S);

   type RegType is record
      validAddress     : sl;
      idx              : natural range 0 to FILTER_SIZE_G-1;
      sAxilWriteSlave  : AxiLiteWriteSlaveType;
      mAxilWriteMaster : AxiLiteWriteMasterType;
      state            : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      validAddress     => '1',
      idx              => 0,
      sAxilWriteSlave  => AXI_LITE_WRITE_SLAVE_INIT_C,
      mAxilWriteMaster => AXI_LITE_WRITE_MASTER_INIT_C,
      state            => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (axilRst, blockAll, enFilter, mAxilWriteSlave, r,
                   sAxilWriteMaster) is
      variable v : RegType;
   begin
      -- Latch the current value   
      v := r;

      -- Reset the strobe
      v.sAxilWriteSlave.awready := '0';
      v.sAxilWriteSlave.wready  := '0';

      -- Slave bready/bvalid handshaking
      if (sAxilWriteMaster.bready = '1') then
         v.sAxilWriteSlave.bvalid := '0';
      end if;

      -- Master awready/awvalid handshaking
      if mAxilWriteSlave.awready = '1' then
         v.mAxilWriteMaster.awvalid := '0';
      end if;

      -- Master wready/wvalid handshaking
      if mAxilWriteSlave.wready = '1' then
         v.mAxilWriteMaster.wvalid := '0';
      end if;

      -- State machine
      case (r.state) is
         ------------------------------------------------------------------------------------
         when IDLE_S =>
            -- Latch the address and data
            v.mAxilWriteMaster.awaddr := sAxilWriteMaster.awaddr;
            v.mAxilWriteMaster.awprot := sAxilWriteMaster.awprot;
            v.mAxilWriteMaster.wdata  := sAxilWriteMaster.wdata;
            v.mAxilWriteMaster.wstrb  := sAxilWriteMaster.wstrb;
            -- Reset the flag
            v.validAddress            := '0';
            -- Check for Incoming write transaction
            if (sAxilWriteMaster.awvalid = '1') and (sAxilWriteMaster.wvalid = '1') then
               -- Accept the address and data
               v.sAxilWriteSlave.awready := '1';
               v.sAxilWriteSlave.wready  := '1';
               -- Check if filtering address
               if (blockAll = '1') then
                  -- Forward the error message
                  v.sAxilWriteSlave.bvalid := '1';
                  v.sAxilWriteSlave.bresp  := AXI_ERROR_RESP_G;
                  -- Next state
                  v.state                  := BUS_RESP_S;
               elsif (enFilter = '1') then
                  -- Next state
                  v.state := LOOP_ARRAY_S;
               else
                  -- Forward the write transaction
                  v.mAxilWriteMaster.awvalid := '1';
                  v.mAxilWriteMaster.wvalid  := '1';
                  v.mAxilWriteMaster.bready  := '1';
                  -- Next state
                  v.state                    := MOVE_S;
               end if;
            end if;
         ------------------------------------------------------------------------------------
         when LOOP_ARRAY_S =>
            -- Check for a matched pass through address
            if (r.mAxilWriteMaster.awaddr = FILTER_ADDR_G(r.idx)) then
               -- Set the flag
               v.validAddress := '1';
            end if;
            -- Check the counter
            if (r.idx = FILTER_SIZE_G-1) then
               -- Reset the counter
               v.idx   := 0;
               -- Next state
               v.state := CHECK_FLAG_S;
            else
               -- Increment the counter
               v.idx := r.idx + 1;
            end if;
         ------------------------------------------------------------------------------------
         when CHECK_FLAG_S =>
            -- Check results
            if (r.validAddress = '0') then
               -- Forward the error message
               v.sAxilWriteSlave.bvalid := '1';
               v.sAxilWriteSlave.bresp  := AXI_ERROR_RESP_G;
               -- Next state
               v.state                  := BUS_RESP_S;
            else
               -- Forward the write transaction
               v.mAxilWriteMaster.awvalid := '1';
               v.mAxilWriteMaster.wvalid  := '1';
               v.mAxilWriteMaster.bready  := '1';
               -- Next state
               v.state                    := MOVE_S;
            end if;
         ------------------------------------------------------------------------------------
         when MOVE_S =>
            -- Check for bus response
            if mAxilWriteSlave.bvalid = '1' then
               -- Reset the flag
               v.mAxilWriteMaster.bready := '0';
               -- Forward the error message
               v.sAxilWriteSlave.bvalid  := '1';
               v.sAxilWriteSlave.bresp   := mAxilWriteSlave.bresp;
               -- Next state
               v.state                   := BUS_RESP_S;
            end if;
         ------------------------------------------------------------------------------------
         when BUS_RESP_S =>
            -- Wait for the bus responds
            if (r.sAxilWriteSlave.bvalid = '0') then
               -- Next state
               v.state := IDLE_S;
            end if;
      ------------------------------------------------------------------------------------
      end case;

      -- Synchronous Reset         
      if (axilRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle      
      rin <= v;

      -- Outputs
      sAxilWriteSlave  <= r.sAxilWriteSlave;
      mAxilWriteMaster <= r.mAxilWriteMaster;

   end process comb;

   seq : process (axilClk) is
   begin
      if (rising_edge(axilClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
