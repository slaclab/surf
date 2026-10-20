-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Block to resize AXI. Re-sizing is always little endian.
--
-- When upsizing reads (slave data width narrower than master data width) the
-- slice bounds of every accepted read request are queued so the response
-- slicer returns exactly ARLEN+1 slave beats and places RLAST on the final
-- one. Responses are matched to requests in acceptance order, so read data
-- must return in request order across IDs. The queue holds 2**RD_QUEUE_AWIDTH_G
-- requests and the slave ARREADY is held off while it is full.
--
-- Disclaimer: This module doesn't support the following:
--             Narrow write transfers
--             Unaligned transfers (the read upsizing path accepts a start
--             address aligned to the slave data width; every other path
--             requires alignment to the wider data width)
--             Read response reordering across IDs when upsizing reads
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;


library surf;
use surf.StdRtlPkg.all;
use surf.AxiPkg.all;

entity AxiResize is
   generic (
      -- General Configurations
      TPD_G               : time := 1 ns;
      -- AXI Stream Port Configurations
      SLAVE_AXI_CONFIG_G  : AxiConfigType;
      MASTER_AXI_CONFIG_G : AxiConfigType;
      -- Outstanding read request queue depth (read upsizing only)
      RD_QUEUE_AWIDTH_G   : positive range 4 to 48 := 4);
   port (
      -- Clock and reset
      axiClk          : in  sl;
      axiRst          : in  sl;
      -- Slave Port
      sAxiReadMaster  : in  AxiReadMasterType;
      sAxiReadSlave   : out AxiReadSlaveType;
      sAxiWriteMaster : in  AxiWriteMasterType;
      sAxiWriteSlave  : out AxiWriteSlaveType;
      -- Master Port
      mAxiReadMaster  : out AxiReadMasterType;
      mAxiReadSlave   : in  AxiReadSlaveType;
      mAxiWriteMaster : out AxiWriteMasterType;
      mAxiWriteSlave  : in  AxiWriteSlaveType);
end AxiResize;

architecture rtl of AxiResize is

   constant SLV_BYTES_C : integer := SLAVE_AXI_CONFIG_G.DATA_BYTES_C;
   constant MST_BYTES_C : integer := MASTER_AXI_CONFIG_G.DATA_BYTES_C;
   constant MAX_BYTES_C : integer := maximum(SLV_BYTES_C, MST_BYTES_C);
   constant COUNT_C     : integer := ite(SLV_BYTES_C > MST_BYTES_C, SLV_BYTES_C / MST_BYTES_C, MST_BYTES_C / SLV_BYTES_C);
   constant BIT_CNT_C   : integer := bitSize(COUNT_C);
   constant SHIFT_C     : integer := log2(COUNT_C);
   constant SLV_SHIFT_C : integer := log2(SLV_BYTES_C);

   -- Read request queue entry: first slave slice of the burst (from ARADDR)
   -- in the low half, last slave slice of the final master beat in the high half
   constant RD_QUEUE_WIDTH_C : integer := maximum(2*SHIFT_C, 1);

   type RegType is record
      rdCount   : slv(BIT_CNT_C-1 downto 0);
      rdInBurst : sl;
      rdQueueWr : sl;
      rdQueueRd : sl;
      rdHold    : AxiReadSlaveType;
      rdMaster  : AxiReadMasterType;
      rdSlave   : AxiReadSlaveType;
      wrCount   : slv(BIT_CNT_C-1 downto 0);
      wrMaster  : AxiWriteMasterType;
      wrSlave   : AxiWriteSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      rdCount   => (others => '0'),
      rdInBurst => '0',
      rdQueueWr => '0',
      rdQueueRd => '0',
      rdHold    => AXI_READ_SLAVE_INIT_C,
      rdMaster  => axiReadMasterInit(MASTER_AXI_CONFIG_G),
      rdSlave   => AXI_READ_SLAVE_INIT_C,
      wrCount   => (others => '0'),
      wrMaster  => axiWriteMasterInit(MASTER_AXI_CONFIG_G),
      wrSlave   => AXI_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal rdQueueWr    : sl;
   signal rdQueueRd    : sl;
   signal rdQueueDin   : slv(RD_QUEUE_WIDTH_C-1 downto 0);
   signal rdQueueDout  : slv(RD_QUEUE_WIDTH_C-1 downto 0);
   signal rdQueueValid : sl;
   signal rdQueueFull  : sl;

begin

   -- Make sure data widths are appropriate.
   assert ((SLV_BYTES_C >= MST_BYTES_C and SLV_BYTES_C mod MST_BYTES_C = 0) or
           (MST_BYTES_C >= SLV_BYTES_C and MST_BYTES_C mod SLV_BYTES_C = 0))
      report "Data widths must be even number multiples of each other" severity failure;

   GEN_RESIZE : if (SLV_BYTES_C /= MST_BYTES_C) generate

      comb : process (axiRst, mAxiReadSlave, mAxiWriteSlave, r, rdQueueDout,
                      rdQueueFull, rdQueueValid, sAxiReadMaster,
                      sAxiWriteMaster) is
         variable v         : RegType;
         variable ibRdM     : AxiReadSlaveType;
         variable ibWrM     : AxiWriteMasterType;
         variable rdIdx     : integer;  -- index version of counter
         variable wrIdx     : integer;  -- index version of counter
         variable rdFirst   : integer;  -- first slave slice of a read burst
         variable rdTotal   : integer;  -- rdFirst plus ARLEN
         variable rdStart   : integer;  -- first slice of the accepted master beat
         variable rdLast    : integer;  -- last slice of the current master beat
         variable wrByteCnt : integer;  -- Number of valid bytes in incoming bus
         variable wrBytes   : integer;  -- byte version of counter
         variable arlen     : slv(7 downto 0);
         variable awlen     : slv(7 downto 0);
         variable queueDin  : slv(RD_QUEUE_WIDTH_C-1 downto 0);
      begin
         -- Latch the current value
         v := r;

         ----------------------------------------------------------------------
         --                AXI Read Resizing Logic                           --
         ----------------------------------------------------------------------

         -- Update the indexes
         rdIdx := conv_integer(r.rdCount);

         -- Initialize the ready and queue strobes
         v.rdMaster.rready := '0';
         v.rdQueueWr       := '0';
         v.rdQueueRd       := '0';

         -- Valid/Ready Handshaking for the data channel
         if (sAxiReadMaster.rready = '1') then
            v.rdSlave.rvalid := '0';
         end if;

         -- Inbound data
         ibRdM := mAxiReadSlave;

         -- Pipeline advance
         if (v.rdSlave.rvalid = '0') then

            -- Increasing size
            if SLV_BYTES_C > MST_BYTES_C then
               -- Accept the data
               v.rdMaster.rready := '1';

               -- Initialize when rdCount = 0
               if (r.rdCount = 0) then
                  v.rdSlave := AXI_READ_SLAVE_INIT_C;
               end if;

               v.rdSlave.rdata((MST_BYTES_C*8*rdIdx)+((MST_BYTES_C*8)-1) downto (MST_BYTES_C*8*rdIdx)) := ibRdM.rdata((MST_BYTES_C*8)-1 downto 0);

               v.rdSlave.rid   := ibRdM.rid;
               v.rdSlave.rresp := ibRdM.rresp;
               v.rdSlave.rlast := ibRdM.rlast;

               -- Determine if we move data
               if (ibRdM.rvalid = '1') then
                  if r.rdCount = (COUNT_C-1) or ibRdM.rlast = '1' then
                     v.rdSlave.rvalid := '1';
                     v.rdCount        := (others => '0');
                  else
                     v.rdCount := r.rdCount + 1;
                  end if;
               end if;

            -- Decreasing size
            else

               v.rdSlave := AXI_READ_SLAVE_INIT_C;

               -- The queue head describes the burst being returned: its first
               -- slave slice (from ARADDR) and the last slave slice of its
               -- final master beat (from ARADDR plus ARLEN). Hold off the
               -- master beat until the entry is visible.
               if (r.rdHold.rvalid = '0') then

                  if (rdQueueValid = '1') then
                     v.rdMaster.rready := '1';
                  end if;

                  if (ibRdM.rvalid = '1') and (rdQueueValid = '1') then

                     -- The first master beat of a burst starts at the ARADDR
                     -- slice, later master beats start at slice 0
                     rdStart := 0;
                     if (r.rdInBurst = '0') then
                        rdStart := conv_integer(rdQueueDout(SHIFT_C-1 downto 0));
                     end if;

                     -- The final master beat of a burst stops at the ARLEN
                     -- slice, earlier master beats deliver every slice
                     rdLast := COUNT_C-1;
                     if (ibRdM.rlast = '1') then
                        rdLast := conv_integer(rdQueueDout((2*SHIFT_C)-1 downto SHIFT_C));
                     end if;

                     -- Buffer the accepted wide master beat so later narrow
                     -- slave slices do not depend on the live master-side bus
                     -- after the current handshake completes.
                     v.rdHold                                   := AXI_READ_SLAVE_INIT_C;
                     v.rdHold.rdata((MST_BYTES_C*8)-1 downto 0) := ibRdM.rdata((MST_BYTES_C*8)-1 downto 0);
                     v.rdHold.rid                               := ibRdM.rid;
                     v.rdHold.rresp                             := ibRdM.rresp;
                     v.rdHold.rlast                             := ibRdM.rlast;
                     v.rdHold.rvalid                            := '1';
                     v.rdInBurst                                := '1';

                     -- Queue the first slice immediately while retaining the
                     -- full beat so the remaining narrow slices can drain from
                     -- rdHold without an extra bubble.
                     v.rdSlave.rdata((SLV_BYTES_C*8)-1 downto 0) := ibRdM.rdata((SLV_BYTES_C*8*rdStart)+((SLV_BYTES_C*8)-1) downto (SLV_BYTES_C*8*rdStart));
                     v.rdSlave.rid                               := ibRdM.rid;
                     v.rdSlave.rresp                             := ibRdM.rresp;
                     v.rdSlave.rvalid                            := '1';

                     if (rdStart = rdLast) then
                        -- This master beat contributes a single slice
                        v.rdHold.rvalid := '0';
                        v.rdSlave.rlast := ibRdM.rlast;
                        v.rdCount       := (others => '0');
                        if (ibRdM.rlast = '1') then
                           v.rdQueueRd := '1';
                           v.rdInBurst := '0';
                        end if;
                     else
                        v.rdSlave.rlast := '0';
                        v.rdCount       := toSlv(rdStart+1, v.rdCount'length);
                     end if;

                  end if;

               else

                  rdLast := COUNT_C-1;
                  if (r.rdHold.rlast = '1') then
                     rdLast := conv_integer(rdQueueDout((2*SHIFT_C)-1 downto SHIFT_C));
                  end if;

                  v.rdSlave.rdata((SLV_BYTES_C*8)-1 downto 0) := r.rdHold.rdata((SLV_BYTES_C*8*rdIdx)+((SLV_BYTES_C*8)-1) downto (SLV_BYTES_C*8*rdIdx));
                  v.rdSlave.rid                               := r.rdHold.rid;
                  v.rdSlave.rresp                             := r.rdHold.rresp;
                  v.rdSlave.rvalid                            := '1';

                  if (rdIdx = rdLast) then
                     v.rdCount       := (others => '0');
                     v.rdHold.rvalid := '0';
                     v.rdSlave.rlast := r.rdHold.rlast;
                     if (r.rdHold.rlast = '1') then
                        v.rdQueueRd := '1';
                        v.rdInBurst := '0';
                     end if;
                  else
                     v.rdCount       := r.rdCount + 1;
                     v.rdSlave.rlast := '0';
                  end if;

               end if;

            end if;
         end if;

         -- Pass the read request through while the queue has room for its
         -- slice bounds (rdQueueFull is tied low unless upsizing reads)
         v.rdMaster.arvalid := sAxiReadMaster.arvalid and not rdQueueFull;
         v.rdSlave.arready  := mAxiReadSlave.arready and not rdQueueFull;
         v.rdQueueWr        := v.rdMaster.arvalid and v.rdSlave.arready;

         rdFirst  := 0;
         rdTotal  := 0;
         queueDin := (others => '0');
         if MST_BYTES_C > SLV_BYTES_C then
            -- Count the burst in slave slices from the start of its first
            -- master beat: ARADDR selects the first slice and ARLEN more
            -- slices follow, which sets both the master ARLEN and the slice
            -- bounds queued for the response path
            rdFirst  := conv_integer(sAxiReadMaster.araddr(SHIFT_C+SLV_SHIFT_C-1 downto SLV_SHIFT_C));
            rdTotal  := rdFirst + conv_integer(sAxiReadMaster.arlen);
            arlen    := toSlv(rdTotal/COUNT_C, 8);
            queueDin := toSlv(rdTotal mod COUNT_C, SHIFT_C) & toSlv(rdFirst, SHIFT_C);
         else
            arlen(7 downto SHIFT_C)   := sAxiReadMaster.arlen(7-SHIFT_C downto 0);
            arlen(SHIFT_C-1 downto 0) := (others => '1');
         end if;

         ---------------------------
         -- mAxiReadMaster's Outputs
         ---------------------------
         -- Read Address channel
         mAxiReadMaster.arvalid  <= v.rdMaster.arvalid;
         mAxiReadMaster.araddr   <= sAxiReadMaster.araddr;
         mAxiReadMaster.arid     <= sAxiReadMaster.arid;
         mAxiReadMaster.arlen    <= arlen;
         mAxiReadMaster.arsize   <= toSlv(log2(MASTER_AXI_CONFIG_G.DATA_BYTES_C), 3);
         mAxiReadMaster.arburst  <= sAxiReadMaster.arburst;
         mAxiReadMaster.arlock   <= sAxiReadMaster.arlock;
         mAxiReadMaster.arprot   <= sAxiReadMaster.arprot;
         mAxiReadMaster.arcache  <= sAxiReadMaster.arcache;
         mAxiReadMaster.arqos    <= sAxiReadMaster.arqos;
         mAxiReadMaster.arregion <= sAxiReadMaster.arregion;
         -- Read data channel
         mAxiReadMaster.rready   <= v.rdMaster.rready;

         --------------------------
         -- sAxiReadSlave's Outputs
         --------------------------
         -- Read Address channel
         sAxiReadSlave.arready <= v.rdSlave.arready;
         -- Read data channel
         sAxiReadSlave.rdata   <= r.rdSlave.rdata;
         sAxiReadSlave.rlast   <= r.rdSlave.rlast;
         sAxiReadSlave.rvalid  <= r.rdSlave.rvalid;
         sAxiReadSlave.rid     <= r.rdSlave.rid;
         sAxiReadSlave.rresp   <= r.rdSlave.rresp;

         ---------------------
         -- Read request queue
         ---------------------
         rdQueueWr  <= v.rdQueueWr;
         rdQueueRd  <= v.rdQueueRd;
         rdQueueDin <= queueDin;

         ----------------------------------------------------------------------
         --                AXI Write Resizing Logic                          --
         ----------------------------------------------------------------------

         -- Update the indexes
         wrIdx := conv_integer(r.wrCount);

         -- Update the number of bytes
         wrBytes := (wrIdx+1) * MST_BYTES_C;

         -- Update the byte counter pointer
         wrByteCnt := conv_integer(onesCount(sAxiWriteMaster.wstrb(SLV_BYTES_C-1 downto 0)));

         -- Initialize the ready signal
         v.wrSlave.wready := '0';

         -- Valid/Ready Handshaking for the data channel
         if (mAxiWriteSlave.wready = '1') then
            v.wrMaster.wvalid := '0';
         end if;

         -- Inbound data
         ibWrM := sAxiWriteMaster;

         -- Pipeline advance
         if (v.wrMaster.wvalid = '0') then

            -- Increasing size
            if MST_BYTES_C > SLV_BYTES_C then
               -- Accept the data
               v.wrSlave.wready := '1';

               -- Initialize when wrCount = 0
               if (r.wrCount = 0) then
                  v.wrMaster       := axiWriteMasterInit(MASTER_AXI_CONFIG_G);
                  v.wrMaster.wstrb := (others => '0');
               end if;

               v.wrMaster.wdata((SLV_BYTES_C*8*wrIdx)+((SLV_BYTES_C*8)-1) downto (SLV_BYTES_C*8*wrIdx)) := ibWrM.wdata((SLV_BYTES_C*8)-1 downto 0);
               v.wrMaster.wstrb((SLV_BYTES_C*wrIdx)+(SLV_BYTES_C-1) downto (SLV_BYTES_C*wrIdx))         := ibWrM.wstrb(SLV_BYTES_C-1 downto 0);

               v.wrMaster.wid   := ibWrM.wid;  --- The WID signal is implemented only in AXI3
               v.wrMaster.wlast := ibWrM.wlast;

               -- Determine if we move data
               if (ibWrM.wvalid = '1') then
                  if r.wrCount = (COUNT_C-1) or ibWrM.wlast = '1' then
                     v.wrMaster.wvalid := '1';
                     v.wrCount         := (others => '0');
                  else
                     v.wrCount := r.wrCount + 1;
                  end if;
               end if;

            -- Decreasing size
            else

               v.wrMaster := axiWriteMasterInit(MASTER_AXI_CONFIG_G);

               v.wrMaster.wdata((MST_BYTES_C*8)-1 downto 0) := ibWrM.wdata((MST_BYTES_C*8*wrIdx)+((MST_BYTES_C*8)-1) downto (MST_BYTES_C*8*wrIdx));
               v.wrMaster.wstrb(MST_BYTES_C-1 downto 0)     := ibWrM.wstrb((MST_BYTES_C*wrIdx)+(MST_BYTES_C-1) downto (MST_BYTES_C*wrIdx));

               v.wrMaster.wid := ibWrM.wid;  -- The WID signal is implemented only in AXI3

               -- Determine if we move data
               if (ibWrM.wvalid = '1') then
                  if (r.wrCount = (COUNT_C-1)) or ((wrBytes >= wrByteCnt) and (ibWrM.wlast = '1')) then
                     v.wrCount        := (others => '0');
                     v.wrSlave.wready := '1';
                     v.wrMaster.wlast := ibWrM.wlast;
                  else
                     v.wrCount        := r.wrCount + 1;
                     v.wrSlave.wready := '0';
                     v.wrMaster.wlast := '0';
                  end if;
               end if;

               -- Drop transfers with no wstrb bits set, except on wlast
               v.wrMaster.wvalid := ibWrM.wvalid and (uOr(v.wrMaster.wstrb(COUNT_C-1 downto 0)) or v.wrMaster.wlast);

            end if;
         end if;

         if MST_BYTES_C > SLV_BYTES_C then
            awlen(7 downto 7-SHIFT_C+1) := (others => '0');
            awlen(7-SHIFT_C downto 0)   := sAxiWriteMaster.awlen(7 downto SHIFT_C);
         else
            awlen(7 downto SHIFT_C)   := sAxiWriteMaster.awlen(7-SHIFT_C downto 0);
            awlen(SHIFT_C-1 downto 0) := (others => '1');
         end if;

         ----------------------------
         -- mAxiWriteMaster's Outputs
         ----------------------------
         -- Write address channel
         mAxiWriteMaster.awvalid  <= sAxiWriteMaster.awvalid;
         mAxiWriteMaster.awaddr   <= sAxiWriteMaster.awaddr;
         mAxiWriteMaster.awid     <= sAxiWriteMaster.awid;
         mAxiWriteMaster.awlen    <= awlen;
         mAxiWriteMaster.awsize   <= toSlv(log2(MASTER_AXI_CONFIG_G.DATA_BYTES_C), 3);
         mAxiWriteMaster.awburst  <= sAxiWriteMaster.awburst;
         mAxiWriteMaster.awlock   <= sAxiWriteMaster.awlock;
         mAxiWriteMaster.awprot   <= sAxiWriteMaster.awprot;
         mAxiWriteMaster.awcache  <= sAxiWriteMaster.awcache;
         mAxiWriteMaster.awqos    <= sAxiWriteMaster.awqos;
         mAxiWriteMaster.awregion <= sAxiWriteMaster.awregion;
         -- Write data channel
         mAxiWriteMaster.wdata    <= r.wrMaster.wdata;
         mAxiWriteMaster.wlast    <= r.wrMaster.wlast;
         mAxiWriteMaster.wvalid   <= r.wrMaster.wvalid;
         mAxiWriteMaster.wid      <= r.wrMaster.wid;
         mAxiWriteMaster.wstrb    <= r.wrMaster.wstrb;
         -- Write ack channel
         mAxiWriteMaster.bready   <= sAxiWriteMaster.bready;

         --------------------------
         -- sAxiWriteSlave's Outputs
         --------------------------
         -- Write address channel
         sAxiWriteSlave.awready <= mAxiWriteSlave.awready;
         -- Write data channel
         sAxiWriteSlave.wready  <= v.wrSlave.wready;
         -- Write ack channel
         sAxiWriteSlave.bresp   <= mAxiWriteSlave.bresp;
         sAxiWriteSlave.bvalid  <= mAxiWriteSlave.bvalid;
         sAxiWriteSlave.bid     <= mAxiWriteSlave.bid;

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

      GEN_RD_QUEUE : if (MST_BYTES_C > SLV_BYTES_C) generate
         U_RdQueue : entity surf.Fifo
            generic map (
               TPD_G           => TPD_G,
               GEN_SYNC_FIFO_G => true,
               FWFT_EN_G       => true,
               SYNTH_MODE_G    => "inferred",
               MEMORY_TYPE_G   => "distributed",
               DATA_WIDTH_G    => RD_QUEUE_WIDTH_C,
               ADDR_WIDTH_G    => RD_QUEUE_AWIDTH_G)
            port map (
               rst    => axiRst,
               wr_clk => axiClk,
               wr_en  => rdQueueWr,
               din    => rdQueueDin,
               full   => rdQueueFull,
               rd_clk => axiClk,
               rd_en  => rdQueueRd,
               dout   => rdQueueDout,
               valid  => rdQueueValid);
      end generate;

      BYP_RD_QUEUE : if (MST_BYTES_C < SLV_BYTES_C) generate
         rdQueueFull  <= '0';
         rdQueueValid <= '1';
         rdQueueDout  <= (others => '0');
      end generate;

   end generate;

   BYP_RESIZE : if (SLV_BYTES_C = MST_BYTES_C) generate
      mAxiReadMaster  <= sAxiReadMaster;
      sAxiReadSlave   <= mAxiReadSlave;
      mAxiWriteMaster <= sAxiWriteMaster;
      sAxiWriteSlave  <= mAxiWriteSlave;
   end generate;

end rtl;
