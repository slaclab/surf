-------------------------------------------------------------------------------
-- Title      : Single lane JESD AXI stream data receive control
-------------------------------------------------------------------------------
-- File       : AxiStreamLaneTx.vhd
-- Author     : Uros Legat  <ulegat@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-02
-- Last update: 2015-04-29
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:   This module receives the data on Virtual Channel Lane
--                and sends it to JESD TX lane.
--                When the rxAxisMaster_i.tvalid = '1'
--                the module sends data over JESD to DAC.
--                Otherwise it sends zero.
--                Note: The data reception is enabled only if JESD synchronisation is in data valid state dataReady_i='1'.
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

use work.Jesd204bPkg.all;

entity AxiStreamLaneTx is
   generic (
      -- General Configurations
      TPD_G   : time                        := 1 ns;
      F_G     : positive := 2
   );
   port (
   
      -- JESD devClk
      devClk_i          : in  sl;
      devRst_i          : in  sl;
      
      -- Axi Stream
      txAxisMaster_i  : in  AxiStreamMasterType;
      txAxisSlave_o   : out AxiStreamSlaveType;      
      
      -- JESD signals
      jesdReady_i     : in  sl;
      enable_i        : in  sl; 
      
      sampleData_o    : out slv((GT_WORD_SIZE_C*8)-1 downto 0)
   );
end AxiStreamLaneTx;

architecture rtl of AxiStreamLaneTx is

  
begin
   
   txAxisSlave_o.tReady <= jesdReady_i and enable_i;

   sampleData_o <= txAxisMaster_i.tData((GT_WORD_SIZE_C*8)-1 downto 0) when  (txAxisMaster_i.tValid = '1' and 
                                                                              jesdReady_i = '1'           and   
                                                                              enable_i = '1')                         
                                        else
                   outSampleZero(F_G,GT_WORD_SIZE_C);    
end rtl;
