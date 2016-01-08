-------------------------------------------------------------------------------
-- Title         : AXI-4 DMA Controller Package File
-- File          : AxiDmaPkg.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 05/06/2013
-------------------------------------------------------------------------------
-- Description:
-- Package file for AXI DMA Controller
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
-- Modification history:
-- 05/06/2013: created.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;

package AxiDmaPkg is

   -------------------------------------
   -- Write DMA Request
   -------------------------------------

   -- Base Record
   type AxiWriteDmaReqType is record
      request : sl;
      drop    : sl;
      address : slv(31 downto 0);
      maxSize : slv(31 downto 0);
   end record;

   -- Initialization constants
   constant AXI_WRITE_DMA_REQ_INIT_C : AxiWriteDmaReqType := ( 
      request => '0',
      drop    => '0',
      address => (others=>'0'),
      maxSize => (others=>'0')
   );

   -- Array
   type AxiWriteDmaReqArray is array (natural range<>) of AxiWriteDmaReqType;

   -------------------------------------
   -- Write DMA Acknowledge
   -------------------------------------

   -- Base Record
   type AxiWriteDmaAckType is record
      done       : sl;
      size       : slv(31 downto 0);
      overflow   : sl;
      writeError : sl;
      errorValue : slv(1 downto 0);
      firstUser  : slv(7 downto 0);
      lastUser   : slv(7 downto 0);
      dest       : slv(7 downto 0);
      id         : slv(7 downto 0);
   end record;

   -- Initialization constants
   constant AXI_WRITE_DMA_ACK_INIT_C : AxiWriteDmaAckType := ( 
      done       => '0',
      size       => (others=>'0'),
      overflow   => '0',
      writeError => '0',
      errorValue => "00",
      firstUser  => (others=>'0'),
      lastUser   => (others=>'0'),
      dest       => (others=>'0'),
      id         => (others=>'0')
   );

   -- Array
   type AxiWriteDmaAckArray is array (natural range<>) of AxiWriteDmaAckType;

   -------------------------------------
   -- Read DMA Request
   -------------------------------------

   -- Base Record
   type AxiReadDmaReqType is record
      request   : sl;
      address   : slv(31 downto 0);
      size      : slv(31 downto 0);
      firstUser : slv(7 downto 0);
      lastUser  : slv(7 downto 0);
      dest      : slv(7 downto 0);
      id        : slv(7 downto 0);
   end record;

   -- Initialization constants
   constant AXI_READ_DMA_REQ_INIT_C : AxiReadDmaReqType := ( 
      request   => '0',
      address   => (others=>'0'),
      size      => (others=>'0'),
      firstUser => (others=>'0'),
      lastUser  => (others=>'0'),
      dest      => (others=>'0'),
      id        => (others=>'0')
   );

   -- Array
   type AxiReadDmaReqArray is array (natural range<>) of AxiReadDmaReqType;

   -------------------------------------
   -- Read DMA Acknowledge
   -------------------------------------

   -- Base Record
   type AxiReadDmaAckType is record
      done       : sl;
      readError  : sl;
      errorValue : slv(1 downto 0);
   end record;

   -- Initialization constants
   constant AXI_READ_DMA_ACK_INIT_C : AxiReadDmaAckType := ( 
      done       => '0',
      readError  => '0',
      errorValue => "00"
   );

   -- Array
   type AxiReadDmaAckArray is array (natural range<>) of AxiReadDmaAckType;

end AxiDmaPkg;

