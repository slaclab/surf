-------------------------------------------------------------------------------
-- Title      : CoaXPress Protocol: http://jiia.org/wp-content/themes/jiia/pdf/standard_dl/coaxpress/CXP-001-2021.pdf
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Event Ack Message Generator
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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.CoaXPressPkg.all;

entity CoaXPressEventAckMsg is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- Clock and Reset
      clk            : in  sl;
      rst            : in  sl;
      -- Event ACK Interface
      eventAck       : in  sl;
      eventTag       : in  slv(7 downto 0);
      -- AXI Stream Interface
      eventAckMaster : out AxiStreamMasterType;
      eventAckSlave  : in  AxiStreamSlaveType);
end entity CoaXPressEventAckMsg;

architecture rtl of CoaXPressEventAckMsg is

   type StateType is (
      IDLE_S,
      XFER_S);

   type RegType is record
      byteIdx        : natural range 0 to 3;
      idx            : natural range 0 to 3;
      tData          : Slv32Array(3 downto 0);
      tDataK         : slv(3 downto 0);
      eventAckMaster : AxiStreamMasterType;
      state          : StateType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      byteIdx        => 0,
      idx            => 0,
      tData          => (
         0           => CXP_SOP_C,
         1           => x"08_08_08_08",
         2           => x"00_00_00_00",
         3           => CXP_EOP_C),
      tDataK         => "1001",
      eventAckMaster => AXI_STREAM_MASTER_INIT_C,
      state          => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (eventAck, eventAckSlave, eventTag, r, rst) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Flow Control
      if (eventAckSlave.tReady = '1') then
         v.eventAckMaster.tValid := '0';
         v.eventAckMaster.tLast  := '0';
      end if;

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check for the strobe
            if (eventAck = '1') then
               -- Create response message
               v.tDataK   := "1001";
               v.tData(0) := CXP_SOP_C;
               v.tData(1) := x"08_08_08_08";
               v.tData(2) := eventTag & eventTag & eventTag & eventTag;
               v.tData(3) := CXP_EOP_C;
               -- Next State
               v.state    := XFER_S;
            end if;
         ----------------------------------------------------------------------
         when XFER_S =>
            -- Check if ready to move data
            if (v.eventAckMaster.tValid = '0') then

               -- Send the transaction
               v.eventAckMaster.tValid            := '1';
               v.eventAckMaster.tData(7 downto 0) := r.tData(r.idx)(8*r.byteIdx+7 downto 8*r.byteIdx);
               v.eventAckMaster.tUser(0)          := r.tDataK(r.idx);

               -- Check counter
               if (r.byteIdx = 3) then

                  -- Reset counter
                  v.byteIdx := 0;

                  -- Check counter
                  if (r.idx = 3) then

                     -- Reset counter
                     v.idx := 0;

                     -- Set the flag
                     v.eventAckMaster.tLast := '1';

                     -- Next State
                     v.state := IDLE_S;

                  else
                     -- Increment counter
                     v.idx := r.idx + 1;
                  end if;

               else
                  -- Increment counter
                  v.byteIdx := r.byteIdx + 1;
               end if;

            end if;
      ----------------------------------------------------------------------
      end case;

      -- Outputs
      eventAckMaster <= r.eventAckMaster;

      -- Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (clk) is
   begin
      if (rising_edge(clk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
