-------------------------------------------------------------------------------
-- File       : ClinkClk.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-11-13
-------------------------------------------------------------------------------
-- Description:
-- CameraLink clock module
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
library unisim;
use unisim.vcomponents.all;

entity ClinkClk is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- Input clock
      clinkClkIn      : in  sl;
      -- Async reset
      resetIn         : in  sl;
      -- Clock and reset out
      clinkClk        : out sl;
      clinkRst        : out sl;
      clinkClk7x      : out sl; -- 7X clock input
      -- Status, clinkClk
      clinkShift      : out sl;
      shiftCount      : out slv(3 downto 0);
      clinkLocked     : out sl;
      -- AXI-Lite Interface 
      axilClk         : in  sl                     := '0';
      axilRst         : in  sl                     := '0';
      axilReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave  : out AxiLiteWriteSlaveType);      

end ClinkClk;

architecture structure of ClinkClk is

   type RegType is record
      count   : integer range 0 to 6;
      sftCnt  : slv(3 downto 0);
      locked  : sl;
      shift   : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      count   => 0,
      sftCnt  => (others=>'0'),
      locked  => '0',
      shift   => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal intData        : slv(6 downto 0);
   signal iclinkClk      : sl;
   signal iclinkRst      : sl;
   signal iclinkClk7x    : sl;
   signal iclinkClk7xInv : sl;

begin

   -- Clock Manager
   U_ClkGen : entity work.ClockManager7
      generic map (
         TPD_G               => TPD_G,
         INPUT_BUFG_G        => false,
         NUM_CLOCKS_G        => 2,
         BANDWIDTH_G         => "OPTIMIZED",
         CLKIN_PERIOD_G      => 11.765,
         DIVCLK_DIVIDE_G     => 1,
         CLKFBOUT_MULT_F_G   => 14.0,
         CLKOUT0_DIVIDE_F_G  => 14.0,
         CLKOUT1_DIVIDE_G    => 2)
      port map (
         clkIn            => clinkClkIn,
         rstIn            => resetIn,
         clkOut(0)        => iclinkClk,
         clkOut(1)        => iclinkClk7x,
         rstOut(0)        => iclinkRst,
         axilClk          => axilClk,
         axilRst          => axilRst,
         axilReadMaster   => axilReadMaster,
         axilReadSlave    => axilReadSlave,
         axilWriteMaster  => axilWriteMaster,
         axilWriteSlave   => axilWriteSlave);

   -- Clocks
   clinkClk       <= iclinkClk;
   clinkRst       <= iclinkRst;
   clinkClk7x     <= iclinkClk7x;
   iclinkClk7xInv <= not iclinkClk7x;

   -- ISERDESE2: Input SERial/DESerializer with bitslip
   -- 7 Series
   -- Xilinx HDL Libraries Guide, version 2012.2
   U_Iserdes : ISERDESE2
      generic map (
         DATA_RATE         => "SDR",        -- DDR, SDR
         DATA_WIDTH        => 7,            -- Parallel data width (2-8,10,14)
         DYN_CLKDIV_INV_EN => "FALSE",
         DYN_CLK_INV_EN    => "FALSE",
         INTERFACE_TYPE    => "NETWORKING", -- MEMORY, MEMORY_DDR3, MEMORY_QDR, NETWORKING, OVERSAMPLE
         IOBDELAY          => "NONE",       -- NONE, BOTH, IBUF, IFD
         NUM_CE            => 1,            -- Number of clock enables (1,2)
         OFB_USED          => "FALSE",      -- Select OFB path (FALSE, TRUE)
         SERDES_MODE       => "MASTER"      -- MASTER, SLAVE
      )
      port map (
         Q1           => intData(0),
         Q2           => intData(1),
         Q3           => intData(2),
         Q4           => intData(3),
         Q5           => intData(4),
         Q6           => intData(5),
         Q7           => intData(6),
         BITSLIP      => r.shift,
         CE1          => '1',
         CE2          => '1',
         CLKDIVP      => '0',
         CLK          => iclinkClk7x,
         CLKB         => iclinkClk7xInv,
         CLKDIV       => iclinkClk,
         OCLK         => '0',
         DYNCLKDIVSEL => '0',
         DYNCLKSEL    => '0',
         D            => clinkClkIn,
         DDLY         => '0',
         OFB          => '0',
         OCLKB        => '0',
         RST          => iclinkRst,
         SHIFTIN1     => '0',
         SHIFTIN2     => '0'
      );


   -- Data tracking
   comb : process (iclinkRst, r, intData) is
      variable v  : RegType;
   begin

      -- Latch the current value
      v := r;

      -- Clear shift
      v.shift := '0';

      -- Counter
      if r.count = 100 then
         v.count := 0;
      else
         v.count := r.count + 1;
      end if;

      -- Check for required bit shift every 100 clocks
      if r.count = 100 then
         if intData /= "1100011" then
            v.shift  := '1';
            v.locked := '0';
            v.sftCnt := r.sftCnt + 1;
         else
            v.locked := '1';
         end if;
      end if;

      -- Reset
      if (iclinkRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      clinkLocked <= r.locked;
      clinkShift  <= r.shift;
      shiftCount  <= r.sftCnt;

   end process comb;

   -- sync logic
   seq : process (iclinkClk) is
   begin
      if (rising_edge(iclinkClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end structure;

