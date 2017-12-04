-------------------------------------------------------------------------------
-- File       : SaltTxResize.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-11-08
-- Last update: 2017-11-08
-------------------------------------------------------------------------------
-- Description: SALT TX Engine Resizer Module
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SaltPkg.all;

entity SaltTxResize is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- Clock and Reset
      clk      : in  sl;
      rst      : in  sl;
      -- AXI Stream Interface
      rxMaster : in  AxiStreamMasterType;
      rxSlave  : out AxiStreamSlaveType;
      -- GMII Interface
      txEn     : out sl;
      txData   : out slv(7 downto 0));
end SaltTxResize;

architecture rtl of SaltTxResize is

   type StateType is (
      MOVE_S,
      INTER_GAP_S);

   type RegType is record
      txEn    : sl;
      txData  : slv(7 downto 0);
      idx     : natural range 0 to 3;
      gapCnt  : natural range 0 to INTER_GAP_SIZE_C;
      rxSlave : AxiStreamSlaveType;
      state   : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      txEn    => '0',
      txData  => (others => '0'),
      idx     => 0,
      gapCnt  => 0,
      rxSlave => AXI_STREAM_SLAVE_INIT_C,
      state   => MOVE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (r, rst, rxMaster) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset the flags
      v.rxSlave := AXI_STREAM_SLAVE_INIT_C;
      v.txEn    := '0';
      v.txData  := x"BC";

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when MOVE_S =>
            -- Check for data
            if (rxMaster.tValid = '1') then
               -- Move the data
               v.txEn   := '1';
               v.txData := rxMaster.tData((8*r.idx)+7 downto (8*r.idx));
               -- Check the counter
               if (r.idx = 3) then
                  -- Reset the counter
                  v.idx            := 0;
                  -- Accept the data
                  v.rxSlave.tReady := '1';
                  -- Check for last transfer
                  if (rxMaster.tLast = '1') then
                     -- Next state
                     v.state := INTER_GAP_S;
                  end if;
               else
                  -- Increment the counter
                  v.idx := r.idx + 1;
               end if;
            end if;
         ----------------------------------------------------------------------
         when INTER_GAP_S =>
            -- Check the intergap counter
            if r.gapCnt = INTER_GAP_SIZE_C then
               -- Reset the counter
               v.gapCnt := 0;
               -- Next state
               v.state  := MOVE_S;
            else
               v.gapCnt := r.gapCnt + 1;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs        
      rxSlave <= v.rxSlave;
      txEn    <= r.txEn;
      txData  <= r.txData;

   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
