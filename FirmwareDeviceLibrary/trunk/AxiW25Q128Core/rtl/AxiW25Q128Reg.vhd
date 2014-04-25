-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AxiW25Q128Reg.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-25
-- Last update: 2014-04-25
-- Platform   : Vivado 2013.3
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiW25Q128Pkg.all;


entity AxiW25Q128Reg is
   generic (
      TPD_G                 : time            := 1 ns;
      FORCE_ADDR_MSB_HIGH_G : boolean         := false;  -- Set true to prevent any operation in the lower half of the address space
      BRAM_EN_G             : boolean         := false;
      AXI_CLK_FREQ_G        : real            := 200.0E+6;  -- units of Hz
      SPI_CLK_FREQ_G        : real            := 50.0E+6;   -- units of Hz
      AXI_ERROR_RESP_G      : slv(1 downto 0) := AXI_RESP_SLVERR_C);  
   port (
      -- FLASH Memory Ports
      csL            : out sl;
      sck            : out sl;
      din            : in  slv(3 downto 0);
      dout           : out slv(3 downto 0);
      oeL            : out slv(3 downto 0);
      -- AXI-Lite Register Interface (axiClk domain)
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;
      -- Register Inputs/Outputs (axiClk domain)
      status         : in  AxiW25Q128StatusType;
      config         : out AxiW25Q128ConfigType;
      -- Global Signals
      axiClk         : in  sl;
      axiRst         : in  sl);
end AxiW25Q128Reg;

architecture rtl of AxiW25Q128Reg is

   constant DOUBLE_SCK_FREQ_C : real    := getRealMult(SPI_CLK_FREQ_G, 2.0E+0);
   constant SCK_HALF_PERIOD_C : natural := (getTimeRatio(AXI_CLK_FREQ_G, DOUBLE_SCK_FREQ_C))-1;
   
   type StateType is (
      IDLE_S,
      LATENCY_WAIT_S,
      SCK_LOW_S,
      SCK_HIGH_S,
      CS_HIGH_S);  

   type RegType is record
      wrWen         : sl;
      rdWen         : sl;
      bytePtnr      : slv(1 downto 0);
      bitPntr       : slv(2 downto 0);
      wrAddr        : slv(6 downto 0);
      rdAddr        : slv(6 downto 0);
      shiftReg      : slv(7 downto 0);
      xferSize      : slv(8 downto 0);
      byteCnt       : slv(8 downto 0);
      wrDin         : slv(31 downto 0);
      rdDin         : slv(31 downto 0);
      sckCnt        : natural range 0 to SCK_HALF_PERIOD_C;
      dout          : slv(3 downto 0);
      oeL           : slv(3 downto 0);
      state         : StateType;
      axiReadSlave  : AxiLiteReadSlaveType;
      axiWriteSlave : AxiLiteWriteSlaveType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      '0',
      '0',
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      0,
      x"F",
      x"1",
      IDLE_S,
      AXI_LITE_READ_SLAVE_INIT_C,
      AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal sdi,
      sdo : sl;
   signal wrDout,
      rdDout : slv(31 downto 0) := (others => '0');
   signal wrBtye,
      rdBtye : Slv8Array(0 to 3) := (others => (others => '0'));
   
begin

   ----------------------------------------------------------------
   -- Note:
   --    In SPI mode:
   --       sdio[0] = sdi
   --       sdio[1] = sdo
   --       sdio[2] = wpL
   --       sdio[3] = holdL or rstL
   --
   --    In DSPI mode:
   --       sdio[0] = IO[0]
   --       sdio[1] = IO[1]
   --       sdio[2] = wpL
   --       sdio[3] = holdL or rstL
   --
   --    In QSPI mode:
   --       sdio[0] = IO[0]
   --       sdio[1] = IO[1]
   --       sdio[2] = IO[2]
   --       sdio[3] = IO[3]  
   ----------------------------------------------------------------
   -- Note: This module doesn't support DSPI or QSPI interface yet.
   ----------------------------------------------------------------

   -------------------------------
   -- Configuration Register
   -------------------------------  
   comb : process (axiReadMaster, axiRst, axiWriteMaster, din, r, rdDout, wrBtye, wrDout) is
      variable v            : RegType;
      variable axiStatus    : AxiLiteStatusType;
      variable axiWriteResp : slv(1 downto 0);
      variable axiReadResp  : slv(1 downto 0);
   begin
      -- Latch the current value
      v := r;

      -- Determine the transaction type
      axiSlaveWaitTxn(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiStatus);

      -- Reset strobe signals
      v.wrWen := '0';
      v.rdWen := '0';

      if (axiStatus.writeEnable = '1') and (r.state = IDLE_S) then
         -- Check for an out of 32 bit aligned address
         if axiWriteMaster.awaddr(1 downto 0) /= "00" then
            -- Send AXI response
            axiSlaveWriteResponse(v.axiWriteSlave, AXI_ERROR_RESP_G);
         -- Check for a write buffer to RAM access
         elsif axiWriteMaster.awaddr(9) = '1' then
            v.bufSel := '1';            -- Write Buffer selected         
            v.wrWen  := '1';
            v.wrAddr := axiWriteMaster.awaddr(8 downto 2);
            v.wrDin  := axiWriteMaster.wdata;
            -- Send AXI response
            axiSlaveWriteResponse(v.axiWriteSlave);
         elsif axiWriteMaster.awaddr(9 downto 2) = x"00" then
            -- Latch the SPI transfer size
            v.xferSize := axiWriteMaster.wdata(8 downto 0);  -- transfer size is in units of bytes minus one   
            -- Reset all counters and control signals
            v.cs       := '0';
            v.sckCnt   := 0;
            v.bitPntr  := (others => '0');
            v.bytePtnr := (others => '0');
            v.byteCnt  := (others => '0');
            v.wrAddr   := (others => '0');
            v.rdAddr   := (others => '0');
            -- Next state
            state      := LATENCY_WAIT_S;
         else
            -- Send AXI response
            axiSlaveWriteResponse(v.axiWriteSlave, AXI_ERROR_RESP_G);
         end if;
      elsif (axiStatus.readEnable = '1') and (r.state = IDLE_S) then
         -- Reset the read bus
         v.axiReadSlave.rdata := (others => '0');
         -- Check for an out of 32 bit aligned address
         if axiReadMaster.araddr(1 downto 0) /= "00" then
            -- Send AXI response
            axiSlaveReadResponse(v.axiReadSlave, AXI_ERROR_RESP_G);
         else
            v.bufSel := axiWriteMaster.awaddr(9);
            v.wrAddr := axiReadMaster.araddr(8 downto 2);
            v.rdAddr := axiReadMaster.araddr(8 downto 2);
            -- Next state
            state    := LATENCY_WAIT_S;
         end if;
      end if;

      -- State Machine
      case (r.state) is
         ----------------------------------------------------------------------
         when IDLE_S =>
            v.csL  := '1';
            v.sck  := '0';
            v.dout := x"F";
            v.oeL  := x"1";
         ----------------------------------------------------------------------
         when LATENCY_WAIT_S =>
            -- Increment the counter
            v.sckCnt := r.sckCnt + 1;
            if r.sckCnt = 1 then
               -- Reset the counter
               v.sckCnt := 0;
               -- Check if this is a serialization or RAM transaction
               if r.csL = '0' then
                  -- Next State
                  v.state := SCK_LOW_S;
               else
                  -- Determine which buffer was being pulled
                  if r.bufSel = '0' then
                     v.axiReadSlave.rdata := rdDout;
                  else
                     v.axiReadSlave.rdata := wrDout;
                  end if;
                  -- Send AXI Response
                  axiSlaveReadResponse(v.axiReadSlave);
                  -- Next State
                  v.state := IDLE_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when SCK_LOW_S =>
            -- Serial Clock low phase
            v.sck := '0';
            -- Check for address MSB bit
            if (r.byteCnt = 1) and (r.bitPntr = 0) and (FORCE_ADDR_MSB_HIGH_G = true) then
               v.dout(0) := '1';  -- Prevent any operation in the lower half of the address space!!!!
            else
               v.dout(0) := wrBtye(conv_integer(r.bytePtnr))(conv_integer(7-r.bitPntr));
            end if;
            -- Increment the counter
            v.sckCnt := r.sckCnt + 1;
            -- Check the counter value
            if r.sckCnt = SCK_HALF_PERIOD_C then
               -- Reset the counter
               v.sckCnt := 0;
               -- Next state
               v.state  := SCK_HIGH_S;
            end if;
         ----------------------------------------------------------------------
         when SCK_HIGH_S =>
            -- Serial Clock high phase
            v.sck    := '1';
            -- Increment the counter
            v.sckCnt := r.sckCnt + 1;
            -- Check the counter value
            if r.sckCnt = SCK_HALF_PERIOD_C then
               -- Reset the counter
               v.sckCnt               := 0;
               -- Shifter Register
               v.shiftReg(0)          := din(1);
               v.shiftReg(7 downto 1) := r.shiftReg(6 downto 0);
               -- Increment the counter
               v.bitPntr              := r.bitPntr + 1;
               -- Check the counter value
               if r.bitPntr = 7 then
                  -- Reset the counter
                  v.bitPntr                                      := (others => '0');
                  -- Shifter Register
                  v.rdBtye(conv_integer(r.bytePtnr))(0)          := din(1);
                  v.rdBtye(conv_integer(r.bytePtnr))(7 downto 1) := r.shiftReg(6 downto 0);
                  -- Increment the counter
                  v.byteCnt                                      := r.byteCnt + 1;
                  -- Check the counter value
                  if r.byteCnt = r.xferSize then
                     -- Reset the counters
                     v.byteCnt  := (others => '0');
                     v.bytePtnr := (others => '0');
                     -- Write the data to RAM
                     v.rdWen    := '1';
                     v.rdAddr   := r.wrAddr;
                     v.state    := CS_HIGH_S;
                  else
                     -- Increment the counter
                     v.bytePtnr := r.bytePtnr + 1;
                     if r.bytePtnr = 3 then
                        -- Reset the counter
                        v.bytePtnr := (others => '0');
                        -- Write the data to RAM
                        v.rdWen    := '1';
                        v.rdAddr   := r.wrAddr;
                        v.wrAddr   := r.wrAddr + 1;
                        v.state    := LATENCY_WAIT_S;
                     else
                        v.state := SCK_LOW_S;
                     end if;
                  end if;
               else
                  -- Next State
                  v.state := SCK_LOW_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when CS_HIGH_S =>
            -- Serial Clock low phase
            v.sck    := '0';
            -- Increment the counter
            v.sckCnt := r.sckCnt + 1;
            if r.sckCnt = SCK_HALF_PERIOD_C then
               -- Reset the counter
               v.sckCnt := 0;
               -- Release the chip select
               v.csL    := '1';
               -- Send AXI Response
               axiSlaveReadResponse(v.axiReadSlave);
               -- Next State
               v.state  := HANDSHAKE_S;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Synchronous Reset
      if axiRst = '1' then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      axiReadSlave  <= r.axiReadSlave;
      axiWriteSlave <= r.axiWriteSlave;

      csL  <= r.csL;
      sck  <= r.sck;
      dout <= r.dout;
      oeL  <= r.oeL;
      
   end process comb;

   seq : process (axiClk) is
   begin
      if rising_edge(axiClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   rdDin(7 downto 0)   <= r.rdBtye(0);
   rdDin(15 downto 8)  <= r.rdBtye(1);
   rdDin(23 downto 16) <= r.rdBtye(2);
   rdDin(31 downto 24) <= r.rdBtye(3);

   wrBtye(0) <= wrDout(7 downto 0);
   wrBtye(1) <= wrDout(15 downto 8);
   wrBtye(2) <= wrDout(23 downto 16);
   wrBtye(3) <= wrDout(31 downto 24);

   Write_Buffer_Inst : entity work.SimpleDualPortRam
      generic map(
         TPD_G        => TPD_G,
         BRAM_EN_G    => BRAM_EN_G,
         DATA_WIDTH_G => 32,
         ADDR_WIDTH_G => 7)
      port map (
         -- Port A
         clka  => axiClk,
         wea   => r.wrWen,
         addra => r.wrAddr,
         dina  => r.wrDin,
         -- Port B
         clkb  => axiClk,
         addrb => r.wrAddr,
         doutb => wrDout); 

   Read_Buffer_Inst : entity work.SimpleDualPortRam
      generic map(
         TPD_G        => TPD_G,
         BRAM_EN_G    => BRAM_EN_G,
         DATA_WIDTH_G => 32,
         ADDR_WIDTH_G => 7)
      port map (
         -- Port A
         clka  => axiClk,
         wea   => r.rdWen,
         addra => r.rdAddr,
         dina  => r.rdDin,
         -- Port B
         clkb  => axiClk,
         addrb => r.rdAddr,
         doutb => rdDout);     
end rtl;
