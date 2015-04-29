-------------------------------------------------------------------------------
-- Title      : Single lane JESD AXI stream data control 
-------------------------------------------------------------------------------
-- File       : AxiStreamLaneTx.vhd
-- Author     : Uros Legat  <ulegat@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-04-02
-- Last update: 2014-11-10
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:   This module sends the RX JESD lane 
--                on Virtual Channel Lane.
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
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
      TPD_G             : time                        := 1 ns;
      
      -- 
      AXI_ERROR_RESP_G  : slv(1 downto 0)             := AXI_RESP_SLVERR_C;
      AXI_PACKET_SIZE_G : natural range 1 to (2**24)  :=2**8;
      
      -- JESD configuration

      -- Transceiver word size (GTP,GTX,GTH) (2 or 4 bytes)
      GT_WORD_SIZE_G    : positive                    := 4
   );
   port (
   
      -- JESD devClk
      devClk_i          : in  sl;
      devRst_i          : in  sl;
      
      -- Axi Stream
      txAxisMaster_o  : out AxiStreamMasterType;
      txCtrl_i        : in  AxiStreamCtrlType;
      
      -- JESD signals
      enable_i        : in  sl;      
      sampleData_i    : in  slv((GT_WORD_SIZE_G*8)-1 downto 0);
      dataReady_i     : in  sl
   );
end AxiStreamLaneTx;

architecture rtl of AxiStreamLaneTx is

   constant JESD_SSI_CONFIG_C : AxiStreamConfigType                           := ssiAxiStreamConfig(GT_WORD_SIZE_G, TKEEP_COMP_C);
   constant PACKET_SIZE_SLV_C : slv(bitSize(AXI_PACKET_SIZE_G)-1 downto 0)    := intToSlv(AXI_PACKET_SIZE_G, bitSize(AXI_PACKET_SIZE_G));
   constant TSTRB_C           : slv(15 downto 0)                              := (15 downto GT_WORD_SIZE_G => '0') & ( GT_WORD_SIZE_G-1 downto 0 => '1');
   constant KEEP_C            : slv(15 downto 0)                              := (15 downto GT_WORD_SIZE_G => '0') & ( GT_WORD_SIZE_G-1 downto 0 => '1');

   type StateType is (
      IDLE_S,
      SOF_S,
      DATA_S,
      EOF_S
   );  

   type RegType is record    
      dataCnt        : slv(bitSize(AXI_PACKET_SIZE_G)-1 downto 0);
      txAxisMaster   : AxiStreamMasterType;
      state          : StateType;
   end record;
   
   constant REG_INIT_C : RegType := (
      dataCnt        => (others => '0'),
      txAxisMaster   => AXI_STREAM_MASTER_INIT_C,
      state          => IDLE_S
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal txCtrl : AxiStreamCtrlType;
   
begin

   assert (GT_WORD_SIZE_G = 2 or GT_WORD_SIZE_G = 4) report "GT_WORD_SIZE_G must be 2 or 4" severity failure;

   comb : process (devRst_i, r, enable_i,sampleData_i, txCtrl_i) is
      variable v             : RegType;
      variable axilStatus    : AxiLiteStatusType;
      variable axilWriteResp : slv(1 downto 0);
      variable axilReadResp  : slv(1 downto 0);
   begin
      -- Latch the current value
      v := r;

      -- Reset strobing signals
      ssiResetFlags(v.txAxisMaster);
      v.txAxisMaster.tData := (others => '0');

      -- Latch the configuration
      v.txAxisMaster.tKeep := KEEP_C;
      v.txAxisMaster.tStrb := TSTRB_C;
      
      -- State Machine
      case (r.state) is
         ----------------------------------------------------------------------
         when IDLE_S =>
         
            -- Put packet data count to zero 
            v.dataCnt := (others => '0');  
 
            -- No data sent 
            v.txAxisMaster.tvalid  := '0';
            v.txAxisMaster.tData(GT_WORD_SIZE_G-1 downto 0)  := (others => '0');                
            v.txAxisMaster.tLast := '0';
            
            -- Check if fifo and JESD is ready
            if txCtrl_i.pause = '0' and enable_i = '1' then -- TODO later add "and dataReady_i = '1'"
               -- Next State
               v.state := SOF_S;
            end if;
         ----------------------------------------------------------------------
         when SOF_S =>
           
            -- Increment the counter            
            v.dataCnt := (others => '0');


            -- No data sent 
            v.txAxisMaster.tvalid  := '1';
            v.txAxisMaster.tData(GT_WORD_SIZE_G-1 downto 0)   := (others => '0');              
            v.txAxisMaster.tLast := '0';
            
            -- Set the SOF bit
            ssiSetUserSof(JESD_SSI_CONFIG_C, v.txAxisMaster, '1');

            v.state      := DATA_S;
         ----------------------------------------------------------------------
         when DATA_S =>
         
               -- Increment the counter            
               v.dataCnt := r.dataCnt + 1;         
         
               -- Send the JESD data 
               v.txAxisMaster.tvalid  := '1';
               v.txAxisMaster.tData((GT_WORD_SIZE_G*8)-1 downto 0)   := sampleData_i;
               v.txAxisMaster.tLast := '0'; 
         
            -- Wait until the whole packet is sent
            if r.dataCnt = PACKET_SIZE_SLV_C then
               -- Next State
               v.state   := EOF_S;
            end if;
         ----------------------------------------------------------------------
         when EOF_S =>
         
            -- Put packet data count to zero 
            v.dataCnt := (others => '0'); 

            -- No data sent 
            v.txAxisMaster.tvalid  := '1';
            v.txAxisMaster.tData(GT_WORD_SIZE_G-1 downto 0)  := (others => '0');
            -- Set the EOF(tlast) bit                
            v.txAxisMaster.tLast := '1';
            
            -- Set the EOFE bit ERROR bit TODO add JESD error later
            ssiSetUserEofe(JESD_SSI_CONFIG_C, v.txAxisMaster, '0');

            v.state := IDLE_S;

      ----------------------------------------------------------------------
      end case;

      -- Reset
      if (devRst_i = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;
      
   end process comb;

   seq : process (devClk_i) is
   begin
      if rising_edge(devClk_i) then
         r <= rin after TPD_G;
      end if;
   end process seq;
 
   -- Output assignment
   txAxisMaster_o <= r.txAxisMaster;
    

end rtl;
