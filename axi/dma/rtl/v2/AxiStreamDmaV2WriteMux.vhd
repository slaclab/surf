-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: This MUX is used to make sure that the write descriptor is sent
--              after the data is sent. Else the descriptor can get to the
--              software driver before the data received
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


library surf;
use surf.StdRtlPkg.all;
use surf.AxiPkg.all;

entity AxiStreamDmaV2WriteMux is
   generic (
      TPD_G          : time          := 1 ns;
      AXI_CONFIG_G   : AxiConfigType;
      AXI_READY_EN_G : boolean       := false);
   port (
      -- Clock and reset
      axiClk          : in  sl;
      axiRst          : in  sl;
      -- DMA Data Write Path
      dataWriteMaster : in  AxiWriteMasterType;
      dataWriteSlave  : out AxiWriteSlaveType;
      dataWriteCtrl   : out AxiCtrlType;
      -- DMA Descriptor Write Path
      descWriteMaster : in  AxiWriteMasterType;
      descWriteSlave  : out AxiWriteSlaveType;
      -- MUX Write Path
      mAxiWriteMaster : out AxiWriteMasterType;
      mAxiWriteSlave  : in  AxiWriteSlaveType;
      mAxiWriteCtrl   : in  AxiCtrlType);
end AxiStreamDmaV2WriteMux;

architecture rtl of AxiStreamDmaV2WriteMux is

   type StateType is (
      ADDR_S,
      DATA_S,
      DESC_S);

   type RegType is record
      pause      : sl;
      armed      : sl;
      descSlave  : AxiWriteSlaveType;
      dataSlave  : AxiWriteSlaveType;
      descriptor : AxiWriteMasterType;
      master     : AxiWriteMasterType;
      state      : StateType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      pause      => '0',
      armed      => '0',
      descSlave  => AXI_WRITE_SLAVE_INIT_C,
      dataSlave  => AXI_WRITE_SLAVE_INIT_C,
      descriptor => AXI_WRITE_MASTER_INIT_C,
      master     => AXI_WRITE_MASTER_INIT_C,
      state      => ADDR_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (axiRst, dataWriteMaster, descWriteMaster, mAxiWriteCtrl,
                   mAxiWriteSlave, r) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Valid/Ready Handshaking
      v.descSlave.awready := '0';
      v.descSlave.wready  := '0';

      v.dataSlave.awready := '0';
      v.dataSlave.wready  := '0';

      if (mAxiWriteSlave.awready = '1') or (AXI_READY_EN_G = false) then
         v.master.awvalid := '0';
      end if;

      if (mAxiWriteSlave.wready = '1') or (AXI_READY_EN_G = false) then
         v.master.wvalid := '0';
      end if;

      -- Check descriptor channel
      if (descWriteMaster.awvalid = '1') and (descWriteMaster.wvalid = '1') and (r.armed = '0') then
         -- Set the flag
         v.armed             := '1';
         -- ACK the valid (
         v.descSlave.awready := '1';
         v.descSlave.wready  := '1';
         -- Write address channel
         v.descriptor        := descWriteMaster;
      end if;

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when ADDR_S =>
            -- Reset the pause flag
            v.pause := '0';
            -- Check if ready to set the address
            if (v.master.awvalid = '0') then
               -- Check DMA channel
               if (dataWriteMaster.awvalid = '1') then
                  -- ACK the valid
                  v.dataSlave.awready := '1';
                  -- Write address channel
                  v.master.awvalid    := dataWriteMaster.awvalid;
                  v.master.awaddr     := dataWriteMaster.awaddr;
                  v.master.awid       := dataWriteMaster.awid;
                  v.master.awlen      := dataWriteMaster.awlen;
                  v.master.awsize     := dataWriteMaster.awsize;
                  v.master.awburst    := dataWriteMaster.awburst;
                  v.master.awlock     := dataWriteMaster.awlock;
                  v.master.awprot     := dataWriteMaster.awprot;
                  v.master.awcache    := dataWriteMaster.awcache;
                  v.master.awqos      := dataWriteMaster.awqos;
                  v.master.awregion   := dataWriteMaster.awregion;
                  -- Next state
                  v.state             := DATA_S;
               -- Check descriptor channel
               elsif (r.armed = '1') and (v.master.wvalid = '0') then
                  -- Reset the flag
                  v.armed  := '0';
                  -- Write address channel
                  v.master := r.descriptor;
                  -- Check for 64-bit AXI DMA interface
                  if (AXI_CONFIG_G.DATA_BYTES_C = 8) then
                     -- Configuration to two 64-bit cycles
                     v.master.wlast  := '0';  -- Mask off the wlast from single transaction
                     v.master.awlen  := toSlv(1, 8);  -- Double transaction
                     v.master.awsize := toSlv(log2(8), 3);  -- Update to 8B size
                     -- Set the pause flag
                     v.pause         := '1';
                     -- Next state
                     v.state         := DESC_S;
                  end if;

               end if;
            end if;
         ----------------------------------------------------------------------
         when DATA_S =>
            -- Check if ready to move data
            if (v.master.wvalid = '0') and (dataWriteMaster.wvalid = '1') then
               -- ACK the valid
               v.dataSlave.wready := '1';
               -- Write data channel
               v.master.wdata     := dataWriteMaster.wdata;
               v.master.wlast     := dataWriteMaster.wlast;
               v.master.wvalid    := dataWriteMaster.wvalid;
               v.master.wid       := dataWriteMaster.wid;
               v.master.wstrb     := dataWriteMaster.wstrb;
               -- Check for last transfer
               if (v.master.wlast = '1') then
                  -- Next state
                  v.state := ADDR_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when DESC_S =>
            -- Check if ready to move data
            if (v.master.wvalid = '0') then
               -- Write data channel
               v.master.wvalid             := '1';
               v.master.wlast              := '1';
               v.master.wdata(63 downto 0) := r.master.wdata(127 downto 64);
               -- Next state
               v.state                     := ADDR_S;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Descriptor Outputs
      descWriteSlave         <= r.descSlave;
      descWriteSlave.awready <= v.descSlave.awready;
      descWriteSlave.wready  <= v.descSlave.wready;

      -- Data Outputs
      dataWriteSlave         <= r.dataSlave;
      dataWriteSlave.awready <= v.dataSlave.awready;
      dataWriteSlave.wready  <= v.dataSlave.wready;
      dataWriteCtrl          <= mAxiWriteCtrl;
      dataWriteCtrl.pause    <= mAxiWriteCtrl.pause or v.pause;

      -- MUX Outputs
      mAxiWriteMaster        <= r.master;
      mAxiWriteMaster.bready <= '1';

      -- Reset
      if (axiRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (axiClk) is
   begin
      if (rising_edge(axiClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
