
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiPkg.all;

entity AxiReadEmulate is
   generic (
      TPD_G            : time                       := 1 ns;
      AXI_CONFIG_G     : AxiConfigType              := AXI_CONFIG_INIT_C
   );
   port (

      -- Clock/Reset
      axiClk          : in  sl;
      axiRst          : in  sl;

      -- AXI Interface
      axiReadMaster   : in  AxiReadMasterType;
      axiReadSlave    : out AxiReadSlaveType
   );
end AxiReadEmulate;

architecture structure of AxiReadEmulate is

   type StateType is (S_IDLE_C, S_DATA_C);

   type RegType is record
      state    : StateType;
      count    : slv(31 downto 0);
      iMaster  : AxiReadMasterType;
      iSlave   : AxiReadSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state    => S_IDLE_C,
      count    => (others=>'0'),
      iMaster  => AXI_READ_MASTER_INIT_C,
      iSlave   => AXI_READ_SLAVE_INIT_C
   );

   signal r             : RegType := REG_INIT_C;
   signal rin           : RegType;

   signal intReadMaster : AxiReadMasterType;
   signal intReadSlave  : AxiReadSlaveType;

begin

   U_AxiReadPathFifo: entity work.AxiReadPathFifo 
      generic map (
         TPD_G           => TPD_G,
         AXI_CONFIG_G    => AXI_CONFIG_G
      ) port map (
         sAxiClk         => axiClk,
         sAxiRst         => axiRst,
         sAxiReadMaster  => axiReadMaster,
         sAxiReadSlave   => axiReadSlave,
         mAxiClk         => axiClk,
         mAxiRst         => axiRst,
         mAxiReadMaster  => intReadMaster,
         mAxiReadSlave   => intReadSlave
      );


   comb : process (axiRst, r, intReadMaster ) is
      variable v : RegType;
   begin
      v := r;

      -- Init
      v.iSlave := AXI_READ_SLAVE_INIT_C;

      -- State machine
      case r.state is

         -- IDLE
         when S_IDLE_C =>
            v.count := (others=>'0');
            
            if intReadMaster.arvalid = '1' then
               v.iMaster        := intReadMaster;
               v.iSlave.arready := '1';
               v.state          := S_DATA_C;
            end if;

         -- DATA
         when S_DATA_C =>

            if intReadMaster.rready = '1' then

               for i in 0 to (2**conv_integer(r.iMaster.arsize))-1 loop
                  v.iSlave.rdata(i*8+7 downto i*8) := v.count(7 downto 0);
                  v.count := v.count + 1;
               end loop;

               v.iSlave.rvalid := '1';
               v.iSlave.rid    := r.iMaster.arid;

               if r.iMaster.arlen = 0 then
                  v.iSlave.rlast := '1';
                  v.state        := S_IDLE_C;
               else
                  v.iMaster.arlen := r.iMaster.arlen - 1;
               end if;
            end if;

         when others =>
            v.state := S_IDLE_C;

      end case;

      -- Resets
      if (axiRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      intReadSlave <= v.iSlave;

   end process comb;

   seq : process (axiClk) is
   begin
      if (rising_edge(axiClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end structure;

