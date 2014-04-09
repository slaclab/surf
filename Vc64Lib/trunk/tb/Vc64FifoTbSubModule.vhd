-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Vc64FifoTb.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-08
-- Last update: 2014-04-09
-- Platform   : Vivado 2013.3
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.Vc64Pkg.all;

entity Vc64FifoTbSubModule is
   generic (
      TPD_G             : time;
      PIPE_STAGES_G     : integer;
      BRAM_EN_G         : boolean;
      GEN_SYNC_FIFO_G   : boolean;
      USE_BUILT_IN_G    : boolean;
      LAST_DATA_G       : slv(63 downto 0);
      READ_BUSY_THRES_G : slv(3 downto 0));  
   port (
      -- Status
      dropWrite : out sl := '0';
      termFrame : out sl := '0';
      wrDone    : out sl := '0';
      rdDone    : out sl := '0';
      rdError   : out sl := '0';
      -- Clocks and Resets
      vcRxClk   : in  sl;
      vcRxRst   : in  sl;
      clk       : in  sl;
      rst       : in  sl);
end Vc64FifoTbSubModule;

architecture rtl of Vc64FifoTbSubModule is

   signal vcTxClk,
      vcTxRst,
      overflowDly,
      dropWriteDly,
      termFrameDly,
      vcRxDropWrite,
      vcRxTermFrame : sl := '0';
   signal vcRxData,
      vcTxData : Vc64DataType;
   signal vcRxCtrl,
      vcTxCtrl : Vc64CtrlType;
   signal rdCnt : slv(3 downto 0) := (others => '0');
   signal txData,
      rdData : slv(63 downto 0) := (others => '0');

begin

   dropWrite <= vcRxDropWrite;
   termFrame <= vcRxTermFrame;

   process(dropWriteDly, overflowDly, termFrameDly)
   begin
      if overflowDly = '1' then
         assert false
            report "FIFO overflow error detected!" severity failure;
      elsif dropWriteDly = '1' then
         assert false
            report "drop write error detected!" severity failure;
      elsif termFrameDly = '1' then
         assert false
            report "termination frame error detected!" severity failure;
      end if;
   end process;

   vcTxClk <= vcRxClk when(GEN_SYNC_FIFO_G = true) else clk;
   vcTxRst <= vcRxRst when(GEN_SYNC_FIFO_G = true) else rst;

   -- SynchronizerOneShot (VHDL module to be tested)
   Vc64Fifo_Inst : entity work.Vc64Fifo
      generic map (
         TPD_G           => TPD_G,
         PIPE_STAGES_G   => PIPE_STAGES_G,
         BRAM_EN_G       => BRAM_EN_G,
         GEN_SYNC_FIFO_G => GEN_SYNC_FIFO_G,
         USE_BUILT_IN_G  => USE_BUILT_IN_G)
      port map (
         -- RX Frame Filter Status (vcRxClk domain) 
         vcRxDropWrite => vcRxDropWrite,
         vcRxTermFrame => vcRxTermFrame,
         -- Streaming RX Data Interface (vcRxClk domain) 
         vcRxData      => vcRxData,
         vcRxCtrl      => vcRxCtrl,
         vcRxClk       => vcRxClk,
         vcRxRst       => vcRxRst,
         -- Streaming TX Data Interface (vcTxClk domain) 
         vcTxCtrl      => vcTxCtrl,
         vcTxData      => vcTxData,
         vcTxClk       => vcTxClk,
         vcTxRst       => vcTxRst);     

   -- Transmit the data pattern into the FIFO
   process(vcRxClk)
   begin
      if rising_edge(vcRxClk) then
         overflowDly    <= vcRxCtrl.overflow after TPD_G;
         dropWriteDly   <= vcRxDropWrite     after TPD_G;
         termFrameDly   <= vcRxTermFrame     after TPD_G;
         vcRxData.valid <= '0'               after TPD_G;
         vcRxData.sof   <= '0'               after TPD_G;
         vcRxData.eof   <= '0'               after TPD_G;
         if vcRxRst = '1' then
            wrDone   <= '0'              after TPD_G;
            txData   <= (others => '0')  after TPD_G;
            vcRxData <= VC64_DATA_INIT_C after TPD_G;
         elsif (txData /= LAST_DATA_G) and (vcRxCtrl.almostFull = '0') then
            -- Check for start of frame
            if txData = 0 then
               vcRxData.sof <= '1' after TPD_G;
            end if;
            -- Check for end of frame
            if txData = (LAST_DATA_G-1) then
               vcRxData.eof <= '1' after TPD_G;
            end if;
            -- Write the value to the FIFO
            vcRxData.valid <= '1'        after TPD_G;
            vcRxData.data  <= txData     after TPD_G;
            -- Increment the counter
            txData         <= txData + 1 after TPD_G;
         elsif txData = LAST_DATA_G then
            wrDone <= '1' after TPD_G;
         end if;
      end if;
   end process;

   -- Receive the data pattern into the FIFO and check if it is valid
   process(vcTxClk)
   begin
      if rising_edge(vcTxClk) then
         vcTxCtrl.ready      <= '0' after TPD_G;
         vcTxCtrl.almostFull <= '1' after TPD_G;
         if vcTxRst = '1' then
            rdDone   <= '0'              after TPD_G;
            rdError  <= '0'              after TPD_G;
            rdCnt    <= (others => '0')  after TPD_G;
            rdData   <= (others => '0')  after TPD_G;
            vcTxCtrl <= VC64_CTRL_INIT_C after TPD_G;
         else
            -- increment a counter
            rdCnt <= rdCnt + 1 after TPD_G;
            if rdCnt < READ_BUSY_THRES_G then
               -- Ready to read the FIFO
               vcTxCtrl.ready <= '1' after TPD_G;
            end if;
            if rdCnt < (READ_BUSY_THRES_G-1) then
               -- Ready to read the FIFO
               vcTxCtrl.almostFull <= '0' after TPD_G;
            end if;
            -- Check if we were reading the FIFO
            if (vcTxCtrl.ready = '1') and (vcTxData.valid = '1') then
               -- Check for an error in the data
               if vcTxData.data /= rdData then
                  -- Error detected
                  rdError <= '1' after TPD_G;
               end if;
               -- Check for roll over
               if rdData /= LAST_DATA_G then
                  -- increment the counter
                  rdData <= rdData + 1 after TPD_G;
               end if;
            elsif rdData = LAST_DATA_G then
               rdDone <= '1' after TPD_G;
            end if;
         end if;
      end if;
   end process;
   
end rtl;
