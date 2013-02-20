-------------------------------------------------------------------------------
-- Title      : Synchronizer Package
-------------------------------------------------------------------------------
-- File       : SynchronizePkg.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2012-04-30
-- Last update: 2013-02-15
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Defines a data type and functions that act on which simplify
-- the creation of dual flip flop synchronization structures. The data type
-- also has a third stage that can be used to detect edges.
-------------------------------------------------------------------------------
-- Copyright (c) 2012 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;
use work.StdRtlPkg.all;

package SynchronizePkg is

  type SynchronizerType is record
    tmp  : sl;
    sync : sl;
    last : sl;
  end record;

  type SynchronizerArray is array (natural range <>) of SynchronizerType;

  -- Constants for initializing a SynchronizerType
  constant SYNCHRONIZER_INIT_0_C : SynchronizerType := (tmp => '0', sync => '0', last => '0');
  constant SYNCHRONIZER_INIT_1_C : SynchronizerType := (tmp => '1', sync => '1', last => '1');

  procedure synchronize (
    input   : in  sl;
    current : in  SynchronizerType;
    nextOut : out SynchronizerType);

  procedure synchronize (
    var   : inout SynchronizerType;
    input : in    sl);

  procedure synchronize (
    input   : in  slv;
    current : in  SynchronizerArray;
    nextOut : out SynchronizerArray);

  procedure synchronize (
    var   : inout SynchronizerArray;
    input : in    slv);

  function toSlvSync (
    input : SynchronizerArray)
    return slv;

  function toSlvLast (
    input : SynchronizerArray)
    return slv;

  function detectRisingEdge (
    synchronizer : SynchronizerType)
    return boolean;

  function detectRisingEdge (
    synchronizers : SynchronizerArray)
    return boolean;

  function detectFallingEdge (
    synchronizer : SynchronizerType)
    return boolean;

  function detectFallingEdge (
    synchronizers : SynchronizerArray)
    return boolean;

  function detectEdge (
    synchronizer : SynchronizerType)
    return boolean;

  function detectEdge (
    synchronizers : SynchronizerArray)
    return boolean;

end package SynchronizePkg;

package body SynchronizePkg is

  procedure synchronize (
    input   : in  sl;
    current : in  SynchronizerType;
    nextOut : out SynchronizerType) is
  begin
    nextOut.tmp  := input;
    nextOut.sync := current.tmp;
    nextOut.last := current.sync;
  end procedure;

  -- Simplified. Can be used when v := r has already been called.
  procedure synchronize (
    var   : inout SynchronizerType;
    input : in    sl) is
  begin
    var.last := var.sync;
    var.sync := var.tmp;
    var.tmp  := input;
  end procedure synchronize;

  procedure synchronize (
    input   : in  slv;
    current : in  SynchronizerArray;
    nextOut : out SynchronizerArray) is
  begin
    for i in input'range loop
      synchronize(input(i), current(i), nextOut(i));
    end loop;
  end procedure;

  -- Simplified. Can be used when v := r has already been called.
  procedure synchronize (
    var   : inout SynchronizerArray;
    input : in    slv) is
  begin
    for i in input'range loop
      synchronize(var(i), input(i));
    end loop;
  end procedure synchronize;

  function toSlvSync (
    input : SynchronizerArray)
    return slv is
    variable retVar : slv(input'range);
  begin
    for i in retVar'range loop
      retVar(i) := input(i).sync;
    end loop;
    return retVar;
  end function;

  function toSlvLast (
    input : SynchronizerArray)
    return slv is
    variable retVar : slv(input'range);
  begin
    for i in retVar'range loop
      retVar(i) := input(i).last;
    end loop;
    return retVar;
  end function;
  
  function detectRisingEdge (
    synchronizer : SynchronizerType)
    return boolean is
  begin
    return synchronizer.sync = '1' and synchronizer.last = '0';
  end function;

  function detectRisingEdge (
    synchronizers : SynchronizerArray)
    return boolean is
    variable retVar : boolean := false;
  begin
    for i in synchronizers'range loop
      if (detectRisingEdge(synchronizers(i))) then
        retVar := true;
      end if;
    end loop;
    return retVar;
  end function;

  function detectFallingEdge (
    synchronizer : SynchronizerType)
    return boolean is
  begin
    return synchronizer.sync = '0' and synchronizer.last = '1';
  end function;

  function detectFallingEdge (
    synchronizers : SynchronizerArray)
    return boolean is
    variable retVar : boolean := false;
  begin
    for i in synchronizers'range loop
      if (detectFallingEdge(synchronizers(i))) then
        retVar := true;
      end if;
    end loop;
    return retVar;
  end function;
  
  function detectEdge (
    synchronizer : SynchronizerType)
    return boolean is
  begin
    return synchronizer.sync /= synchronizer.last;
  end function;

  function detectEdge (
    synchronizers : SynchronizerArray)
    return boolean is
    variable retVar : boolean := false;
  begin
    for i in synchronizers'range loop
      if (detectEdge(synchronizers(i))) then
        retVar := true;
      end if;
    end loop;
    return retVar;
  end function;
  
end package body SynchronizePkg;
