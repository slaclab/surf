-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: General AXI RAM Module
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

entity AxiRam is
   generic (
      TPD_G          : time                 := 1 ns;
      SYNTH_MODE_G   : string               := "inferred";
      MEMORY_TYPE_G  : string               := "block";
      READ_LATENCY_G : natural range 0 to 2 := 2;
      AXI_CONFIG_G   : AxiConfigType);
   port (
      -- Clock and Reset
      axiClk          : in  sl;
      axiRst          : in  sl;
      -- Slave Write Interface
      sAxiWriteMaster : in  AxiWriteMasterType;
      sAxiWriteSlave  : out AxiWriteSlaveType;
      -- Slave Read Interface
      sAxiReadMaster  : in  AxiReadMasterType;
      sAxiReadSlave   : out AxiReadSlaveType);
end AxiRam;

architecture structure of AxiRam is

   constant DATA_BYTES_C : positive := AXI_CONFIG_G.DATA_BYTES_C;
   constant DATA_WIDTH_C : positive := 8*DATA_BYTES_C;
   constant OFFSET_C     : positive := ite(DATA_BYTES_C = 1, 0, log2(DATA_BYTES_C));
   constant ADDR_WIDTH_C : positive := AXI_CONFIG_G.ADDR_WIDTH_C-OFFSET_C;

   type WrStateType is (
      WR_ADDR_S,
      WR_DATA_S,
      WR_BLOWOFF_S);

   type RdStateType is (
      RD_ADDR_S,
      RD_PIPELINE_S,
      RD_DATA_S);

   type RegType is record
      -- Write Signals
      wrData         : slv(DATA_WIDTH_C-1 downto 0);
      wrAddr         : slv(ADDR_WIDTH_C-1 downto 0);
      wstrb          : slv(DATA_BYTES_C-1 downto 0);
      wid            : slv(31 downto 0);
      awlen          : slv(7 downto 0);
      sAxiWriteSlave : AxiWriteSlaveType;
      wrState        : WrStateType;
      -- Read Signals
      rdAddr         : slv(ADDR_WIDTH_C-1 downto 0);
      rid            : slv(31 downto 0);
      arlen          : slv(7 downto 0);
      sAxiReadSlave  : AxiReadSlaveType;
      rdEn           : slv(1 downto 0);
      rdLat          : slv(1 downto 0);
      rdState        : RdStateType;
   end record;

   constant REG_INIT_C : RegType := (
      -- Write Signals
      wrData         => (others => '0'),
      wrAddr         => (others => '0'),
      wstrb          => (others => '0'),
      wid            => (others => '0'),
      awlen          => (others => '0'),
      sAxiWriteSlave => AXI_WRITE_SLAVE_INIT_C,
      wrState        => WR_ADDR_S,
      -- Read Signals
      rdAddr         => (others => '0'),
      rid            => (others => '0'),
      arlen          => (others => '0'),
      sAxiReadSlave  => AXI_READ_SLAVE_INIT_C,
      rdEn           => (others => '0'),
      rdLat          => (others => '0'),
      rdState        => RD_ADDR_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;


   signal wrEn   : sl;
   signal wrData : slv(DATA_WIDTH_C-1 downto 0);
   signal wrAddr : slv(ADDR_WIDTH_C-1 downto 0);
   signal wstrb  : slv(DATA_BYTES_C-1 downto 0);

   signal rdEn   : slv(1 downto 0);
   signal rdData : slv(DATA_WIDTH_C-1 downto 0);
   signal rdAddr : slv(ADDR_WIDTH_C-1 downto 0);

begin

   assert (SYNTH_MODE_G /= "inferred") or
      ((SYNTH_MODE_G = "inferred") and (READ_LATENCY_G > 0))
      report "AxiRam: Inferred SimpleDualPortRam does not support zero latency reads" severity failure;

   GEN_XPM : if (SYNTH_MODE_G = "xpm") generate
      U_RAM : entity surf.SimpleDualPortRamXpm
         generic map (
            TPD_G          => TPD_G,
            COMMON_CLK_G   => true,
            MEMORY_TYPE_G  => MEMORY_TYPE_G,
            READ_LATENCY_G => READ_LATENCY_G,
            DATA_WIDTH_G   => DATA_WIDTH_C,
            BYTE_WR_EN_G   => true,
            BYTE_WIDTH_G   => 8,
            ADDR_WIDTH_G   => ADDR_WIDTH_C)
         port map (
            -- Port A
            ena    => wrEn,
            clka   => axiClk,
            addra  => wrAddr,
            dina   => wrData,
            wea    => wstrb,
            -- Read Interface
            enb    => rdEn(0),
            clkb   => axiClk,
            addrb  => rdAddr,
            doutb  => rdData,
            regceb => rdEn(1));
   end generate;

   GEN_ALTERA : if (SYNTH_MODE_G = "altera_mf") generate
      U_RAM : entity surf.SimpleDualPortRamAlteraMf
         generic map (
            TPD_G          => TPD_G,
            COMMON_CLK_G   => true,
            MEMORY_TYPE_G  => MEMORY_TYPE_G,
            READ_LATENCY_G => READ_LATENCY_G,
            DATA_WIDTH_G   => DATA_WIDTH_C,
            BYTE_WR_EN_G   => true,
            BYTE_WIDTH_G   => 8,
            ADDR_WIDTH_G   => ADDR_WIDTH_C)
         port map (
            -- Port A
            ena    => wrEn,
            clka   => axiClk,
            addra  => wrAddr,
            dina   => wrData,
            wea    => wstrb,
            -- Read Interface
            enb    => rdEn(0),
            clkb   => axiClk,
            addrb  => rdAddr,
            doutb  => rdData,
            regceb => rdEn(1));
   end generate;

   GEN_INFERRED : if (SYNTH_MODE_G = "inferred") generate
      U_RAM : entity surf.SimpleDualPortRam
         generic map (
            TPD_G         => TPD_G,
            MEMORY_TYPE_G => MEMORY_TYPE_G,
            DOB_REG_G     => ite(READ_LATENCY_G = 2, true, false),
            BYTE_WR_EN_G  => true,
            DATA_WIDTH_G  => DATA_WIDTH_C,
            BYTE_WIDTH_G  => 8,
            ADDR_WIDTH_G  => ADDR_WIDTH_C)
         port map (
            -- Port A
            ena     => wrEn,
            clka    => axiClk,
            addra   => wrAddr,
            dina    => wrData,
            weaByte => wstrb,
            -- Read Interface
            enb     => rdEn(0),
            clkb    => axiClk,
            addrb   => rdAddr,
            doutb   => rdData,
            regceb  => rdEn(1));
   end generate;

   comb : process (axiRst, r, rdData, sAxiReadMaster, sAxiWriteMaster) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      ----------------------------------------------------------------------
      --                      AXI Write Logic                             --
      ----------------------------------------------------------------------

      -- Reset the strobes
      v.wstrb                  := (others => '0');
      v.sAxiWriteSlave.awready := '0';
      v.sAxiWriteSlave.wready  := '0';
      if (sAxiWriteMaster.bready = '1') then
         v.sAxiWriteSlave.bvalid := '0';
      end if;

      -- Write State Machine
      case (r.wrState) is
         ----------------------------------------------------------------------
         when WR_ADDR_S =>
            -- Wait for the Address transaction
            if (sAxiWriteMaster.awvalid = '1') then
               -- Accept the transaction
               v.sAxiWriteSlave.awready := '1';
               -- Slave the channel ID
               v.wid                    := sAxiWriteMaster.awid;
               -- Save the address
               v.wrAddr                 := sAxiWriteMaster.awaddr((ADDR_WIDTH_C-1)+OFFSET_C downto OFFSET_C);
               -- Pre-decrement (registered output)
               v.wrAddr                 := v.wrAddr - 1;
               -- latch the length
               v.awlen                  := sAxiWriteMaster.awlen;
               -- Next State
               v.wrState                := WR_DATA_S;
            end if;
         ----------------------------------------------------------------------
         when WR_DATA_S =>
            -- Check if ready to move data
            if (sAxiWriteMaster.wvalid = '1') and (r.sAxiWriteSlave.bvalid = '0') then
               -- Accept the data
               v.sAxiWriteSlave.wready := '1';
               -- Increment the address
               v.wrAddr                := r.wrAddr + 1;
               -- Write the data to RAM
               v.wstrb                 := sAxiWriteMaster.wstrb(DATA_BYTES_C-1 downto 0);
               v.wrData                := sAxiWriteMaster.wdata(DATA_WIDTH_C-1 downto 0);
               -- Decrement the counter
               v.awlen                 := r.awlen - 1;
               -- Check for last transfer
               if (sAxiWriteMaster.wlast = '1') or (r.awlen = 0) then
                  v.sAxiWriteSlave.bvalid := '1';
                  v.sAxiWriteSlave.bid    := r.wid;
                  -- Check alignment
                  if (sAxiWriteMaster.wlast = '1') and (r.awlen = 0) then
                     -- Access OK
                     v.sAxiWriteSlave.bresp := "00";
                     -- Next State
                     v.wrState              := WR_ADDR_S;
                  else
                     -- Slave Error
                     v.sAxiWriteSlave.bresp := "10";
                     -- Check for last transfer
                     if (sAxiWriteMaster.wlast = '1') then
                        -- Next State
                        v.wrState := WR_ADDR_S;
                     else
                        -- Next State
                        v.wrState := WR_BLOWOFF_S;
                     end if;
                  end if;
               end if;
            end if;
         ----------------------------------------------------------------------
         when WR_BLOWOFF_S =>
            -- Blow off the data
            v.sAxiWriteSlave.wready := '1';
            -- Check for last transfer
            if (sAxiWriteMaster.wvalid = '1') and (sAxiWriteMaster.wlast = '1') then
               -- Next State
               v.wrState := WR_ADDR_S;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Outputs
      wrEn   <= uOr(r.wstrb);
      wstrb  <= r.wstrb;
      wrAddr <= r.wrAddr;
      wrData <= r.wrData;

      --------------------------
      -- sAxiWriteSlave's Outputs
      --------------------------
      -- Write address channel
      sAxiWriteSlave.awready <= v.sAxiWriteSlave.awready;
      -- Write data channel
      sAxiWriteSlave.wready  <= v.sAxiWriteSlave.wready;
      -- Write ack channel
      sAxiWriteSlave.bresp   <= r.sAxiWriteSlave.bresp;
      sAxiWriteSlave.bvalid  <= r.sAxiWriteSlave.bvalid;
      sAxiWriteSlave.bid     <= r.sAxiWriteSlave.bid;

      ----------------------------------------------------------------------
      --                      AXI Read Logic                              --
      ----------------------------------------------------------------------

      -- Reset the strobes
      v.sAxiReadSlave.arready := '0';
      if (sAxiReadMaster.rready = '1') then
         v.sAxiReadSlave.rvalid := '0';
         v.sAxiReadSlave.rlast  := '0';
      end if;

      -- Write State Machine
      case (r.rdState) is
         ----------------------------------------------------------------------
         when RD_ADDR_S =>
            -- Wait for the Address transaction
            if (sAxiReadMaster.arvalid = '1') then
               -- Accept the transaction
               v.sAxiReadSlave.arready := '1';
               -- Slave the channel ID
               v.rid                   := sAxiReadMaster.arid;
               -- Save the address
               v.rdAddr                := sAxiReadMaster.araddr((ADDR_WIDTH_C-1)+OFFSET_C downto OFFSET_C);
               -- Enable RAM reads
               v.rdEn                  := "11";
               -- latch the length
               v.arlen                 := sAxiReadMaster.arlen;
               -- Check the read latency
               if (READ_LATENCY_G = 0) then
                  -- Next State
                  v.rdState := RD_DATA_S;
               else
                  -- Next State
                  v.rdState := RD_PIPELINE_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when RD_PIPELINE_S =>
            -- Enable RAM reads
            v.rdEn   := "11";
            -- Increment the address
            v.rdAddr := r.rdAddr + 1;
            -- Check if RAM pipeline is filled
            if (r.rdLat = READ_LATENCY_G-1) then
               -- Reset the counter
               v.rdLat   := (others => '0');
               -- Next State
               v.rdState := RD_DATA_S;
            else
               -- Increment the counter
               v.rdLat := r.rdLat + 1;
            end if;
         ----------------------------------------------------------------------
         when RD_DATA_S =>
            --  Hold the pipeline
            v.rdEn := "00";
            -- Check if ready to move data
            if (v.sAxiReadSlave.rvalid = '0') then
               -- Accept the data from the rate
               v.rdEn                                         := "11";
               -- Forward the data
               v.sAxiReadSlave.rvalid                         := '1';
               v.sAxiReadSlave.rdata(DATA_WIDTH_C-1 downto 0) := rdData;
               v.sAxiReadSlave.rid                            := r.rid;
               -- Increment the address
               v.rdAddr                                       := r.rdAddr + 1;
               -- Decrement the counter
               v.arlen                                        := r.arlen - 1;
               -- Check for last transfer
               if (r.arlen = 0) then
                  -- Set the last transfer flag
                  v.sAxiReadSlave.rlast := '1';
                  -- Next State
                  v.rdState             := RD_ADDR_S;
               end if;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Outputs
      rdAddr <= r.rdAddr;
      if (READ_LATENCY_G = 0) then
         rdEn <= "11";
      else
         rdEn <= v.rdEn;
      end if;

      --------------------------
      -- sAxiReadSlave's Outputs
      --------------------------
      -- Read Address channel
      sAxiReadSlave.arready <= v.sAxiReadSlave.arready;
      -- Read data channel
      sAxiReadSlave.rdata   <= r.sAxiReadSlave.rdata;
      sAxiReadSlave.rlast   <= r.sAxiReadSlave.rlast;
      sAxiReadSlave.rvalid  <= r.sAxiReadSlave.rvalid;
      sAxiReadSlave.rid     <= r.sAxiReadSlave.rid;
      sAxiReadSlave.rresp   <= r.sAxiReadSlave.rresp;

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

end structure;
