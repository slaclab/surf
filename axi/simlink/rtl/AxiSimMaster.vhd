-------------------------------------------------------------------------------
-- File       : AxiSimMaster.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-07-21
-- Last update: 2016-07-21
-------------------------------------------------------------------------------
-- Description: AXI Master Simulation Module 
------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
------------------------------------------------------------------------------

LIBRARY ieee;
USE work.ALL;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity AxiSimMaster is port (
      axiClk         : in  std_logic;
      masterId       : in  std_logic_vector(7  downto 0);
      arvalid        : out std_logic;
      arready        : in  std_logic;
      araddr         : out std_logic_vector(31 downto 0);
      arid           : out std_logic_vector(11 downto 0);
      arlen          : out std_logic_vector(3  downto 0);
      arsize         : out std_logic_vector(2  downto 0);
      arburst        : out std_logic_vector(1  downto 0);
      arlock         : out std_logic_vector(1  downto 0);
      arprot         : out std_logic_vector(2  downto 0);
      arcache        : out std_logic_vector(3  downto 0);
      rready         : out std_logic;
      rdataH         : in  std_logic_vector(31 downto 0);
      rdataL         : in  std_logic_vector(31 downto 0);
      rlast          : in  std_logic;
      rvalid         : in  std_logic;
      rid            : in  std_logic_vector(11 downto 0);
      rresp          : in  std_logic_vector(1  downto 0);
      awvalid        : out std_logic;
      awready        : in  std_logic;
      awaddr         : out std_logic_vector(31 downto 0);
      awid           : out std_logic_vector(11 downto 0);
      awlen          : out std_logic_vector(3  downto 0);
      awsize         : out std_logic_vector(2  downto 0);
      awburst        : out std_logic_vector(1  downto 0);
      awlock         : out std_logic_vector(1  downto 0);
      awcache        : out std_logic_vector(3  downto 0);
      awprot         : out std_logic_vector(2  downto 0);
      wready         : in  std_logic;
      wdataH         : out std_logic_vector(31 downto 0);
      wdataL         : out std_logic_vector(31 downto 0);
      wlast          : out std_logic;
      wvalid         : out std_logic;
      wid            : out std_logic_vector(11 downto 0);
      wstrb          : out std_logic_vector(7  downto 0);
      bready         : out std_logic;
      bresp          : in  std_logic_vector(1  downto 0);
      bvalid         : in  std_logic;
      bid            : in  std_logic_vector(11 downto 0)
   );
end AxiSimMaster;

-- Define architecture
architecture AxiSimMaster of AxiSimMaster is
   Attribute FOREIGN of AxiSimMaster: architecture is 
      "vhpi:AxiSim:VhpiGenericElab:AxiSimMasterInit:AxiSimMaster";
begin
end AxiSimMaster;

