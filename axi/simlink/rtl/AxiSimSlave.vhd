-------------------------------------------------------------------------------
-- File       : AxiSimSlave.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-07-21
-- Last update: 2016-07-21
-------------------------------------------------------------------------------
-- Description: AXI Slave Simulation Module 
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

entity AxiSimSlave is port (
      axiClk         : in  std_logic;
      slaveId        : in  std_logic_vector(7  downto 0);
      arvalid        : in  std_logic;
      arready        : out std_logic;
      araddr         : in  std_logic_vector(31 downto 0);
      arid           : in  std_logic_vector(11 downto 0);
      arlen          : in  std_logic_vector(3  downto 0);
      arsize         : in  std_logic_vector(2  downto 0);
      arburst        : in  std_logic_vector(1  downto 0);
      arlock         : in  std_logic_vector(1  downto 0);
      arprot         : in  std_logic_vector(2  downto 0);
      arcache        : in  std_logic_vector(3  downto 0);
      rready         : in  std_logic;
      rdataH         : out std_logic_vector(31 downto 0);
      rdataL         : out std_logic_vector(31 downto 0);
      rlast          : out std_logic;
      rvalid         : out std_logic;
      rid            : out std_logic_vector(11 downto 0);
      rresp          : out std_logic_vector(1  downto 0);
      awvalid        : in  std_logic;
      awready        : out std_logic;
      awaddr         : in  std_logic_vector(31 downto 0);
      awid           : in  std_logic_vector(11 downto 0);
      awlen          : in  std_logic_vector(3  downto 0);
      awsize         : in  std_logic_vector(2  downto 0);
      awburst        : in  std_logic_vector(1  downto 0);
      awlock         : in  std_logic_vector(1  downto 0);
      awcache        : in  std_logic_vector(3  downto 0);
      awprot         : in  std_logic_vector(2  downto 0);
      wready         : out std_logic;
      wdataH         : in  std_logic_vector(31 downto 0);
      wdataL         : in  std_logic_vector(31 downto 0);
      wlast          : in  std_logic;
      wvalid         : in  std_logic;
      wid            : in  std_logic_vector(11 downto 0);
      wstrb          : in  std_logic_vector(7  downto 0);
      bready         : in  std_logic;
      bresp          : out std_logic_vector(1  downto 0);
      bvalid         : out std_logic;
      bid            : out std_logic_vector(11 downto 0)
   );
end AxiSimSlave;

-- Define architecture
architecture AxiSimSlave of AxiSimSlave is
   Attribute FOREIGN of AxiSimSlave: architecture is 
      "vhpi:AxiSim:VhpiGenericElab:AxiSimSlaveInit:AxiSimSlave";
begin
end AxiSimSlave;

