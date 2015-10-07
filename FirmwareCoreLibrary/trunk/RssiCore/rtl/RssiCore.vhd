-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : RssiCore.vhd
-- Author     : Uros Legat  <ulegat@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory (Cosylab)
-- Created    : 2015-08-09
-- Last update: 2015-08-09
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
--                     
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

entity RssiCore is
   generic (
      TPD_G        : time     := 1 ns;
      SERVER_G : boolean := true;
    
      
      -- Adjustible parameters
      
      -- Transmitter
      MAX_TX_NUM_OUTS_SEG_G  : positive := 32;
      MAX_TX_OUTS_SEG_SIZE_G : positive := 16;
      
      -- Receiver
      MAX_RX_NUM_OUTS_SEG_G  : positive := 32;
      MAX_RX_OUTS_SEG_SIZE_G : positive := 16;

      -- Timeouts
      RETRANS_TOUT_G         : positive := 60;  -- ms
      ACK_TOUT_G             : positive := 30;  -- ms
      NULL_TOUT_G            : positive := 200; -- ms
      TRANS_STATE_TOUT_G     : positive := 500; -- ms
      
      -- Counters
      MAX_RETRANS_CNT_G      : positive := 2;
      MAX_CUM_ACK_CNT_G      : positive := 3;
      MAX_OUT_OF_SEQUENCE_G  : natural  := 3;
      MAX_AUTO_RST_CNT_G     : positive := 1;
      
      -- Standard parameters
      SYN_HEADER_SIZE_G   : natural := 28;
      ACK_HEADER_SIZE_G   : natural := 6;
      EACK_HEADER_SIZE_G  : natural := 6;      
      RST_HEADER_SIZE_G   : natural := 6;      
      NULL_HEADER_SIZE_G  : natural := 6;
      DATA_HEADER_SIZE_G  : natural := 6     
   );
   port (
      clk_i      : in  sl;
      rst_i      : in  sl
      

   );
end entity RssiCore;

architecture rtl of RssiCore is

begin
 
end architecture rtl;