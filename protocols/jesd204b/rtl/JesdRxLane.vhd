-------------------------------------------------------------------------------
-- File       : JesdRxLane.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-14
-- Last update: 2017-11-10
-------------------------------------------------------------------------------
-- Description: JesdRx single lane module
--              Receiver JESD204b standard.
--              Supports sub-class 1 deterministic latency.
--              Supports sub-class 0 non deterministic latency
--              Features:
--              - Comma synchronization
--              - Internal buffer to align the lanes.
--              - Sample data alignment (Sample extraction from GT word - barrel shifter).
--              - Alignment character replacement.
--              - Scrambling support
--             Status register encoding:
--                bit 0: GT Reset done
--                bit 1: Received data valid
--                bit 2: Received data is misaligned
--                bit 3: Synchronization output status 
--                bit 4: Rx buffer overflow
--                bit 5: Rx buffer underflow
--                bit 6: Comma position not as expected during alignment
--                bit 7: RX module enabled status
--                bit 8: SysRef detected (active only when the lane is enabled)
--                bit 9: Comma (K28.5) detected
--                bit 10-13: Disparity error
--                bit 14-17: Not in table Error
--                bit 18-25: 8-bit buffer latency
--                bit 26: CDR Status of the GTH (Not used in yaml)
--
--          Note: sampleData_o is little endian and not byte swapped
--                First sample in time:  sampleData_o(15 downto 0) 
--                Second sample in time: sampleData_o(31 downto 16)
--
--          Note: The output ADC sample data can be inverted.
--                     inv_i:     '1' Inverted,      '0' Normal
--                If inverted the mode can be chosen:
--                     invMode_i: '1' Offset binary, '0' Twos complement 
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
use work.Jesd204bPkg.all;

entity JesdRxLane is
   generic (
      TPD_G : time := 1 ns;

      -- Number of bytes in a frame
      F_G : positive := 2;

      -- Number of frames in a multi frame
      K_G : positive := 32
      );
   port (

      -- JESD
      -- Clocks and Resets   
      devClk_i : in sl;
      devRst_i : in sl;

      -- JESD subclass selection: '0' or '1'(default)     
      subClass_i : in sl;

      -- SYSREF for subclass 1 fixed latency
      sysRef_i : in sl;

      -- Clear registered errors     
      clearErr_i : in sl;

      -- Control register
      enable_i     : in  sl;
      replEnable_i : in  sl;
      scrEnable_i  : in  sl;
      status_o     : out slv((RX_STAT_WIDTH_C)-1 downto 0);

      -- Data and character inputs from GT (transceivers)
      r_jesdGtRx : in jesdGtRxLaneType;

      -- Local multi frame clock
      lmfc_i : in sl;

      -- Error mask
      linkErrMask_i : in slv(5 downto 0) := (others => '1');

      -- One or more RX modules requested synchronization
      nSyncAny_i   : in sl;
      nSyncAnyD1_i : in sl;

      -- Invert ADC data
      inv_i : in sl := '0';

      -- Synchronization request output 
      nSync_o : out sl;

      -- Synchronization process is complete and data is valid
      dataValid_o  : out sl;
      sampleData_o : out slv((GT_WORD_SIZE_C*8)-1 downto 0)
      );
end JesdRxLane;


architecture rtl of JesdRxLane is

   constant ERR_REG_WIDTH_C : positive := 4+2*GT_WORD_SIZE_C;

-- Register
   type RegType is record
      bufWeD1         : sl;
      errReg          : slv(ERR_REG_WIDTH_C-1 downto 0);
      sampleData      : slv(sampleData_o'range);
      sampleDataValid : sl;
      jesdGtRx        : jesdGtRxLaneType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      bufWeD1         => '0',
      errReg          => (others => '0'),
      sampleData      => (others => '0'),
      sampleDataValid => '0',
      jesdGtRx        => JESD_GT_RX_LANE_INIT_C
      );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- Internal signals

   -- Control signals from FSM
   signal s_nSync         : sl;
   signal s_readBuff      : sl;
   signal s_alignFrame    : sl;
   signal s_alignFrameDly : sl;
   signal s_ila           : sl;
   signal s_dataValid     : sl;
   signal s_dataValidDly  : sl;

   -- Buffer control
   signal s_bufRst : sl;
   signal s_bufWe  : sl;
   signal s_bufRe  : sl;

   -- Datapath
   signal s_charAndData        : slv(((GT_WORD_SIZE_C*8)+GT_WORD_SIZE_C)-1 downto 0);
   signal s_charAndDataBuff    : slv(s_charAndData'range);
   signal s_charAndDataBuffDly : slv(s_charAndData'range);
   signal s_sampleData         : slv(sampleData_o'range);
   signal s_sampleDataValid    : sl;

   -- Statuses
   signal s_bufOvf      : sl;
   signal s_bufUnf      : sl;
   signal s_bufFull     : sl;
   signal s_alignErr    : sl;
   signal s_positionErr : sl;
   signal s_linkErrVec  : slv(5 downto 0);
   signal s_linkErr     : sl;
   signal s_kDetected   : sl;
   signal s_refDetected : sl;
   signal s_errComb     : slv(ERR_REG_WIDTH_C-1 downto 0);
   signal s_buffLatency : slv(7 downto 0);

begin

   s_charAndData <= r.jesdGtRx.dataK & r.jesdGtRx.data;

   -- Buffer control
   s_bufRst <= devRst_i or not s_nSync or not enable_i;
   s_bufWe  <= not s_bufRst and not s_bufFull;
   s_bufRe  <= r.bufWeD1 and s_readBuff;

   -- Buffer samples between first data and LMFC
   -- Min size one LMFC period
   RX_buffer_fifo_INST : entity work.FifoSync
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => '1',
         RST_ASYNC_G    => false,
         BRAM_EN_G      => true,
         FWFT_EN_G      => false,
         USE_DSP48_G    => "no",
         ALTERA_SYN_G   => false,
         ALTERA_RAM_G   => "M9K",
         PIPE_STAGES_G  => 0,
         DATA_WIDTH_G   => (GT_WORD_SIZE_C*8) + GT_WORD_SIZE_C,
         -- ADDR_WIDTH_G   => bitSize((K_G * F_G)/GT_WORD_SIZE_C),
         ADDR_WIDTH_G   => 8,
         INIT_G         => "0",
         FULL_THRES_G   => 1,
         EMPTY_THRES_G  => 1)
      port map (
         rst          => s_bufRst,
         clk          => devClk_i,
         wr_en        => s_bufWe,       -- Always write when enabled
         rd_en        => s_bufRe,  -- Hold read while sync not in sync with LMFC
         din          => s_charAndData,
         dout         => s_charAndDataBuff,
         data_count   => s_buffLatency,
         wr_ack       => open,
         valid        => open,
         overflow     => s_bufOvf,
         underflow    => s_bufUnf,
         prog_full    => open,
         prog_empty   => open,
         almost_full  => open,
         almost_empty => open,
         full         => s_bufFull,
         not_full     => open,
         empty        => open
         );

   -- Synchronization FSM
   syncFSM_INST : entity work.JesdSyncFsmRx
      generic map (
         TPD_G => TPD_G,
         F_G   => F_G,
         K_G   => K_G)
      port map (
         clk          => devClk_i,
         rst          => devRst_i,
         enable_i     => enable_i,
         sysRef_i     => sysRef_i,
         dataRx_i     => r.jesdGtRx.data,
         chariskRx_i  => r.jesdGtRx.dataK,
         gtReady_i    => r.jesdGtRx.rstDone,
         lmfc_i       => lmfc_i,
         nSyncAnyD1_i => nSyncAnyD1_i,
         nSyncAny_i   => nSyncAny_i,
         linkErr_i    => s_linkErr,
         nSync_o      => s_nSync,
         readBuff_o   => s_readBuff,
         -- buffLatency_o => s_buffLatency,
         alignFrame_o => s_alignFrame,
         ila_o        => s_ila,
         kDetected_o  => s_kDetected,
         sysref_o     => s_refDetected,
         dataValid_o  => s_dataValid,
         subClass_i   => subClass_i
         );

   -- Align the rx data within the GT word and replace the characters. 
   alignFrRepCh_INST : entity work.JesdAlignFrRepCh
      generic map (
         TPD_G => TPD_G,
         F_G   => F_G)
      port map (
         clk               => devClk_i,
         rst               => devRst_i,
         replEnable_i      => replenable_i,
         scrEnable_i       => scrEnable_i,
         alignFrame_i      => s_alignFrameDly,
         dataValid_i       => s_dataValidDly,
         dataRx_i          => s_charAndDataBuffDly((GT_WORD_SIZE_C*8)-1 downto 0),
         chariskRx_i       => s_charAndDataBuffDly(((GT_WORD_SIZE_C*8)+GT_WORD_SIZE_C)-1 downto (GT_WORD_SIZE_C*8)),
         sampleDataValid_o => s_sampleDataValid,
         sampleData_o      => s_sampleData,
         alignErr_o        => s_alignErr,
         positionErr_o     => s_positionErr
         );

   process(devClk_i)
   begin
      if rising_edge(devClk_i) then

         -- Register to help with timing
         s_alignFrameDly      <= s_alignFrame      after TPD_G;
         s_dataValidDly       <= s_dataValid       after TPD_G;
         s_charAndDataBuffDly <= s_charAndDataBuff after TPD_G;

         -- Link error masked by the mask from register and ORed
         s_linkErrVec <= s_positionErr & s_bufOvf & s_bufUnf & uOr(r.jesdGtRx.dispErr) & uOr(r.jesdGtRx.decErr) & s_alignErr after TPD_G;
         s_linkErr    <= uOr(s_linkErrVec and linkErrMask_i) and enable_i                                                    after TPD_G;

         -- Combine errors that need registering
         s_errComb <= r.jesdGtRx.decErr & r.jesdGtRx.dispErr & s_alignErr & s_positionErr & s_bufOvf & s_bufUnf after TPD_G;

      end if;
   end process;

   -- Synchronous process function:
   -- - Registering of errors
   -- - Delay the s_bufWe to use it for s_bufRe
   -- - Inverting ADC data
   -------------------------------------------------------------------------------
   -------------------------------------------------------------------------------
   comb : process (clearErr_i, devRst_i, enable_i, inv_i, r, r_jesdGtRx,
                   s_bufWe, s_errComb, s_nSync, s_sampleData,
                   s_sampleDataValid) is
      variable v : RegType;
   begin
      v := r;

      v.jesdGtRx := r_jesdGtRx;
      v.bufWeD1  := s_bufWe;

      -- Register errors (store until reset)
      if (r.jesdGtRx.rstDone = '1' and s_nSync = '1') then
         for I in 0 to(ERR_REG_WIDTH_C-1) loop
            if (s_errComb(I) = '1') and (enable_i = '1') then
               v.errReg(I) := '1';
            end if;
         end loop;
      end if;

      -- Clear registered errors if module is disabled
      if (clearErr_i = '1') then
         v.errReg := REG_INIT_C.errReg;
      end if;

      -- Invert sample data
      v.sampleDataValid := s_sampleDataValid;

      if (inv_i = '1') then
         -- Invert sample data      
         v.sampleData := invData(s_sampleData, F_G, GT_WORD_SIZE_C);
      else
         v.sampleData := s_sampleData;
      end if;

      -- Reset registers
      if (devRst_i = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;
   end process comb;

   seq : process (devClk_i) is
   begin
      if (rising_edge(devClk_i)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   -- Output assignment
   nSync_o      <= s_nSync;
   dataValid_o  <= r.sampleDataValid;
   sampleData_o <= endianSwapSlv(r.sampleData, GT_WORD_SIZE_C);
   status_o     <= r.jesdGtRx.cdrStable & s_buffLatency & r.errReg(r.errReg'high downto 4) & s_kDetected & s_refDetected & enable_i & r.errReg(2 downto 0) & s_nSync & r.errReg(3) & s_dataValidDly & r.jesdGtRx.rstDone;
-----------------------------------------------------------------------------------------
end rtl;
