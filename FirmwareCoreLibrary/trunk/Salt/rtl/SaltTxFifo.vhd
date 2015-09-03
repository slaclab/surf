-------------------------------------------------------------------------------
-- Title      : SLAC Asynchronous Logic Transceiver (SALT)
-------------------------------------------------------------------------------
-- File       : SaltTxFifo.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-09-01
-- Last update: 2015-09-02
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: SALT TX FIFO Module
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.SaltPkg.all;

entity SaltTxFifo is
   generic (
      TPD_G              : time                := 1 ns;
      COMMON_TX_CLK_G    : boolean             := false;  -- Set to true if sAxisClk and clk are the same clock
      SLAVE_AXI_CONFIG_G : AxiStreamConfigType := ssiAxiStreamConfig(4));
   port (
      -- TX Parallel Stream
      dataK       : out sl;
      data8B      : out slv(7 downto 0);
      -- Reference Signals
      clk         : in  sl;
      rst         : in  sl;
      -- Slave Port
      sAxisClk    : in  sl;
      sAxisRst    : in  sl;
      sAxisMaster : in  AxiStreamMasterType;
      sAxisSlave  : out AxiStreamSlaveType);
end SaltTxFifo;

architecture rtl of SaltTxFifo is

   type StateType is (
      IDLE_S,
      SOF_S,
      SOC_S,
      MOVE_S,
      CHECKSUM_S,
      EOFE_S,
      EOF_S,
      EOC_S,
      DONE_S); 

   type RegType is record
      cnt      : slv(7 downto 0);
      checksum : slv(7 downto 0);
      dataK    : sl;
      data8B   : slv(7 downto 0);
      rxSlave  : AxiStreamSlaveType;
      endFrame : StateType;
      state    : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      cnt      => x"00",
      checksum => x"00",
      dataK    => '1',
      data8B   => K_COM_C,
      rxSlave  => AXI_STREAM_SLAVE_INIT_C,
      endFrame => IDLE_S,
      state    => IDLE_S);      

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal rxMaster : AxiStreamMasterType;
   signal rxSlave  : AxiStreamSlaveType;

   attribute dont_touch             : string;
   attribute dont_touch of r        : signal is "TRUE";
   attribute dont_touch of rxMaster : signal is "TRUE";
   attribute dont_touch of rxSlave  : signal is "TRUE";

begin

   FIFO_RX : entity work.SsiFifo
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         PIPE_STAGES_G       => 0,
         VALID_THOLD_G       => 1,
         EN_FRAME_FILTER_G   => true,
         -- FIFO configurations
         BRAM_EN_G           => true,
         USE_BUILT_IN_G      => false,
         GEN_SYNC_FIFO_G     => COMMON_TX_CLK_G,
         CASCADE_SIZE_G      => 1,
         FIFO_ADDR_WIDTH_G   => 9,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => SLAVE_AXI_CONFIG_G,
         MASTER_AXI_CONFIG_G => SSI_SALT_CONFIG_C)            
      port map (
         -- Slave Port
         sAxisClk    => sAxisClk,
         sAxisRst    => sAxisRst,
         sAxisMaster => sAxisMaster,
         sAxisSlave  => sAxisSlave,
         -- Master Port
         mAxisClk    => clk,
         mAxisRst    => rst,
         mAxisMaster => rxMaster,
         mAxisSlave  => rxSlave);


   comb : process (r, rst, rxMaster) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset the flags
      v.dataK   := '1';
      v.rxSlave := AXI_STREAM_SLAVE_INIT_C;

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Reset the variables
            v.cnt      := x"00";
            v.checksum := x"00";
            -- Send IDLE Comma
            v.data8B   := K_COM_C;
            -- Check for data
            if (rxMaster.tValid = '1') then
               -- Check for SOF with no EOF
               if (ssiGetUserSof(SSI_SALT_CONFIG_C, rxMaster) = '1') then
                  -- Next state
                  v.state := SOF_S;
               else
                  -- Next state
                  v.state := SOC_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when SOF_S =>
            -- Send SOF Comma
            v.data8B := K_SOF_C;
            -- Next state
            v.state  := MOVE_S;
         ----------------------------------------------------------------------
         when SOC_S =>
            -- Send SOF Comma
            v.data8B := K_SOC_C;
            -- Next state
            v.state  := MOVE_S;
         ----------------------------------------------------------------------
         when MOVE_S =>
            -- Check for data
            if (rxMaster.tValid = '1') then
               -- Accept the data
               v.rxSlave.tReady := '1';
               -- Move the data
               v.dataK          := '0';
               v.data8B         := rxMaster.tData(7 downto 0);
               -- Update checksum
               v.checksum       := r.checksum + rxMaster.tData(7 downto 0);
               -- Increment the counter
               v.cnt            := r.cnt + 1;
               -- Check for EOF
               if (rxMaster.tLast = '1') then
                  -- Check for EOFE
                  if (ssiGetUserEofe(SSI_SALT_CONFIG_C, rxMaster) = '1') then
                     -- Next state
                     v.endFrame := EOFE_S;
                     v.state    := CHECKSUM_S;
                  else
                     -- Next state
                     v.endFrame := EOF_S;
                     v.state    := CHECKSUM_S;
                  end if;
               elsif r.cnt = x"FF" then
                  -- Next state
                  v.endFrame := EOC_S;
                  v.state    := CHECKSUM_S;
               end if;
            else
               -- Send checksum
               v.dataK  := '0';
               v.data8B := not(r.checksum);  -- one's complement
               -- Next state
               v.state  := EOC_S;
            end if;
         ----------------------------------------------------------------------
         when CHECKSUM_S =>
            -- Send checksum
            v.dataK  := '0';
            v.data8B := not(r.checksum);     -- one's complement
            -- Next state
            v.state  := r.endFrame;
         ----------------------------------------------------------------------
         when EOFE_S =>
            -- Send EOFE Comma
            v.data8B := K_EOFE_C;
            -- Next state
            v.state  := DONE_S;
         ----------------------------------------------------------------------
         when EOF_S =>
            -- Send EOF Comma
            v.data8B := K_EOF_C;
            -- Next state
            v.state  := DONE_S;
         ----------------------------------------------------------------------
         when EOC_S =>
            -- Send EOC Comma
            v.data8B := K_EOC_C;
            -- Next state
            v.state  := DONE_S;
         ----------------------------------------------------------------------
         when DONE_S =>
            -- Send IDLE Comma
            v.data8B := K_COM_C;
            -- Next state
            v.state  := IDLE_S;
      ----------------------------------------------------------------------
      end case;

      -- Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs        
      rxSlave <= v.rxSlave;
      dataK   <= r.dataK;
      data8B  <= r.data8B;

   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
