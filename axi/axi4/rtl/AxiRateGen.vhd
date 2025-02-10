-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: General Purpose AXI4 memory rate generator
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
use surf.AxiLitePkg.all;
use surf.AxiPkg.all;

entity AxiRateGen is
   generic (
      TPD_G        : time    := 1 ns;
      COMMON_CLK_G : boolean := false;
      AXI_CONFIG_G : AxiConfigType);
   port (
      -- AXI4 Memory Interface
      axiClk           : in  sl;
      axiRst           : in  sl;
      axiWriteMaster   : out AxiWriteMasterType;
      axiWriteSlave    : in  AxiWriteSlaveType;
      axiReadMaster    : out AxiReadMasterType;
      axiReadSlave     : in  AxiReadSlaveType;
      -- AXI-Lite Interface
      axilClk          : in  sl;
      axilRst          : in  sl;
      sAxilReadMaster  : in  AxiLiteReadMasterType;
      sAxilReadSlave   : out AxiLiteReadSlaveType;
      sAxilWriteMaster : in  AxiLiteWriteMasterType;
      sAxilWriteSlave  : out AxiLiteWriteSlaveType);
end AxiRateGen;

architecture rtl of AxiRateGen is

   type WrStateType is (
      WRITE_ADDR_S,
      WRITE_DATA_S,
      WRITE_RESP_S);

   type RdStateType is (
      READ_ADDR_S,
      READ_DATA_S);

   type RegType is record
      wrState        : WrStateType;
      rdState        : RdStateType;
      awlen          : slv(7 downto 0);
      writeSize      : slv(11 downto 0);
      wrTimer        : slv(31 downto 0);
      rdTimer        : slv(31 downto 0);
      -- Registers
      wrEnable       : sl;
      rdEnable       : sl;
      wrSize         : slv(11 downto 0);
      rdSize         : slv(11 downto 0);
      wrPeriod       : slv(31 downto 0);
      rdPeriod       : slv(31 downto 0);
      awburst        : slv(1 downto 0);
      awcache        : slv(3 downto 0);
      arburst        : slv(1 downto 0);
      arcache        : slv(3 downto 0);
      -- AXI4
      axiWriteMaster : AxiWriteMasterType;
      axiReadMaster  : AxiReadMasterType;
      -- AXI-Lite
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
   end record;

   constant REG_INIT_C : RegType := (
      wrState        => WRITE_ADDR_S,
      rdState        => READ_ADDR_S,
      awlen          => x"00",
      writeSize      => x"FFF",
      wrTimer        => x"0000_0000",
      rdTimer        => x"0000_0000",
      -- Registers
      wrEnable       => '0',
      rdEnable       => '0',
      wrSize         => x"FFF",
      rdSize         => x"FFF",
      wrPeriod       => x"0000_FFFF",
      rdPeriod       => x"0000_FFFF",
      awburst        => "01",
      awcache        => "1111",
      arburst        => "01",
      arcache        => "1111",
      -- AXI4
      axiWriteMaster => axiWriteMasterInit(AXI_CONFIG_G),
      axiReadMaster  => axiReadMasterInit(AXI_CONFIG_G),
      -- AXI-Lite
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal axilReadMaster  : AxiLiteReadMasterType;
   signal axilReadSlave   : AxiLiteReadSlaveType;
   signal axilWriteMaster : AxiLiteWriteMasterType;
   signal axilWriteSlave  : AxiLiteWriteSlaveType;

begin

   U_AxiLiteAsync : entity surf.AxiLiteAsync
      generic map (
         TPD_G           => TPD_G,
         COMMON_CLK_G    => COMMON_CLK_G,
         NUM_ADDR_BITS_G => 8)
      port map (
         -- Slave Interface
         sAxiClk         => axilClk,
         sAxiClkRst      => axilRst,
         sAxiReadMaster  => sAxilReadMaster,
         sAxiReadSlave   => sAxilReadSlave,
         sAxiWriteMaster => sAxilWriteMaster,
         sAxiWriteSlave  => sAxilWriteSlave,
         -- Master Interface
         mAxiClk         => axiClk,
         mAxiClkRst      => axiRst,
         mAxiReadMaster  => axilReadMaster,
         mAxiReadSlave   => axilReadSlave,
         mAxiWriteMaster => axilWriteMaster,
         mAxiWriteSlave  => axilWriteSlave);

   comb : process (axiReadSlave, axiRst, axiWriteSlave, axilReadMaster,
                   axilWriteMaster, r) is
      variable v      : RegType;
      variable axilEp : AxiLiteEndpointType;
   begin
      -- Latch the current value
      v := r;

      ----------------------------------------------------------------------
      -- AXI-Lite Transactions
      ----------------------------------------------------------------------

      -- Determine the transaction type
      axiSlaveWaitTxn(axilEp, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);

      axiSlaveRegister(axilEp, x"00", 0, v.wrEnable);
      axiSlaveRegister(axilEp, x"04", 0, v.rdEnable);

      axiSlaveRegister(axilEp, x"10", 0, v.wrSize);
      axiSlaveRegister(axilEp, x"14", 0, v.rdSize);

      axiSlaveRegister(axilEp, x"20", 0, v.wrPeriod);
      axiSlaveRegister(axilEp, x"24", 0, v.rdPeriod);

      axiSlaveRegister(axilEp, x"30", 0, v.awburst);
      axiSlaveRegister(axilEp, x"34", 0, v.arburst);

      axiSlaveRegister(axilEp, x"40", 0, v.awcache);
      axiSlaveRegister(axilEp, x"44", 0, v.arcache);

      axiSlaveRegisterR(axilEp, x"80", 0, toSlv(AXI_CONFIG_G.ADDR_WIDTH_C, 8));
      axiSlaveRegisterR(axilEp, x"80", 8, toSlv(AXI_CONFIG_G.DATA_BYTES_C, 8));
      axiSlaveRegisterR(axilEp, x"80", 16, toSlv(AXI_CONFIG_G.ID_BITS_C, 8));
      axiSlaveRegisterR(axilEp, x"80", 24, toSlv(AXI_CONFIG_G.LEN_BITS_C, 8));

      -- Close the transaction
      axiSlaveDefault(axilEp, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_DECERR_C);

      ----------------------------------------------------------------------

      -- Write Timer
      if (r.wrPeriod /= v.wrPeriod) then
         -- Reset the timer
         v.wrTimer := (others => '0');
      elsif (r.wrTimer /= 0) then
         -- Decrement the counter
         v.wrTimer := r.wrTimer - 1;
      end if;

      -- Write AXI Flow Control
      v.axiWriteMaster.bready := '0';
      if axiWriteSlave.awready = '1' then
         v.axiWriteMaster.awvalid := '0';
      end if;
      if axiWriteSlave.wready = '1' then
         v.axiWriteMaster.wvalid := '0';
         v.axiWriteMaster.wlast  := '0';
      end if;

      -- State Machine
      case (r.wrState) is
         ----------------------------------------------------------------------
         when WRITE_ADDR_S =>
            -- Check if enabled and timeout
            if (r.wrEnable = '1') and (r.wrTimer = 0) and (v.axiWriteMaster.awvalid = '0') then

               -- Arm the timer
               v.wrTimer := r.wrPeriod;

               -- Latch the write size
               v.writeSize := r.wrSize;

               -- Write Address channel
               v.axiWriteMaster.awvalid := '1';
               v.axiWriteMaster.awsize  := toSlv(log2(AXI_CONFIG_G.DATA_BYTES_C), 3);
               v.axiWriteMaster.awlen   := getAxiLen(AXI_CONFIG_G, conv_integer(r.wrSize)+1);
               v.awlen                  := getAxiLen(AXI_CONFIG_G, conv_integer(r.wrSize)+1);
               v.axiWriteMaster.awaddr  := r.axiWriteMaster.awaddr + 4096;  -- 4kB address alignment
               v.axiWriteMaster.awburst := r.awburst;
               v.axiWriteMaster.awcache := r.awcache;

               -- Next State
               v.wrState := WRITE_DATA_S;

            end if;
         ----------------------------------------------------------------------
         when WRITE_DATA_S =>
            -- Check if ready to move write data
            if (v.axiWriteMaster.wvalid = '0') then

               -- Write Data channel
               v.axiWriteMaster.wvalid := '1';
               v.axiWriteMaster.wstrb  := (others => '1');

               -- Decrement the counters
               v.awlen     := r.awlen - 1;
               v.writeSize := r.writeSize - AXI_CONFIG_G.DATA_BYTES_C;

               -- Check for last write
               if (r.awlen = 0) then

                  -- Terminate the frame
                  v.axiWriteMaster.wlast := '1';

                  -- Update the WSTRB
                  if (r.writeSize < AXI_CONFIG_G.DATA_BYTES_C) then
                     v.axiWriteMaster.wstrb                                     := (others => '0');
                     v.axiWriteMaster.wstrb(conv_integer(r.writeSize) downto 0) := (others => '1');
                  end if;

                  -- Next State
                  v.wrState := WRITE_RESP_S;

               end if;

            end if;
         ----------------------------------------------------------------------
         when WRITE_RESP_S =>
            -- Wait for the response
            if axiWriteSlave.bvalid = '1' then

               -- Accept the response
               v.axiWriteMaster.bready := '1';

               -- Next State
               v.wrState := WRITE_ADDR_S;

            end if;
      ----------------------------------------------------------------------
      end case;

      ----------------------------------------------------------------------

      -- Read Timer
      if (r.rdPeriod /= v.rdPeriod) then
         -- Reset the timer
         v.rdTimer := (others => '0');
      elsif (r.rdTimer /= 0) then
         -- Decrement the counter
         v.rdTimer := r.rdTimer - 1;
      end if;

      -- Read AXI Flow Control
      v.axiReadMaster.rready := '0';
      if axiReadSlave.arready = '1' then
         v.axiReadMaster.arvalid := '0';
      end if;

      -- State Machine
      case (r.rdState) is
         ----------------------------------------------------------------------
         when READ_ADDR_S =>
            -- Check if enabled and timeout
            if (r.rdEnable = '1') and (r.rdTimer = 0) and (v.axiReadMaster.arvalid = '0') then

               -- Arm the timer
               v.rdTimer := r.rdPeriod;

               -- Write Address channel
               v.axiReadMaster.arvalid := '1';
               v.axiReadMaster.arsize  := toSlv(log2(AXI_CONFIG_G.DATA_BYTES_C), 3);
               v.axiReadMaster.arlen   := getAxiLen(AXI_CONFIG_G, conv_integer(r.rdSize)+1);
               v.axiReadMaster.araddr  := r.axiReadMaster.araddr + 4096;  -- 4kB address alignment
               v.axiReadMaster.arburst := r.arburst;
               v.axiReadMaster.arcache := r.arcache;

               -- Next State
               v.rdState := READ_DATA_S;

            end if;
         ----------------------------------------------------------------------
         when READ_DATA_S =>
            -- Check for new data
            if (axiReadSlave.rvalid = '1') then

               -- Accept the data
               v.axiReadMaster.rready := '1';

               -- Check for last transfer
               if axiReadSlave.rlast = '1' then

                  -- Next State
                  v.rdState := READ_ADDR_S;

               end if;

            end if;
      ----------------------------------------------------------------------
      end case;

      -- AXI-Lite Outputs
      axilReadSlave  <= r.axilReadSlave;
      axilWriteSlave <= r.axilWriteSlave;

      -- AXI4 Write Outputs
      axiWriteMaster        <= r.axiWriteMaster;
      axiWriteMaster.bready <= v.axiWriteMaster.bready;

      -- AXI4 Read Outputs
      axiReadMaster        <= r.axiReadMaster;
      axiReadMaster.rready <= v.axiReadMaster.rready;

      -- Reset
      if axiRst = '1' then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (axiClk) is
   begin
      if rising_edge(axiClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
