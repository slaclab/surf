-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Max5443 DAC Module
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
use surf.AxiLitePkg.all;

entity Max5443 is
   generic (
      TPD_G        : time     := 1 ns;
      CLK_PERIOD_G : real     := 10.0e-9;
      NUM_CHIPS_G  : positive := 1);
   port (
      -- AXI-Lite Register Interface
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;
      -- Guard ring DAC interfaces
      dacSclk         : out sl;
      dacDin          : out sl;
      dacCsb          : out slv(NUM_CHIPS_G-1 downto 0);
      dacClrb         : out sl);
end Max5443;

architecture rtl of Max5443 is

   type RegType is record
      vDacSetting    : Slv16Array(NUM_CHIPS_G-1 downto 0);
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      vDacSetting    => (others => (others => '0')),
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal dacDinSig  : slv(NUM_CHIPS_G-1 downto 0);
   signal dacSclkSig : slv(NUM_CHIPS_G-1 downto 0);
   signal dacClrbSig : slv(NUM_CHIPS_G-1 downto 0);

begin

   dacDin  <= uOr(dacDinSig);
   dacSclk <= uOr(dacSclkSig);
   dacClrb <= uOr(dacClrbSig);

   -------------------------------
   -- Configuration Register
   -------------------------------
   comb : process (axilReadMaster, axilRst, axilWriteMaster, r) is
      variable v      : RegType;
      variable axilEp : AxiLiteEndPointType;

   begin
      -- Latch the current value
      v := r;

      -- Determine the transaction type
      axiSlaveWaitTxn(axilEp, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);

      -- Map out standard registers
      for i in 0 to NUM_CHIPS_G-1 loop
         axiSlaveRegister(axilEp, toSlv(4*i, 8), 0, v.vDacSetting(i));
      end loop;

      -- Closeout the transaction
      axiSlaveDefault(axilEp, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_DECERR_C);

      -- Synchronous Reset
      if axilRst = '1' then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      axilWriteSlave <= r.axilWriteSlave;
      axilReadSlave  <= r.axilReadSlave;

   end process comb;

   seq : process (axilClk) is
   begin
      if rising_edge(axilClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   -----------------------------------------------
   -- DAC Controller
   -----------------------------------------------
   G_MAX5443 : for i in 0 to NUM_CHIPS_G-1 generate
      U_DacCntrl : entity surf.Max5443DacCntrl
         generic map (
            TPD_G => TPD_G)
         port map (
            sysClk    => axilClk,
            sysClkRst => axilRst,
            dacData   => r.vDacSetting(i),
            dacDin    => dacDinSig(i),
            dacSclk   => dacSclkSig(i),
            dacCsL    => dacCsb(i),
            dacClrL   => dacClrbSig(i));
   end generate;

end rtl;
