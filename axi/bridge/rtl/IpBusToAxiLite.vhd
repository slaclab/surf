-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: IP Bus to AXI-Lite Bridge
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


library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;

entity IpBusToAxiLite is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- Clock and Reset
      clk             : in  sl;
      rst             : in  sl;
      -- IP Bus Slave Interface
      ipbAddr         : in  slv(31 downto 0);
      ipbWdata        : in  slv(31 downto 0);
      ipbStrobe       : in  sl;
      ipbWrite        : in  sl;
      ipbRdata        : out slv(31 downto 0);
      ipbAck          : out sl;
      ipbErr          : out sl;
      -- AXI-Lite Master Interface
      axilReadMaster  : out AxiLiteReadMasterType;
      axilReadSlave   : in  AxiLiteReadSlaveType;
      axilWriteMaster : out AxiLiteWriteMasterType;
      axilWriteSlave  : in  AxiLiteWriteSlaveType);
end IpBusToAxiLite;

architecture rtl of IpBusToAxiLite is

   type StateType is (
      IDLE_S,
      WAIT_S);

   type RegType is record
      ipbRdata : slv(31 downto 0);
      ipbAck   : sl;
      ipbErr   : sl;
      req      : AxiLiteReqType;
      state    : StateType;
   end record;

   constant REG_INIT_C : RegType := (
      ipbRdata => (others => '0'),
      ipbAck   => '0',
      ipbErr   => '0',
      req      => AXI_LITE_REQ_INIT_C,
      state    => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal ack : AxiLiteAckType;

begin

   U_AxiLiteMaster : entity surf.AxiLiteMaster
      generic map (
         TPD_G => TPD_G)
      port map (
         req             => r.req,
         ack             => ack,
         axilClk         => clk,
         axilRst         => rst,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave);

   comb : process (ack, ipbAddr, ipbStrobe, ipbWdata, ipbWrite, r, rst) is
      variable v : RegType;
      variable i : natural;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobes
      v.ipbAck := '0';
      v.ipbErr := '0';

      -- State Machine
      case (r.state) is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check if ready for next transaction
            if (ack.done = '0') and (r.ipbAck = '0') then
               -- Check for new transaction
               if (ipbStrobe = '1') then
                  -- Check for invalid address range
                  if (ipbAddr(31 downto 30) /= 0) then
                     -- Send the IP Bus Error response
                     v.ipbAck := '1';
                     v.ipbErr := '1';
                  else
                     -- Setup the AXI-Lite Master request
                     v.req.request := '1';
                     v.req.rnw     := not(ipbWrite);
                     v.req.address := ipbAddr(29 downto 0) & "00";  -- Convert from 32-bit word address to byte address
                     v.req.wrData  := ipbWdata;
                     -- Next state
                     v.state       := WAIT_S;
                  end if;
               end if;
            end if;
         ----------------------------------------------------------------------
         when WAIT_S =>
            -- Wait for DONE to set
            if (ack.done = '1') then
               -- Reset the flag
               v.req.request := '0';
               -- Send the IP Bus response
               v.ipbAck      := '1';
               v.ipbRdata    := ack.rdData;
               -- Check for bus error
               if (ack.resp /= 0) then
                  v.ipbErr := '1';
               end if;
               -- Next state
               v.state := IDLE_S;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Outputs
      ipbRdata <= r.ipbRdata;
      ipbAck   <= r.ipbAck;
      ipbErr   <= r.ipbErr;

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
