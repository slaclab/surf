-------------------------------------------------------------------------------
-- Title      : PCIe Core
-------------------------------------------------------------------------------
-- File       : PcieTlpCtrl.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-16
-- Last update: 2015-04-16
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: PCIe TLP Packet Controller
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.PciePkg.all;

entity PcieTlpCtrl is
   generic (
      TPD_G      : time                   := 1 ns;
      DMA_SIZE_G : positive range 1 to 32 := 1);
   port (
      -- PCIe Interface
      trnPending       : out sl;
      cfgTurnoffOk     : out sl;
      cfgFromPci       : in  PcieCfgOutType;
      pciIbMaster      : in  AxiStreamMasterType;
      pciIbSlave       : out AxiStreamSlaveType;
      pciObMaster      : out AxiStreamMasterType;
      pciObSlave       : in  AxiStreamSlaveType;
      -- Register Interface
      regTranFromPci   : out TranFromPcieType;
      regObMaster      : out AxiStreamMasterType;
      regObSlave       : in  AxiStreamSlaveType;
      regIbMaster      : in  AxiStreamMasterType;
      regIbSlave       : out AxiStreamSlaveType;
      -- DMA Interface      
      dmaTxTranFromPci : out TranFromPcieArray(DMA_SIZE_G-1 downto 0);
      dmaRxTranFromPci : out TranFromPcieArray(DMA_SIZE_G-1 downto 0);
      dmaTxObMaster    : out AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
      dmaTxObSlave     : in  AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0);
      dmaTxIbMaster    : in  AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
      dmaTxIbSlave     : out AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0);
      dmaRxIbMaster    : in  AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
      dmaRxIbSlave     : out AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0);
      -- Clock and Resets
      pciClk           : in  sl;
      pciRst           : in  sl);       
end PcieTlpCtrl;

architecture rtl of PcieTlpCtrl is

   type StateType is (
      SOF_00_S,
      SOF_10_S,
      EOF_10_S);    

   type RegType is record
      cfgTurnoffOk : sl;
      rxSlave      : AxiStreamSlaveType;
      txMaster     : AxiStreamMasterType;
      master       : AxiStreamMasterType;
      state        : StateType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      cfgTurnoffOk => '0',
      rxSlave      => AXI_STREAM_SLAVE_INIT_C,
      txMaster     => AXI_STREAM_MASTER_INIT_C,
      master       => AXI_STREAM_MASTER_INIT_C,
      state        => SOF_00_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal txSlave : AxiStreamSlaveType;
   signal axisHdr : PcieHdrType;

   signal pendingTransaction : sl;
   signal tFirst             : sl;
   signal sof                : slv(3 downto 0);
   signal eof                : slv(3 downto 0);
   signal locId              : slv(15 downto 0);
   
begin

   trnPending <= pendingTransaction;

   --------------
   -- TLP Mapping 
   --------------
   locId <= cfgFromPci.busNumber & cfgFromPci.deviceNumber & cfgFromPci.functionNumber;

   DMA_TLP_MAPPING :
   for i in 0 to DMA_SIZE_G-1 generate

      dmaRxTranFromPci(i).tag <= toSlv((2*i)+0, 8);
      dmaTxTranFromPci(i).tag <= toSlv((2*i)+1, 8);

      dmaTxTranFromPci(i).locId <= locId;
      dmaRxTranFromPci(i).locId <= locId;
      
   end generate DMA_TLP_MAPPING;

   regTranFromPci.tag   <= x"00";       -- Not Used
   regTranFromPci.locId <= locId;

   tFirst <= pciIbMaster.tUser(1);
   sof    <= pciIbMaster.tUser(7 downto 4);
   eof    <= pciIbMaster.tUser(11 downto 8);

   -------------------------------
   -- Check for straddling frames
   -------------------------------
   comb : process (cfgFromPci, eof, pciIbMaster, pciRst, pendingTransaction, r, sof, tFirst,
                   txSlave) is
      variable v : RegType;
      variable i : natural;
   begin
      -- Latch the current value
      v := r;

      -- Update tValid register
      if txSlave.tReady = '1' then
         v.txMaster.tValid := '0';
      end if;

      case r.state is
         ----------------------------------------------------------------------
         when SOF_00_S =>
            -- Check for new data
            if pciIbMaster.tValid = '1' then
               -- Check if target is ready for data
               if v.txMaster.tValid = '0' then
                  -- Ready for data
                  v.rxSlave.tReady := '1';
                  -- Pass the data to the FIFO
                  v.txMaster       := pciIbMaster;
                  -- Save this transaction
                  v.master         := pciIbMaster;
                  -- Check for straddling SOF                  
                  if (tFirst = '1') and (sof /= x"0") then
                     -- Terminate the incoming packet
                     v.txMaster.tLast    := '1';
                     -- Block the SOF in straddling packet
                     v.txMaster.tUser(1) := '0';
                     -- Reset the tLast value
                     v.master.tLast      := '0';
                     -- Set the tKeep value
                     v.master.tKeep      := x"FFFF";
                     -- Next state
                     v.state             := SOF_10_S;
                  end if;
               else
                  -- Not ready for data
                  v.rxSlave.tReady := '0';
               end if;
            else
               -- Not ready for data
               v.rxSlave.tReady := '0';
            end if;
         ----------------------------------------------------------------------
         when SOF_10_S =>
            -- Check for new data
            if pciIbMaster.tValid = '1' then
               -- Check if target is ready for data
               if v.txMaster.tValid = '0' then
                  -- Ready for data
                  v.rxSlave.tReady                := '1';
                  -- Update the bus with last transaction
                  v.txMaster                      := r.master;
                  -- Update tData value
                  v.txMaster.tData(63 downto 0)   := r.master.tData(127 downto 64);
                  v.txMaster.tData(127 downto 64) := pciIbMaster.tData(63 downto 0);
                  -- Update tKeep value
                  v.txMaster.tKeep(7 downto 0)    := r.master.tKeep(15 downto 8);
                  v.txMaster.tKeep(15 downto 8)   := pciIbMaster.tKeep(7 downto 0);
                  -- Save this transaction
                  v.master                        := pciIbMaster;
                  -- Check for straddling SOF
                  if (tFirst = '1') and (sof /= x"0") then
                     -- Terminate the incoming packet
                     v.txMaster.tLast := '1';
                     -- Reset the tLast value
                     v.master.tLast   := '0';
                     -- Set the tKeep value
                     v.master.tKeep   := x"FFFF";
                  -- Check for tLast
                  elsif (pciIbMaster.tLast = '1') then
                     -- Check the upper half for EOF
                     if (eof(3) = '1') then
                        -- Next state
                        v.state := EOF_10_S;
                     else
                        -- Assert tLast
                        v.txMaster.tLast := '1';
                        -- Next state
                        v.state          := SOF_00_S;
                     end if;
                  end if;
               else
                  -- Not ready for data
                  v.rxSlave.tReady := '0';
               end if;
            else
               -- Not ready for data
               v.rxSlave.tReady := '0';
            end if;
         ----------------------------------------------------------------------
         when EOF_10_S =>
            -- Not ready for data
            v.rxSlave.tReady := '0';
            -- Check if target is ready for data
            if v.txMaster.tValid = '0' then
               -- Pass the data to the FIFO
               v.txMaster                      := r.master;
               -- Update tData value
               v.txMaster.tData(63 downto 0)   := r.master.tData(127 downto 64);
               v.txMaster.tData(127 downto 64) := (others => '0');
               -- Update tKeep value
               v.txMaster.tKeep(7 downto 0)    := r.master.tKeep(15 downto 8);
               v.txMaster.tKeep(15 downto 8)   := x"00";
               -- Terminate the incoming packet
               v.txMaster.tLast                := '1';
               -- Next state
               v.state                         := SOF_00_S;
            end if;
      ----------------------------------------------------------------------
      end case;

      --  Turn-off OK if requested and no transaction is pending
      if (cfgFromPci.cfgToTurnOff = '1') and (pendingTransaction = '0') then
         v.cfgTurnoffOk := '1';
      else
         v.cfgTurnoffOk := '0';
      end if;

      -- Reset
      if (pciRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      pciIbSlave   <= v.rxSlave;
      axisHdr      <= getPcieHdr(r.txMaster);
      cfgTurnoffOk <= r.cfgTurnoffOk;
      
   end process comb;

   seq : process (pciClk) is
   begin
      if rising_edge(pciClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   --------------------
   -- Receive Interface
   --------------------
   PcieTlpOutbound_Inst : entity work.PcieTlpOutbound
      generic map (
         TPD_G      => TPD_G,
         DMA_SIZE_G => DMA_SIZE_G)
      port map (
         -- PCIe Interface
         sAsixHdr      => axisHdr,
         sAxisMaster   => r.txMaster,
         sAxisSlave    => txSlave,
         -- Outbound DMA Interface
         regObMaster   => regObMaster,
         regObSlave    => regObSlave,
         dmaTxObMaster => dmaTxObMaster,
         dmaTxObSlave  => dmaTxObSlave,
         -- Global Signals
         pciClk        => pciClk,
         pciRst        => pciRst);    

   ---------------------
   -- Transmit Interface
   ---------------------
   PcieTlpInbound_Inst : entity work.PcieTlpInbound
      generic map (
         TPD_G      => TPD_G,
         DMA_SIZE_G => DMA_SIZE_G)
      port map (
         -- Inbound DMA Interface
         regIbMaster   => regIbMaster,
         regIbSlave    => regIbSlave,
         dmaTxIbMaster => dmaTxIbMaster,
         dmaRxIbMaster => dmaRxIbMaster,
         dmaTxIbSlave  => dmaTxIbSlave,
         dmaRxIbSlave  => dmaRxIbSlave,
         -- PCIe Interface
         trnPending    => pendingTransaction,
         mAxisMaster   => pciObMaster,
         mAxisSlave    => pciObSlave,
         -- Global Signals
         pciClk        => pciClk,
         pciRst        => pciRst); 

end rtl;
