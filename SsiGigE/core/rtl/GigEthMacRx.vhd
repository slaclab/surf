---------------------------------------------------------------------------------
-- Title         : Gigabit Ethernet (1000 BASE X) MAC RX Layer
-- Project       : General Purpose Core
---------------------------------------------------------------------------------
-- File          : GigEthMacRx.vhd
-- Author        : Kurtis Nishimura, kurtisn@slac.stanford.edu
-- Created       : 05/22/2014
---------------------------------------------------------------------------------
-- Description:
-- MAC for gigabit ethernet
---------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
---------------------------------------------------------------------------------
-- Modification history:
-- 05/22/2014: created.
---------------------------------------------------------------------------------

LIBRARY ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.StdRtlPkg.all;
use work.GigEthPkg.all;

entity GigEthMacRx is 
   generic (
      TPD_G         : time                 := 1 ns
   );
   port ( 
      -- 125 MHz ethernet clock in
      ethRxClk          : in sl;
      ethRxRst          : in sl := '0';
      -- Incoming data from the 16-to-8 mux
      ethMacDataIn      : in EthMacDataType;
      -- Outgoing bytes and flags to the applications
      ethMacRxData      : out slv(7 downto 0);
      ethMacRxValid     : out sl;
      ethMacRxGoodFrame : out sl;
      ethMacRxBadFrame  : out sl
   ); 

end GigEthMacRx;

-- Define architecture
architecture rtl of GigEthMacRx is

   type StateType is (S_IDLE, S_PREAMBLE, S_FRAME_DATA, S_WAIT_CRC, S_CHECK_CRC);
   
   type RegType is record
      state        : StateType;
      rxDataValid  : sl;
      rxDataOut    : slv(7 downto 0);
      rxGoodFrame  : sl;
      rxBadFrame   : sl;
      crcReset     : sl;
      crcDataValid : sl;
      byteCount    : slv(15 downto 0);
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      state        => S_IDLE,
      rxDataOut    => (others => '0'),
      rxDataValid  => '0',
      rxGoodFrame  => '0',
      rxBadFrame   => '0',
      crcReset     => '0',
      crcDataValid => '0',
      byteCount    => (others => '0')
   );
   
   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal crcOut       : slv(31 downto 0);
   signal crcData      : slv(31 downto 0);
   signal crcDataWidth : slv(2 downto 0);
   
   -- attribute dont_touch : string;
   -- attribute dont_touch of r : signal is "true";
   -- attribute dont_touch of crcOut : signal is "true";   
   
begin

   crcData      <= x"000000" & r.rxDataOut;
   crcDataWidth <= "000";

   U_Crc32 : entity work.Crc32Parallel
      generic map (
         BYTE_WIDTH_G => 1,
         CRC_INIT_G   => x"FFFFFFFF",
         TPD_G        => TPD_G
      )
      port map (
         crcOut        => crcOut,
         crcClk        => ethRxClk,
         crcDataValid  => r.crcDataValid,
         crcDataWidth  => crcDataWidth,
         crcIn         => r.rxDataOut,
         crcReset      => r.crcReset
      );

   comb : process(r,ethMacDataIn,ethRxRst,crcOut) is
      variable v : RegType;
   begin
      v := r;

      v.rxDataOut   := ethMacDataIn.data;
      
      case(r.state) is 
         when S_IDLE =>
            v.crcReset     := '1';
            v.crcDataValid := '0';
            v.rxDataValid  := '0';
            v.rxGoodFrame  := '0';
            v.rxBadFrame   := '0';
            v.byteCount    := (others => '0');
            -- If we see start of packet then we should move on to accept preamble
            if (ethMacDataIn.dataValid = '1' and ethMacDataIn.dataK = '1' and ethMacDataIn.data = K_SOP_C) then
               v.state := S_PREAMBLE;
            end if;
         when S_PREAMBLE =>
            v.crcReset := '0';
            if (ethMacDataIn.dataValid = '1' and ethMacDataIn.dataK = '0' and ethMacDataIn.data = ETH_SOF_C) then
               v.state := S_FRAME_DATA;
            -- Bail out if we see a comma, error, carrier
            elsif (ethMacDataIn.dataValid = '1' and ethMacDataIn.dataK = '1'  and
                   (ethMacDataIn.data = K_COM_C or ethMacDataIn.data = K_EOP_C or ethMacDataIn.data = K_CAR_C or ethMacDataIn.data = K_ERR_C)) then
               v.state := S_IDLE;
            end if;
         when S_FRAME_DATA =>
            v.rxDataValid  := ethMacDataIn.dataValid;
            v.crcDataValid := '1';
            v.byteCount    := r.byteCount + 1;
            -- Possible errors: K_ERR_C, misplaced comma (K_COM_C)
            if (ethMacDataIn.dataValid = '1' and ethMacDataIn.dataK = '1' and 
                (ethMacDataIn.data = K_ERR_C or ethMacDataIn.data = K_COM_C)) then
               v.rxDataValid := '0';
               v.rxBadFrame  := '1';
               v.rxGoodFrame := '1';
               v.state       := S_IDLE;
            -- Otherwise, should be frame data until we see end of packet
            elsif (ethMacDataIn.dataValid = '1' and ethMacDataIn.dataK = '1' and ethMacDataIn.data = K_EOP_C) then
               v.rxDataValid  := '0';
               v.crcDataValid := '0';
               v.state        := S_WAIT_CRC;
            end if;
         -- Wait one cycle to account for latency of the CRC module
         when S_WAIT_CRC =>
            v.state := S_CHECK_CRC;
         when S_CHECK_CRC =>
            -- Check for packet length and valid CRC
            if (crcOut = CRC_CHECK_C and r.byteCount >= 46) then
               v.rxGoodFrame := '1';
               v.rxBadFrame  := '0';
            -- Otherwise, it's a bad frame
            else
               v.rxGoodFrame := '0';
               v.rxBadFrame  := '1';
            end if;
            v.state := S_IDLE;
         when others =>
            v.state := S_IDLE;
      end case;
      
      -- Reset logic
      if (ethRxRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Outputs to ports
      ethMacRxData      <= r.rxDataOut;
      ethMacRxValid     <= r.rxDataValid;
      ethMacRxGoodFrame <= r.rxGoodFrame;
      ethMacRxBadFrame  <= r.rxBadFrame;
      
      rin <= v;

   end process;

   seq : process (ethRxClk) is
   begin
      if (rising_edge(ethRxClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;   

end rtl;

