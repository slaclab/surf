-------------------------------------------------------------------------------
-- Title         : VC64 Lib, Simulation Link
-- Project       : General Purpose Core
-------------------------------------------------------------------------------
-- File          : SimLink.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 04/18/2014
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- Copyright (c) 2014 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 04/18/2014: created.
-------------------------------------------------------------------------------

LIBRARY ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.StdRtlPkg.all;
use work.Vc64Pkg.all;

entity SimLink is 
   generic (
      TPD_G             : time                    := 1 ns;
      VC_WIDTH_G        : integer range 16 to 64  := 16;   -- Bits: 8, 16, 32 or 64
      VC_COUNT_G        : integer range 1  to 16  := 4;
      LITTLE_ENDIAN_G   : boolean                 := true
   );
   port ( 

      -- Inbound VC Interface, interleave not supported
      -- Ready is always '1'
      ibVcClk         : in  sl;
      ibVcClkRst      : in  sl;
      ibVcData        : in  Vc64DataType;
      ibVcCtrl        : out Vc64CtrlType;

      -- Outbound VC Interface, ready is used for handshake
      obVcClk         : in  sl;
      obVcClkRst      : in  sl;
      obVcData        : out Vc64DataType;
      obVcCtrl        : in  Vc64CtrlArray(VC_COUNT_G-1 downto 0)
   );

begin
   assert (VC_WIDTH_G = 8 or VC_WIDTH_G = 16 or VC_WIDTH_G = 32 or VC_WIDTH_G = 64 ) 
      report "VC_WIDTH_G must not be = 8, 16, 32 or 64" severity failure;
end SimLink;


-- Define architecture
architecture SimLink of SimLink is

   -- Local Signals
   signal littleEndian : std_logic;
   signal vcWidth      : std_logic_vector(6 downto 0)
   signal obReady      : std_logic_vector(15 downto 0);

begin

   -- Convert generics
   littleEndian <= ite(LITTLE_ENDIAN_G,'1','0');
   vcWidth      <= slv(VC_WIDTH_G,7);

   -- Outbound flow control, overflow ignored, 
   -- transmit occurs when ready = '1' and overflow = '0'
   process ( intVcCtrl ) begin
      obReady <= (others=>'0');

      for i in 0 VC_COUNT_G-1 loop
         obReady(i) <= ibVcCtrl(i).ready and (not ibVcCtrl(i).almostFull);
      end loop;
   end process;

   -- Outbound (data into simulation software)
   U_SimLinkOb: entity work.SimLinkOb
      port map (
         obClk            => obVcClk,
         obReset          => obVcClkRst,
         obDataValid      => obVcData.valid,
         obDataSize       => obVcData.size,
         obDataVc         => obVcData.vc,
         obDataSof        => obVcData.sof,
         obDataEof        => obVcData.eof,
         obDataEofe       => obVcData.eofe,
         obDataDataHigh   => obVcData.data(63 downto 32),
         obDataDataLow    => obVcData.data(31 downto  0),
         obReady          => obReady,
         littleEndian     => littleEndian,
         vcWidth          => vcWidth
      );

   -- Inbound (data into simulation software)
   U_SimLinkIb: entity work.SimLinkIb
      port map (
         ibClk            => ibVcClk,
         ibReset          => ibVcClkRst,
         ibDataValid      => ibVcData.valid,
         ibDataSize       => ibVcData.size,
         ibDataVc         => ibVcData.vc,
         ibDataSof        => ibVcData.sof,
         ibDataEof        => ibVcData.eof,
         ibDataEofe       => ibVcData.eofe,
         ibDataDataHigh   => ibVcData.data(63 downto 32),
         ibDataDataLow    => ibVcData.data(31 downto  0),
         littleEndian     => littleEndian,
         vcWidth          => vcWidth
      );

   -- Init flow control, always ready
   ibVcCtrl <= VC64_CTRL_FORCE_C when ibVcClkRst = '0' else VC64_CTRL_INIT_C;

end SimLink;

