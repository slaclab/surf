-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: AXI-Lite to IP Bus Bridge
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

entity AxiLiteToIpBus is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- Clock and Reset
      clk             : in  sl;
      rst             : in  sl;
      -- AXI-Lite Slave Interface
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;
      -- IP Bus Master Interface
      ipbRdata        : in  slv(31 downto 0);
      ipbAck          : in  sl;
      ipbErr          : in  sl;
      ipbAddr         : out slv(31 downto 0);
      ipbWdata        : out slv(31 downto 0);
      ipbStrobe       : out sl;
      ipbWrite        : out sl);
end AxiLiteToIpBus;

architecture rtl of AxiLiteToIpBus is

   type StateType is (
      IDLE_S,
      WAIT_S);

   type RegType is record
      ipbAddr   : slv(31 downto 0);
      ipbWdata  : slv(31 downto 0);
      ipbStrobe : sl;
      ipbWrite  : sl;
      ack       : AxiLiteAckType;
      state     : StateType;
   end record;

   constant REG_INIT_C : RegType := (
      ipbAddr   => (others => '0'),
      ipbWdata  => (others => '0'),
      ipbStrobe => '0',
      ipbWrite  => '0',
      ack       => AXI_LITE_ACK_INIT_C,
      state     => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal req : AxiLiteReqType;
   signal ack : AxiLiteAckType;

begin

   U_AxiLiteSlave : entity surf.AxiLiteSlave
      generic map (
         TPD_G => TPD_G)
      port map (
         req             => req,
         ack             => ack,
         axilClk         => clk,
         axilRst         => rst,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave);

   comb : process (ipbAck, ipbErr, ipbRdata, r, req, rst) is
      variable v : RegType;
      variable i : natural;
   begin
      -- Latch the current value
      v := r;

      -- State Machine
      case (r.state) is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Reset strobes
            v.ack.done := '0';
            -- Check if ready for next transaction
            if (r.ack.done = '0') then
               -- Check for new transaction
               if (req.request = '1') then
                  -- Check for 32-bit word misalignment
                  if (req.address(1 downto 0) /= 0) then
                     -- Send the Bus Error response
                     v.ack.done := '1';
                     v.ack.resp := AXI_RESP_SLVERR_C;
                  else
                     -- Setup the Master IP Bus request
                     v.ipbAddr   := "00" & req.address(31 downto 2);  -- Convert from byte address to 32-bit word address
                     v.ipbWdata  := req.wrData;
                     v.ipbStrobe := '1';
                     v.ipbWrite  := not(req.rnw);
                     -- Next state
                     v.state     := WAIT_S;
                  end if;
               end if;
            end if;
         ----------------------------------------------------------------------
         when WAIT_S =>
            -- Check for IP bus ACK
            if (ipbAck = '1') then
               -- Reset the false
               v.ipbStrobe  := '0';
               -- Send the Bus response
               v.ack.done   := '1';
               v.ack.rdData := ipbRdata;
               -- Check for bus error
               if (ipbErr = '1') then
                  v.ack.resp := AXI_RESP_SLVERR_C;
               else
                  v.ack.resp := AXI_RESP_OK_C;
               end if;
               -- Next state
               v.state := IDLE_S;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Outputs
      ack       <= v.ack;
      ipbAddr   <= r.ipbAddr;
      ipbWdata  <= r.ipbWdata;
      ipbStrobe <= r.ipbStrobe;
      ipbWrite  <= r.ipbWrite;

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
