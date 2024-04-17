-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- CameraLink data de-serializer.
-- Wrapper for ClinkDeSerial when used as dedicated data channel.
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
use surf.ClinkPkg.all;

library unisim;
use unisim.vcomponents.all;

entity ClinkData is
   generic (
      TPD_G        : time   := 1 ns;
      XIL_DEVICE_G : string := "7SERIES");
   port (
      -- Cable Input
      cblHalfP        : inout slv(4 downto 0);  --  8, 10, 11, 12,  9
      cblHalfM        : inout slv(4 downto 0);  -- 21, 23, 24, 25, 22
      -- Delay clock, 200Mhz
      dlyClk          : in    sl;
      dlyRst          : in    sl;
      -- System clock and reset, must be 100Mhz or greater
      sysClk          : in    sl;
      sysRst          : in    sl;
      -- Status and config
      linkConfig      : in    ClLinkConfigType;
      linkStatus      : out   ClLinkStatusType;
      -- Data output
      parData         : out   slv(27 downto 0);
      parValid        : out   sl;
      parReady        : in    sl;
      -- AXI-Lite Interface
      axilReadMaster  : in    AxiLiteReadMasterType;
      axilReadSlave   : out   AxiLiteReadSlaveType;
      axilWriteMaster : in    AxiLiteWriteMasterType;
      axilWriteSlave  : out   AxiLiteWriteSlaveType);
end ClinkData;

architecture rtl of ClinkData is

   type LinkState is (RESET_S, WAIT_C_S, SHIFT_C_S, CHECK_C_S, LOAD_C_S, SHIFT_D_S, CHECK_D_S, DONE_S);

   -- Each delay tap = 1/(32 * 2 * 200Mhz) = 78ps
   -- Input rate = 85Mhz * 7 = 595Mhz = 1.68nS = 21.55 taps

   type RegType is record
      state   : LinkState;
      lastClk : slv(6 downto 0);
      delay   : slv(4 downto 0);
      delayLd : sl;
      bitSlip : sl;
      count   : integer range 0 to 99;
      status  : ClLinkStatusType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state   => RESET_S,
      lastClk => (others => '0'),
      delay   => toSlv(10,5),
      delayLd => '0',
      bitSlip => '0',
      count   => 99,
      status  => CL_LINK_STATUS_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal rstFsm   : sl;
   signal clinkClk : sl;
   signal clinkRst : sl;
   signal intData  : slv(27 downto 0);
   signal parClock : slv(6 downto 0);

   -- attribute MARK_DEBUG             : string;
   -- attribute MARK_DEBUG of r        : signal is "TRUE";
   -- attribute MARK_DEBUG of parClock : signal is "TRUE";
   -- attribute MARK_DEBUG of intData  : signal is "TRUE";
   -- attribute MARK_DEBUG of rstFsm   : signal is "TRUE";

begin

   -------------------------------
   -- DeSerializer
   -------------------------------
   U_DataShift : entity surf.ClinkDataShift
      generic map (
         TPD_G        => TPD_G,
         XIL_DEVICE_G => XIL_DEVICE_G)
      port map (
         cblHalfP        => cblHalfP,
         cblHalfM        => cblHalfM,
         linkRst         => linkConfig.rstPll,
         dlyClk          => dlyClk,
         dlyRst          => dlyRst,
         clinkClk        => clinkClk,
         clinkRst        => clinkRst,
         -- Parallel clock and data output (clinkClk)
         parData         => intData,
         parClock        => parClock,
         -- Control inputs
         delay           => r.delay,
         delayLd         => r.delayLd,
         bitSlip         => r.bitSlip,
         -- Frequency Measurements
         clkInFreq       => linkStatus.clkInFreq,
         clinkClkFreq    => linkStatus.clinkClkFreq,
         -- AXI-Lite Interface
         sysClk          => sysClk,
         sysRst          => sysRst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave);

   -------------------------------
   -- State Machine
   -------------------------------
   comb : process (clinkRst, parClock, r, rstFsm) is
      variable v : RegType;
   begin

      v := r;

      -- Init
      v.bitSlip := '0';
      v.delayLd := '0';

      -- Counter
      if r.count = 0 then
         v.count := 99;
      else
         v.count := r.count - 1;
      end if;

      -- State machine
      case r.state is

         -- Reset state
         when RESET_S =>
            if r.count = 0 then
               v.state   := WAIT_C_S;
               v.delayLd := '1';
            end if;

         -- Wait while recording clock state
         when WAIT_C_S =>
            v.lastClk := parClock;

            if r.count = 0 then
               v.state := SHIFT_C_S;
            end if;

         -- Shift clock one delay tick
         when SHIFT_C_S =>
            v.delay   := r.delay + 1;
            v.delayLd := '1';
            v.state   := CHECK_C_S;

         -- Check for clock value change
         when CHECK_C_S =>
            if r.count = 0 then

               -- Check for error
               if r.delay = 31 then
                  v.state := DONE_S;

               -- Check for clock change
               elsif parClock /= r.lastClk and (r.lastClk = "1100011" or
                                                r.lastClk = "1110001" or
                                                r.lastClk = "1111000" or
                                                r.lastClk = "0111100" or
                                                r.lastClk = "0011110" or
                                                r.lastClk = "0001111" or
                                                r.lastClk = "1000111") then
                  v.state := LOAD_C_S;

               -- Shift again
               else
                  v.state := WAIT_C_S;
               end if;
            end if;

         -- Load final clock shift
         when LOAD_C_S =>
            v.delay   := r.delay - "01010";  -- 10 = 1/2 cycle
            v.delayLd := '1';
            v.state   := CHECK_D_S;

         when CHECK_D_S =>
            if r.count = 0 then
               if parClock = "1100011" then
                  v.state := DONE_S;
               else
                  v.state := SHIFT_D_S;
               end if;
            end if;

         when SHIFT_D_S =>
            v.bitSlip         := '1';
            v.state           := CHECK_D_S;
            v.status.shiftCnt := r.status.shiftCnt + 1;

         when DONE_S =>
            if r.count = 0 then
               if parClock = "1100011" and r.delay /= 31 then
                  v.status.locked := '1';
               elsif (r.status.locked = '0') then
                  -- Retry to lock again
                  v := REG_INIT_C;
               end if;
            end if;

         when others =>
      end case;

      v.status.delay := r.delay;

      -- Reset
      if (clinkRst = '1') or (rstFsm = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   -- sync logic
   seq : process (clinkClk) is
   begin
      if (rising_edge(clinkClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   U_RstSync : entity surf.RstSync
      generic map (
         TPD_G => TPD_G)
      port map (
         clk      => clinkClk,
         asyncRst => linkConfig.rstFsm,
         syncRst  => rstFsm);

   --------------------------------------
   -- Output FIFO and status
   --------------------------------------
   U_DataFifo : entity surf.Fifo
      generic map (
         TPD_G         => TPD_G,
         MEMORY_TYPE_G => "distributed",
         FWFT_EN_G     => true,
         DATA_WIDTH_G  => 28,
         ADDR_WIDTH_G  => 4)
      port map (
         rst    => clinkRst,
         wr_clk => clinkClk,
         wr_en  => '1',
         din    => intData,
         rd_clk => sysClk,
         rd_en  => parReady,
         dout   => parData,
         valid  => parValid);

   U_Locked : entity surf.Synchronizer
      generic map (TPD_G => TPD_G)
      port map (
         clk     => sysClk,
         rst     => sysRst,
         dataIn  => r.status.locked,
         dataOut => linkStatus.locked);

   U_Delay : entity surf.SynchronizerVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => 5)
      port map (
         clk     => sysClk,
         rst     => sysRst,
         dataIn  => r.status.delay,
         dataOut => linkStatus.delay);

   U_ShiftCnt : entity surf.SynchronizerVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => 3)
      port map (
         clk     => sysClk,
         rst     => sysRst,
         dataIn  => r.status.shiftCnt,
         dataOut => linkStatus.shiftCnt);

end architecture rtl;

