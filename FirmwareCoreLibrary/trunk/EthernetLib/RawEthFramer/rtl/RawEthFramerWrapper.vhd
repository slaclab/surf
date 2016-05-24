-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : RawEthFramerWrapper.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-05-23
-- Last update: 2016-05-24
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Ethernet Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Ethernet Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;

entity RawEthFramerWrapper is
   generic (
      TPD_G            : time             := 1 ns;
      EXT_CONFIG_G     : boolean          := false;
      REMOTE_SIZE_G    : positive         := 1;
      ETH_TYPE_G       : slv(15 downto 0) := x"0010";  --  0x1000 (big-Endian configuration)
      AXI_ERROR_RESP_G : slv(1 downto 0)  := AXI_RESP_DECERR_C);      
   port (
      -- Local Configurations
      localMac        : in  slv(47 downto 0);          --  big-Endian configuration
      remoteMac       : in  Slv48Array(REMOTE_SIZE_G-1 downto 0);  --  big-Endian configuration
      -- Interface to Ethernet Media Access Controller (MAC)
      obMacMaster     : in  AxiStreamMasterType;
      obMacSlave      : out AxiStreamSlaveType;
      ibMacMaster     : out AxiStreamMasterType;
      ibMacSlave      : in  AxiStreamSlaveType;
      -- Interface to Application engine(s)
      ibAppMasters    : out AxiStreamMasterArray(REMOTE_SIZE_G-1 downto 0);
      ibAppSlaves     : in  AxiStreamSlaveArray(REMOTE_SIZE_G-1 downto 0);
      obAppMasters    : in  AxiStreamMasterArray(REMOTE_SIZE_G-1 downto 0);
      obAppSlaves     : out AxiStreamSlaveArray(REMOTE_SIZE_G-1 downto 0);
      -- AXI-Lite Interface
      axilReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave  : out AxiLiteWriteSlaveType;
      -- Clock and Reset
      clk             : in  sl;
      rst             : in  sl);
end RawEthFramerWrapper;

architecture rtl of RawEthFramerWrapper is

   type RegType is record
      remoteMac      : Slv48Array(REMOTE_SIZE_G-1 downto 0);
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
   end record;

   constant REG_INIT_C : RegType := (
      remoteMac      => (others => (others => '0')),
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   ------------------
   -- IPv4/ARP Engine
   ------------------
   U_Core : entity work.RawEthFramer
      generic map (
         TPD_G         => TPD_G,
         REMOTE_SIZE_G => REMOTE_SIZE_G,
         ETH_TYPE_G    => ETH_TYPE_G) 
      port map (
         -- Local Configurations
         localMac     => localMac,
         remoteMac    => r.remoteMac,
         -- Interface to Ethernet Media Access Controller (MAC)
         obMacMaster  => obMacMaster,
         obMacSlave   => obMacSlave,
         ibMacMaster  => ibMacMaster,
         ibMacSlave   => ibMacSlave,
         -- Interface to Application engine(s)
         ibAppMasters => ibAppMasters,
         ibAppSlaves  => ibAppSlaves,
         obAppMasters => obAppMasters,
         obAppSlaves  => obAppSlaves,
         -- Clock and Reset
         clk          => clk,
         rst          => rst); 

   comb : process (axilReadMaster, axilWriteMaster, r, remoteMac, rst) is
      variable v      : RegType;
      variable regCon : AxiLiteEndPointType;
      variable i      : natural;
   begin
      -- Latch the current value
      v := r;

      -- Determine the transaction type
      axiSlaveWaitTxn(regCon, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);

      -- Map the read registers
      for i in REMOTE_SIZE_G-1 downto 0 loop
         axiSlaveRegister(regCon, toSlv(8*i+0, 8), 0, v.remoteMac(i)(31 downto 0));
         axiSlaveRegister(regCon, toSlv(8*i+4, 8), 0, v.remoteMac(i)(47 downto 32));
         axiSlaveRegisterR(regCon, toSlv(8*i+4, 8), 16, x"0000");
      end loop;
      axiSlaveRegisterR(regCon, x"FC", 0, toSlv(REMOTE_SIZE_G, 32));

      -- Closeout the transaction
      axiSlaveDefault(regCon, v.axilWriteSlave, v.axilReadSlave, AXI_ERROR_RESP_G);

      -- Synchronous Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Check for external configuration
      if (EXT_CONFIG_G = true) then
         v.remoteMac := remoteMac;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      axilWriteSlave <= r.axilWriteSlave;
      axilReadSlave  <= r.axilReadSlave;
      
   end process comb;

   seq : process (clk) is
   begin
      if (rising_edge(clk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;
   
end rtl;
