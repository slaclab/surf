-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- CameraLink Registers
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
use surf.ClinkPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
library unisim;
use unisim.vcomponents.all;

entity ClinkReg is
   generic (
      TPD_G        : time                 := 1 ns;
      CHAN_COUNT_G : integer range 1 to 2 := 1);
   port (
      chanStatus      : in  ClChanStatusArray(1 downto 0);
      linkStatus      : in  ClLinkStatusArray(2 downto 0);
      chanConfig      : out ClChanConfigArray(1 downto 0);
      linkConfig      : out ClLinkConfigType;
      -- Axi-Lite Interface
      sysClk          : in  sl;
      sysRst          : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end ClinkReg;

architecture rtl of ClinkReg is

   type RegType is record
      locked         : slv(2 downto 0);
      lockCnt        : Slv8Array(2 downto 0);
      chanConfig     : ClChanConfigArray(1 downto 0);
      linkConfig     : ClLinkConfigType;
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      locked         => "000",
      lockCnt        => (others => x"00"),
      chanConfig     => (others => CL_CHAN_CONFIG_INIT_C),
      linkConfig     => CL_LINK_CONFIG_INIT_C,
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   ---------------------------------
   -- Registers
   ---------------------------------
   comb : process (axilReadMaster, axilWriteMaster, chanStatus, linkStatus, r,
                   sysRst) is

      variable v      : RegType;
      variable axilEp : AxiLiteEndpointType;
      variable i      : natural;
   begin

      -- Latch the current value
      v := r;

      -- Loop through the locking channels
      for i in 2 downto 0 loop
         -- Keep delayed copy of the locks
         v.locked(i) := linkStatus(i).locked;
         -- Check for 0->1 lock transition and not max value
         if (r.locked(i) = '0') and (linkStatus(i).locked = '1') and (r.lockCnt(i) /= x"FF") then
            -- Increment the counter
            v.lockCnt(i) := r.lockCnt(i) + 1;
         end if;
      end loop;

      -- Check for counter reset
      if (r.linkConfig.cntRst = '1') then
         v.lockCnt := (others => x"00");
      end if;

      ------------------------
      -- AXI-Lite Transactions
      ------------------------

      -- Determine the transaction type
      axiSlaveWaitTxn(axilEp, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);

      -- Common Config
      axiSlaveRegisterR(axilEp, x"000", 0, toSlv(CHAN_COUNT_G, 4));
      axiSlaveRegister (axilEp, x"004", 0, v.linkConfig.rstPll);
      axiSlaveRegister (axilEp, x"004", 1, v.linkConfig.rstFsm);
      axiSlaveRegister (axilEp, x"004", 2, v.linkConfig.cntRst);

      -- Common Status
      axiSlaveRegisterR(axilEp, x"010", 0, linkStatus(0).locked);
      axiSlaveRegisterR(axilEp, x"010", 1, linkStatus(1).locked);
      axiSlaveRegisterR(axilEp, x"010", 2, linkStatus(2).locked);
      axiSlaveRegisterR(axilEp, x"010", 8, r.lockCnt(0));
      axiSlaveRegisterR(axilEp, x"010", 16, r.lockCnt(1));
      axiSlaveRegisterR(axilEp, x"010", 24, r.lockCnt(2));
      axiSlaveRegisterR(axilEp, x"014", 0, linkStatus(0).shiftCnt);
      axiSlaveRegisterR(axilEp, x"014", 8, linkStatus(1).shiftCnt);
      axiSlaveRegisterR(axilEp, x"014", 16, linkStatus(2).shiftCnt);
      axiSlaveRegisterR(axilEp, x"018", 0, linkStatus(0).delay);
      axiSlaveRegisterR(axilEp, x"018", 8, linkStatus(1).delay);
      axiSlaveRegisterR(axilEp, x"018", 16, linkStatus(2).delay);

      axiSlaveRegisterR(axilEp, x"01C", 0, linkStatus(0).clkInFreq);
      axiSlaveRegisterR(axilEp, x"020", 0, linkStatus(1).clkInFreq);
      axiSlaveRegisterR(axilEp, x"024", 0, linkStatus(2).clkInFreq);

      axiSlaveRegisterR(axilEp, x"028", 0, linkStatus(0).clinkClkFreq);
      axiSlaveRegisterR(axilEp, x"02C", 0, linkStatus(1).clinkClkFreq);
      axiSlaveRegisterR(axilEp, x"030", 0, linkStatus(2).clinkClkFreq);

      -- Channel A Config
      axiSlaveRegister (axilEp, x"100", 0, v.chanConfig(0).linkMode);
      axiSlaveRegister (axilEp, x"104", 0, v.chanConfig(0).dataMode);
      axiSlaveRegister (axilEp, x"108", 0, v.chanConfig(0).frameMode);
      axiSlaveRegister (axilEp, x"10C", 0, v.chanConfig(0).tapCount);
      axiSlaveRegister (axilEp, x"110", 0, v.chanConfig(0).dataEn);
      axiSlaveRegister (axilEp, x"110", 1, v.chanConfig(0).blowoff);
      axiSlaveRegister (axilEp, x"110", 2, v.chanConfig(0).cntRst);
      axiSlaveRegister (axilEp, x"110", 16, v.chanConfig(0).serThrottle);
      axiSlaveRegister (axilEp, x"114", 0, v.chanConfig(0).serBaud);
      axiSlaveRegister (axilEp, x"118", 0, v.chanConfig(0).swCamCtrlEn);
      axiSlaveRegister (axilEp, x"11C", 0, v.chanConfig(0).swCamCtrl);

      -- Channel A Status
      axiSlaveRegisterR(axilEp, x"120", 0, chanStatus(0).running);
      axiSlaveRegisterR(axilEp, x"124", 0, chanStatus(0).frameCount);
      axiSlaveRegisterR(axilEp, x"128", 0, chanStatus(0).dropCount);
      axiSlaveRegisterR(axilEp, x"12C", 0, chanStatus(0).frameSize);

      -- Channel A ROI
      axiSlaveRegister (axilEp, x"130", 0, v.chanConfig(0).hSkip);
      axiSlaveRegister (axilEp, x"134", 0, v.chanConfig(0).hActive);
      axiSlaveRegister (axilEp, x"138", 0, v.chanConfig(0).vSkip);
      axiSlaveRegister (axilEp, x"13C", 0, v.chanConfig(0).vActive);

      -- Channel B Config
      axiSlaveRegister (axilEp, x"200", 0, v.chanConfig(1).linkMode);
      axiSlaveRegister (axilEp, x"204", 0, v.chanConfig(1).dataMode);
      axiSlaveRegister (axilEp, x"208", 0, v.chanConfig(1).frameMode);
      axiSlaveRegister (axilEp, x"20C", 0, v.chanConfig(1).tapCount);
      axiSlaveRegister (axilEp, x"210", 0, v.chanConfig(1).dataEn);
      axiSlaveRegister (axilEp, x"210", 1, v.chanConfig(1).blowoff);
      axiSlaveRegister (axilEp, x"210", 2, v.chanConfig(1).cntRst);
      axiSlaveRegister (axilEp, x"210", 16, v.chanConfig(1).serThrottle);
      axiSlaveRegister (axilEp, x"214", 0, v.chanConfig(1).serBaud);
      axiSlaveRegister (axilEp, x"218", 0, v.chanConfig(1).swCamCtrlEn);
      axiSlaveRegister (axilEp, x"21C", 0, v.chanConfig(1).swCamCtrl);

      -- Channel B Status
      axiSlaveRegisterR(axilEp, x"220", 0, chanStatus(1).running);
      axiSlaveRegisterR(axilEp, x"224", 0, chanStatus(1).frameCount);
      axiSlaveRegisterR(axilEp, x"228", 0, chanStatus(1).dropCount);
      axiSlaveRegisterR(axilEp, x"22C", 0, chanStatus(1).frameSize);

      -- Channel B ROI
      axiSlaveRegister (axilEp, x"230", 0, v.chanConfig(1).hSkip);
      axiSlaveRegister (axilEp, x"234", 0, v.chanConfig(1).hActive);
      axiSlaveRegister (axilEp, x"238", 0, v.chanConfig(1).vSkip);
      axiSlaveRegister (axilEp, x"23C", 0, v.chanConfig(1).vActive);

      axiSlaveDefault(axilEp, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_DECERR_C);

      -- Prevent zero baud rate
      if (v.chanConfig(0).serBaud = 0) then
         v.chanConfig(0).serBaud := toSlv(1, 24);
      end if;
      if (v.chanConfig(1).serBaud = 0) then
         v.chanConfig(1).serBaud := toSlv(1, 24);
      end if;

      -------------
      -- Reset
      -------------
      if (sysRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      axilReadSlave  <= r.axilReadSlave;
      axilWriteSlave <= r.axilWriteSlave;
      chanConfig     <= r.chanConfig;
      linkConfig     <= r.linkConfig;

   end process comb;

   seq : process (sysClk) is
   begin
      if (rising_edge(sysClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
