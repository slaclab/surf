-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : 
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2012-09-19
-- Last update: 2012-09-19
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- Copyright (c) 2012 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.StdRtlPkg.all;
use work.DsciMasterPkg.all;

package DsciMasterTbPkg is

  constant DSCI_MASTER_ZERO_C : DsciMasterInType := (req => '0',
                                                     reset => '0',
                                                     chip => (others => '0'),
                                                     op => '0',
                                                     cmd => (others => '0'),
                                                     addr => (others => '0'),
                                                     wrData => (others => '0'));

  procedure dsciWrite (
    signal dsciMasterIn  : out DsciMasterInType;
    signal dsciMasterOut : in  DsciMasterOutType;
    chip                 : in  slv(DSCI_CHIP_WIDTH_C-1 downto 0);
    cmd                  : in  slv(6 downto 0);
    addr                 : in  slv(11 downto 0);
    data                 : in  slv(31 downto 0));

  procedure dsciRead (
    signal dsciMasterIn  : out DsciMasterInType;
    signal dsciMasterOut : in  DsciMasterOutType;
    chip                 : in  slv(DSCI_CHIP_WIDTH_C-1 downto 0);
    cmd                  : in  slv(6 downto 0);
    addr                 : in  slv(11 downto 0);
    data                 : out slv(31 downto 0));

  procedure dsciReset (
    signal dsciMasterIn  : out DsciMasterInType;
    signal dsciMasterOut : in  DsciMasterOutType);

end package DsciMasterTbPkg;

package body DsciMasterTbPkg is

  procedure dsciWrite (
    signal dsciMasterIn  : out DsciMasterInType;
    signal dsciMasterOut : in  DsciMasterOutType;
    chip                 : in  slv(DSCI_CHIP_WIDTH_C-1 downto 0);
    cmd                  : in  slv(6 downto 0);
    addr                 : in  slv(11 downto 0);
    data                 : in  slv(31 downto 0)) is
  begin
    -- Present transaction request to master module
    dsciMasterIn.chip   <= chip;
    dsciMasterIn.cmd    <= cmd;
    dsciMasterIn.addr   <= addr;
    dsciMasterIn.wrData <= data;
    dsciMasterIn.op     <= DSCI_WRITE_C;
    dsciMasterIn.reset  <= '0';
    dsciMasterIn.req    <= '1';

    -- Wait for response
    wait until dsciMasterOut.ack = '1';

    -- Deassert request
    dsciMasterIn.req <= '0';

    -- Wait for ack to fall
    wait until dsciMasterOut.ack = '0';
    
  end procedure dsciWrite;

  procedure dsciRead (
    signal dsciMasterIn  : out DsciMasterInType;
    signal dsciMasterOut : in  DsciMasterOutType;
    chip                 : in  slv(DSCI_CHIP_WIDTH_C-1 downto 0);
    cmd                  : in  slv(6 downto 0);
    addr                 : in  slv(11 downto 0);
    data                 : out slv(31 downto 0)) is
  begin
    -- Present transaction request to master module
    dsciMasterIn.chip  <= chip;
    dsciMasterIn.cmd   <= cmd;
    dsciMasterIn.addr  <= addr;
    dsciMasterIn.op    <= DSCI_READ_C;
    dsciMasterIn.reset <= '0';
    dsciMasterIn.req   <= '1';

    -- Wait for response
    wait until dsciMasterOut.ack = '1';

    -- Deassert request
    dsciMasterIn.req <= '0';

    -- Capture data
    data := dsciMasterOut.rdData;

    -- Wait for ack to fall
    wait until dsciMasterOut.ack = '0';
    
  end procedure dsciRead;

  procedure dsciReset (
    signal dsciMasterIn  : out DsciMasterInType;
    signal dsciMasterOut : in  DsciMasterOutType)
  is
  begin
    dsciMasterIn.reset <= '1';
    wait until dsciMasterOut.ack = '1';
    dsciMasterIn.reset <= '0';
  end procedure dsciReset;

end package body DsciMasterTbPkg;

