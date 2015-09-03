-------------------------------------------------------------------------------
-- Title      : SLAC Asynchronous Logic Transceiver (SALT)
-------------------------------------------------------------------------------
-- File       : SaltRxFifo.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-09-01
-- Last update: 2015-09-02
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: SALT RX FIFO Module
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

entity SaltRxFifo is
   generic (
      TPD_G               : time                := 1 ns;
      COMMON_RX_CLK_G     : boolean             := false;  -- Set to true if mAxisClk and clk are the same clock
      MASTER_AXI_CONFIG_G : AxiStreamConfigType := ssiAxiStreamConfig(4));
   port (
      -- RX Parallel Stream
      data8B      : in  slv(7 downto 0);
      dataK       : in  sl;
      codeErr     : in  sl;
      dispErr     : in  sl;
      -- Reference Signals
      clk         : in  sl;
      rst         : in  sl;
      -- Master Port
      mAxisClk    : in  sl;
      mAxisRst    : in  sl;
      mAxisMaster : out AxiStreamMasterType;
      mAxisSlave  : in  AxiStreamSlaveType);
end SaltRxFifo;

architecture rtl of SaltRxFifo is

   type StateType is (
      IDLE_S,
      START_S,
      MOVE_S); 

   type RegType is record
      sof      : sl;
      eofe     : sl;
      data8B   : Slv8Array(1 downto 0);
      dataK    : slv(1 downto 0);
      checksum : slv(7 downto 0);
      txMaster : AxiStreamMasterType;
      state    : StateType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      sof      => '1',
      eofe     => '0',
      data8B   => (others => x"00"),
      dataK    => (others => '0'),
      checksum => x"00",
      txMaster => AXI_STREAM_MASTER_INIT_C,
      state    => IDLE_S);      

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal txMaster : AxiStreamMasterType;
   signal txSlave  : AxiStreamSlaveType;

   attribute dont_touch             : string;
   attribute dont_touch of r        : signal is "TRUE";
   attribute dont_touch of txMaster : signal is "TRUE";
   attribute dont_touch of txSlave  : signal is "TRUE";

begin

   comb : process (codeErr, data8B, dataK, dispErr, r, rst, txSlave) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset the flags
      if txSlave.tReady = '1' then
         v.txMaster.tValid := '0';
         v.txMaster.tLast  := '0';
         v.txMaster.tUser  := (others => '0');
      end if;

      -- Create delayed copies
      v.data8B(0) := data8B;
      v.dataK(0)  := dataK;
      v.data8B(1) := r.data8B(0);
      v.dataK(1)  := r.dataK(0);

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check for IDLE Comma
            if (r.dataK(1) = '1') and (r.data8B(1) = K_COM_C) then
               -- Next state
               v.state := START_S;
            end if;
         ----------------------------------------------------------------------
         when START_S =>
            -- Check for dataK
            if (r.dataK(1) = '1') then
               -- Reset the variable
               v.checksum := x"00";
               -- Check for SOF
               if (r.data8B(1) = K_SOF_C) then
                  -- Reset the flag
                  v.eofe  := '0';
                  -- Set the flag
                  v.sof   := '1';
                  -- Next state
                  v.state := MOVE_S;
               elsif (r.data8B(1) = K_SOC_C) then
                  -- Next state
                  v.state := MOVE_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when MOVE_S =>
            -- Check for data   
            if (r.dataK(1) = '0') then
               -- Check if ready to move data
               if (v.txMaster.tValid = '0') then
                  -- Move the data
                  v.txMaster.tValid            := '1';
                  v.txMaster.tData(7 downto 0) := r.data8B(1);
                  -- Update checksum
                  v.checksum                   := r.checksum + r.data8B(1);
                  -- Check for SOF bit
                  if r.sof = '1' then
                     -- Reset the flag
                     v.sof := '0';
                     -- Set the SOF bit
                     ssiSetUserSof(SSI_SALT_CONFIG_C, v.txMaster, '1');
                  end if;
                  -- Look ahead and check for EOFE
                  if (dataK = '1') and (data8B = K_EOFE_C) then
                     -- Set the EOF bit
                     v.txMaster.tLast := '1';
                     -- Set the EOFE bit
                     ssiSetUserEofe(SSI_SALT_CONFIG_C, v.txMaster, '1');
                     -- Next state
                     v.state          := IDLE_S;
                  end if;
                  -- Look ahead and check for EOF
                  if (dataK = '1') and (data8B = K_EOF_C) then
                     -- Set the EOF bit
                     v.txMaster.tLast := '1';
                     -- Check for non-K in checksum
                     if (r.dataK(0) = '0') then
                        -- Check if checksum disagreement
                        if v.checksum /= not(r.data8B(0)) then
                           -- Set the flag
                           v.eofe := '1';
                        end if;
                     else
                        -- Set the flag
                        v.eofe := '1';
                     end if;
                     -- Set the EOFE bit
                     ssiSetUserEofe(SSI_SALT_CONFIG_C, v.txMaster, v.eofe);
                     -- Next state
                     v.state := IDLE_S;
                  end if;
                  -- Look ahead and check for EOC
                  if (dataK = '1') and (data8B = K_EOC_C) then
                     -- Check for non-K in checksum
                     if (r.dataK(0) = '0') then
                        -- Check if checksum disagreement
                        if v.checksum /= not(r.data8B(0)) then
                           -- Set the flag
                           v.eofe := '1';
                        end if;
                     else
                        -- Set the flag
                        v.eofe := '1';
                     end if;
                     -- Next state
                     v.state := IDLE_S;
                  end if;
               else
                  -- Set the flag
                  v.eofe := '1';
               end if;
            -- Else invalid logic state
            else
               -- Set the flag
               v.eofe  := '1';
               -- Next state
               v.state := IDLE_S;
            end if;
      ----------------------------------------------------------------------
      end case;


      -- Reset
      if (rst = '1') or (codeErr = '1') or (dispErr = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs        
      txMaster <= r.txMaster;

   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   FIFO_TX : entity work.SsiFifo
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         PIPE_STAGES_G       => 0,
         VALID_THOLD_G       => 1,
         EN_FRAME_FILTER_G   => true,
         -- FIFO configurations
         BRAM_EN_G           => true,
         USE_BUILT_IN_G      => false,
         GEN_SYNC_FIFO_G     => COMMON_RX_CLK_G,
         CASCADE_SIZE_G      => 1,
         FIFO_ADDR_WIDTH_G   => 9,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => SSI_SALT_CONFIG_C,
         MASTER_AXI_CONFIG_G => MASTER_AXI_CONFIG_G)            
      port map (
         -- Slave Port
         sAxisClk    => clk,
         sAxisRst    => rst,
         sAxisMaster => txMaster,
         sAxisSlave  => txSlave,
         -- Master Port
         mAxisClk    => mAxisClk,
         mAxisRst    => mAxisRst,
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);   

end rtl;
