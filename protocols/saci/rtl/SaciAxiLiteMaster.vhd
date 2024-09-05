-------------------------------------------------------------------------------
-- Title      : SACI Protocol: https://confluence.slac.stanford.edu/x/YYcRDQ
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: New and improved version of the AxiLiteSaciMaster.
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
use surf.AxiLitePkg.all;
use surf.SaciMasterPkg.all;

entity SaciAxiLiteMaster is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- SACI Slave interface
      saciClk         : in  sl;
      saciCmd         : in  sl;
      saciSelL        : in  sl;
      saciRsp         : out sl;
      -- AXI-Lite Register Interface
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end SaciAxiLiteMaster;

architecture rtl of SaciAxiLiteMaster is

   -- AXI-Lite Master Interface
   signal axilReq : AxiLiteReqType;
   signal axilAck : AxiLiteAckType;

   -- SACI Slave parallel interface
   signal exec   : sl;
   signal ack    : sl;
   signal readL  : sl;
   signal cmd    : slv(6 downto 0);
   signal addr   : slv(11 downto 0);
   signal wrData : slv(31 downto 0);
   signal rdData : slv(31 downto 0);


   -- attribute dont_touch      : string;
   -- attribute dont_touch of r : signal is "true";

begin

   U_SaciSlave_1 : entity surf.SaciSlave
      generic map (
         TPD_G => TPD_G)
      port map (
         rstL     => rstL,              -- [in]
         saciClk  => saciClk,           -- [in]
         saciSelL => saciSelL,          -- [in]
         saciCmd  => saciCmd,           -- [in]
         saciRsp  => saciRsp,           -- [out]
         rstOutL  => rstOutL,           -- [out]
         rstInL   => rstInL,            -- [in]
         exec     => exec,              -- [out]
         ack      => ack,               -- [in]
         readL    => readL,             -- [out]
         cmd      => cmd,               -- [out]
         addr     => addr,              -- [out]
         wrData   => wrData,            -- [out]
         rdData   => rdData);           -- [in]

   axilReq.request               <= exec;
   axilReq.rnw                   <= not readL;
   axilReq.address(1 downto 0)   <= "00";
   axilReq.address(13 downto 2)  <= addr;
   axilReq.address(20 downto 14) <= cmd;
   axilReq.wrData                <= wrData;

   ack    <= axilAck.done;
   rdData <= axilAck.rdData;

   U_AxiLiteMaster_1 : entity surf.AxiLiteMaster
      generic map (
         TPD_G       => TPD_G,
         RST_ASYNC_G => true)
      port map (
         axilClk         => axilClk,          -- [in]
         axilRst         => axilRst,          -- [in]
         req             => axilReq,          -- [in]
         ack             => axilAck,          -- [out]
         axilWriteMaster => axilWriteMaster,  -- [out]
         axilWriteSlave  => axilWriteSlave,   -- [in]
         axilReadMaster  => axilReadMaster,   -- [out]
         axilReadSlave   => axilReadSlave);   -- [in]


end rtl;
