---------------------------------------------------------------------
----                                                             ----
----  WISHBONE revB2 I2C Master Core; bit-controller             ----
----                                                             ----
----                                                             ----
----  Author: Richard Herveille                                  ----
----          richard@asics.ws                                   ----
----          www.asics.ws                                       ----
----                                                             ----
----  Downloaded from: http://www.opencores.org/projects/i2c/    ----
----                                                             ----
---------------------------------------------------------------------
----                                                             ----
---- Copyright (C) 2000 Richard Herveille                        ----
----                    richard@asics.ws                         ----
----                                                             ----
---- This source file may be used and distributed without        ----
---- restriction provided that this copyright statement is not   ----
---- removed from the file and that any derivative work contains ----
---- the original copyright notice and the associated disclaimer.----
----                                                             ----
----     THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY     ----
---- EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED   ----
---- TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS   ----
---- FOR A PARTICULAR PURPOSE. IN NO EVENT SHALL THE AUTHOR      ----
---- OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,         ----
---- INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES    ----
---- (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE   ----
---- GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR        ----
---- BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF  ----
---- LIABILITY, WHETHER IN  CONTRACT, STRICT LIABILITY, OR TORT  ----
---- (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT  ----
---- OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE         ----
---- POSSIBILITY OF SUCH DAMAGE.                                 ----
----                                                             ----
---------------------------------------------------------------------

--  CVS Log
--
--  $Id: i2c_master_bit_ctrl.vhd,v 1.14 2006/10/11 12:10:13 rherveille Exp $
--
--  $Date: 2006/10/11 12:10:13 $
--  $Revision: 1.14 $
--  $Author: rherveille $
--  $Locker:  $
--  $State: Exp $
--
-- Change History:
--               $Log: i2c_master_bit_ctrl.vhd,v $
--               Revision 1.14  2006/10/11 12:10:13  rherveille
--               Added missing semicolons ';' on endif
--
--               Revision 1.13  2006/10/06 10:48:24  rherveille
--               fixed short scl high pulse after clock stretch
--
--               Revision 1.12  2004/05/07 11:53:31  rherveille
--               Fixed previous fix :) Made a variable vs signal mistake.
--
--               Revision 1.11  2004/05/07 11:04:00  rherveille
--               Fixed a bug where the core would signal an arbitration lost (AL bit set), when another master controls the bus and the other master generates a STOP bit.
--
--               Revision 1.10  2004/02/27 07:49:43  rherveille
--               Fixed a bug in the arbitration-lost signal generation. VHDL version only.
--
--               Revision 1.9  2003/08/12 14:48:37  rherveille
--               Forgot an 'end if' :-/
--
--               Revision 1.8  2003/08/09 07:01:13  rherveille
--               Fixed a bug in the Arbitration Lost generation caused by delay on the (external) sda line.
--               Fixed a potential bug in the byte controller's host-acknowledge generation.
--
--               Revision 1.7  2003/02/05 00:06:02  rherveille
--               Fixed a bug where the core would trigger an erroneous 'arbitration lost' interrupt after being reset, when the reset pulse width < 3 clk cycles.
--
--               Revision 1.6  2003/02/01 02:03:06  rherveille
--               Fixed a few 'arbitration lost' bugs. VHDL version only.
--
--               Revision 1.5  2002/12/26 16:05:47  rherveille
--               Core is now a Multimaster I2C controller.
--
--               Revision 1.4  2002/11/30 22:24:37  rherveille
--               Cleaned up code
--
--               Revision 1.3  2002/10/30 18:09:53  rherveille
--               Fixed some reported minor start/stop generation timing issuess.
--
--               Revision 1.2  2002/06/15 07:37:04  rherveille
--               Fixed a small timing bug in the bit controller.\nAdded verilog simulation environment.
--
--               Revision 1.1  2001/11/05 12:02:33  rherveille
--               Split i2c_master_core.vhd into separate files for each entity; same layout as verilog version.
--               Code updated, is now up-to-date to doc. rev.0.4.
--               Added headers.
--
-- Modified by Jan Andersson (jan@gaisler.com):
--
--              * Added two start states to fulfill Set-up time for
--                repeated START condition.
--              * Modified synchronization of SCL and SDA. START and STOP detection
--                is now performed after a two stage synchronizer and is also
--                filtered. 
--              * Changed evaluation order of 'slave_wait', 'en' and 'cnt' in
--                generation of clk_en signal to prevent clk_en assertion when
--                slave_wait is asserted.
--              * Needed to differentiate between slave clock stretching and master
--                clock synchronization.
--              * Added register s_state which contains the next state in case
--                of clock synchronization
--              * Incorporated change in wr_b state from SVN rev. 72 of
--                original OC version (delay check of SDA).
--              * Added 'filter' generic that determines length of filter.
--                Original OC core has a median filter implemented. The solution
--                implemented in this version is a plain shift register with a
--                length determined by the new generic. All samples in this
--                register must be equal, otherwise the SCL or SDA value used by
--                the core will not be changed. Every SCL/SDA transition that is
--                not stable for 'filter' system clock cycles is disregarded.
--                This solution is potentially more vulnerable against short
--                periods of relatively quick fluctuations on the line, however
--                it should do a better job of ignoring 50 ns pulses and still
--                allow us to respond quickly to events on the line - assuming
--                that the core has been correctly configured.
--                Core revision has been increased to 2 (in GRLIB PnP)
--              * Added 'dynfilt' generic to allow dynamic adjustment of the
--                filter. This component takes in a filt vector that is used to
--                reload a filter counter. The filt vector is assigned via the
--                core's APB interface.
--                Reorganized parts of the code, moving signals into blocks.
--                Core revision increased to 3.
-- 
-------------------------------------
-- Bit controller section
------------------------------------
--
-- Translate simple commands into SCL/SDA transitions
-- Each command has 5 states, A/B/C/D/idle
--
-- start:    SCL  ~~~~~~~~~~~~~~\____
--	     SDA  XX/~~~~~~~\______
--	          x | A | B | C | D | i
--
-- repstart  SCL  ______/~~~~~~~\___
--	     SDA  __/~~~~~~~\______
--	          x | A | B | C | D | i
--
-- stop      SCL  _______/~~~~~~~~~~~
--	     SDA  ==\___________/~~~~~
--	          x | A | B | C | D | i
--
--- write    SCL  ______/~~~~~~~\____
--	     SDA  XXX===============XX
--	          x | A | B | C | D | i
--
--- read     SCL  ______/~~~~~~~\____
--	     SDA  XXXXXXX=XXXXXXXXXXX
--	          x | A | B | C | D | i
--

-- Timing:      Normal mode     Fast mode
-----------------------------------------------------------------
-- Fscl         100KHz          400KHz
-- Th_scl       4.0us           0.6us   High period of SCL
-- Tl_scl       4.7us           1.3us   Low period of SCL
-- Tsu:sta      4.7us           0.6us   setup time for a repeated start condition
-- Tsu:sto      4.0us           0.6us   setup time for a stop conditon
-- Tbuf         4.7us           1.3us   Bus free time between a stop and start condition
--

library ieee;
use ieee.std_logic_1164.all;
--library grlib;
use work.stdlib.all;

entity i2c_master_bit_ctrl is
        generic (filter : integer; dynfilt : integer);
	port (
		clk    : in std_logic;
		rst    : in std_logic;
		nReset : in std_logic;
		ena    : in std_logic;				-- core enable signal

		clk_cnt : in std_logic_vector(15 downto 0);		-- clock prescale value

		cmd     : in std_logic_vector(3 downto 0);
		cmd_ack : out std_logic; -- command completed
		busy    : out std_logic; -- i2c bus busy
		al      : out std_logic; -- arbitration lost

		din  : in std_logic;
		dout : out std_logic;

                filt   : in std_logic_vector((filter-1)*dynfilt downto 0);

		-- i2c lines
		scl_i   : in std_logic;  -- i2c clock line input
		scl_o   : out std_logic; -- i2c clock line output
		scl_oen : out std_logic; -- i2c clock line output enable, active low
		sda_i   : in std_logic;  -- i2c data line input
		sda_o   : out std_logic; -- i2c data line output
		sda_oen : out std_logic  -- i2c data line output enable, active low
	);
end entity i2c_master_bit_ctrl;

architecture structural of i2c_master_bit_ctrl is
	constant I2C_CMD_NOP    : std_logic_vector(3 downto 0) := "0000";
	constant I2C_CMD_START  : std_logic_vector(3 downto 0) := "0001";
	constant I2C_CMD_STOP   : std_logic_vector(3 downto 0) := "0010";
	constant I2C_CMD_READ   : std_logic_vector(3 downto 0) := "0100";
	constant I2C_CMD_WRITE  : std_logic_vector(3 downto 0) := "1000";
        
	type states is (idle, start_a, start_b, start_c, start_d, start_e, start_f, start_g,
	                stop_a, stop_b, stop_c, stop_d, rd_a, rd_b, rd_c, rd_d, wr_a, wr_b, wr_c, wr_d);
	signal c_state, s_state : states;

	signal iscl_oen, isda_oen : std_logic;                     -- internal I2C lines
	signal sda_chk            : std_logic;          -- check SDA status (multi-master arbitration)
        signal fSCL, fSDA         : std_logic_vector(1 downto 0);  -- Filtered SCL and SDA inputs
	signal clk_en, slave_wait : std_logic;          -- clock generation signals
	signal ial                : std_logic;          -- internal arbitration lost signal
	signal cnt                : std_logic_vector(15 downto 0); -- clock divider counter
        signal csync              : std_logic;          -- Need to synchronize clock with other master
        
begin   
	-- generate clk enable signal
	gen_clken: process(clk, nReset)
	begin
	    if (nReset = '0') then
	      cnt    <= (others => '0');
	      clk_en <= '1';
	    elsif (clk'event and clk = '1') then
	      if (rst = '1') then
	        cnt    <= (others => '0');
	        clk_en <= '1';
              elsif (ena = '0' or csync = '1') then
                cnt    <= clk_cnt;
	        clk_en <= '1';
              elsif (slave_wait = '1') then
	        cnt    <= cnt;
	        clk_en <= '0';
	      elsif (cnt = X"0000") then
	        cnt    <= clk_cnt;
	        clk_en <= '1';
	      else
	        cnt    <= cnt -1;
	        clk_en <= '0';
	      end if;
	    end if;
	end process gen_clken;


	-- generate bus status controller
	bus_status_ctrl: block
          signal sta_condition       : std_logic;  -- start detected
	  signal sto_condition       : std_logic;  -- stop detected
	  signal cmd_stop            : std_logic;  -- STOP command
	  signal ibusy               : std_logic;  -- internal busy signal
          signal slvw_dis            : std_logic;          -- Slave wait disable;
	begin

          -- Static filter
          staticfilt : if dynfilt = 0 generate
            sfblock : block
              constant FR : integer := filter;  -- Filter range MSb
              constant DR : integer := filter + 1;  -- Delayed SCL/SDA range MSb
              
              signal sSCL, sSDA : std_logic_vector(FR downto 0); -- synchronized SCL and SDA inputs
              signal discl_oen  : std_logic_vector(DR downto 0); -- delayed scl_oen signal
              signal disda_oen  : std_logic_vector(DR downto 0); -- delayed isda_oen
            begin
              -- synchronize SCL and SDA inputs
              synch_scl_sda: process(clk, nReset)
              begin
	        if (nReset = '0') then                  
	          sSCL <= (others => '1');
	          sSDA <= (others => '1');
                  fSCL <= (others => '1');
                  fSDA <= (others => '1');
	        elsif (clk'event and clk = '1') then
	          if (rst = '1') then                    
                    sSCL <= (others => '1');
                    sSDA <= (others => '1');
                    fSCL <= (others => '1');
                    fSDA <= (others => '1');
	          else
                    sSCL <= sSCL(FR-1 downto 0) & scl_i;
                    sSDA <= sSDA(FR-1 downto 0) & sda_i;
                    -- Filtering
                    if andv(sSCL(FR downto 1)) = '1' then
                      fSCL <= fSCL(0) & '1';
                    elsif orv(sSCL(FR downto 1)) = '0' then
                      fSCL <= fSCL(0) & '0';
                    else
                      fSCL <= fSCL;
                    end if;
                    if andv(sSDA(FR downto 1)) = '1' then
                      fSDA <= fSDA(0) & '1';
                    elsif orv(sSDA(FR downto 1)) = '0' then
                      fSDA <= fSDA(0) & '0';
                    else
                      fSDA <= fSDA;
                    end if;
	          end if;
	        end if;
              end process synch_SCL_SDA;

              -- whenever the slave is not ready it can delay the cycle by pulling SCL low
              -- delay scl_oen
              process (clk)
              begin
                if (clk'event and clk = '1') then
                  if rst = '1' then
                    discl_oen <= (others => '1');
                    slvw_dis <= '0';
                  else
                    -- Keep SCL output enable values
                    discl_oen <= discl_oen(DR-1 downto 0) & iscl_oen;
                    -- Disable slave stretch detection when other device drives SCL
                    -- H->L (only a master should to this).
                    slvw_dis <= (slvw_dis or csync) and discl_oen(0);
                  end if;
                end if;
              end process;        
              -- SCL forced low after master tried to assert, slave is stretching clock
              slave_wait <= andv(discl_oen(DR downto 1)) and not fSCL(0) and not (slvw_dis or fSCL(1));
              -- SCL HIGH time cut short, master clock synchronization
              csync <= andv(discl_oen(DR downto 1)) and not fSCL(0) and fSCL(1);

              -- generate arbitration lost signal
              -- aribitration lost when:
              -- 1) master drives SDA high, but the i2c bus is low
              -- 2) stop detected while not requested (detect during 'idle' state)
              gen_al: process(clk, nReset)
              begin
                if (nReset = '0') then
                  cmd_stop  <= '0';
                  ial       <= '0';
                  disda_oen <= (others => '1');
                elsif (clk'event and clk = '1') then
                  if (rst = '1') then
                    cmd_stop  <= '0';
                    ial       <= '0';
                    disda_oen <= (others => '1');
                  else
                    if (clk_en = '1') then
                      if (cmd = I2C_CMD_STOP) then
                        cmd_stop <= '1';
                      else
                        cmd_stop <= '0';
                      end if;
                    end if;

                    if (c_state = idle) then
                      ial <= (sda_chk and not fSDA(0) and disda_oen(DR)); 
                    else
                      ial <= (sda_chk and not fSDA(0) and disda_oen(DR)) or
                             (sto_condition and not cmd_stop);
                    end if;
                  end if;
                  disda_oen <= disda_oen(DR-1 downto 0) & isda_oen;
                end if;
              end process gen_al;
            end block sfblock;            
          end generate staticfilt;

          -- Dynamic filter
          dynamicfilt : if dynfilt /= 0 generate
            -- Fixed window
            dfblock : block
              signal filtcnt : std_logic_vector(filter-1 downto 0);
              signal sSCL, sSDA : std_logic_vector(1 downto 0); -- synchronized SCL and SDA inputs
              signal fiscl_oen : std_logic_vector(1 downto 0);  -- "filtered" scl_oen signal
              signal fisda_oen : std_ulogic;  -- "filtered" sda_oen signal
              signal fSCL_chg, fSDA_chg, fiscl_oen_chg, fisda_oen_chg : std_ulogic;
              signal discl_oen : std_ulogic;  -- delayed scl_oen signal
              signal disda_oen : std_ulogic;  -- delayed sda_oen signal
            begin
              -- Provides filtered signals for SCL and SDA, and corresponding
              -- output enable signals.
              sync_scl_sda: process(clk, nReset, fSCL_chg, fSDA_chg, fiscl_oen_chg, fisda_oen_chg)
                variable scl_chg, sda_chg, iscl_oen_chg, isda_oen_chg : std_ulogic;
              begin
                scl_chg := fSCL_chg; sda_chg := fSDA_chg;
                iscl_oen_chg := fiscl_oen_chg; isda_oen_chg := fisda_oen_chg;
	        if (nReset = '0') then                  
                  filtcnt <= (others => '0');
                  fSCL <= (others => '1'); fSDA <= (others => '1');
                  fSCL_chg <= '0'; fSDA_chg <= '0';
                  fiscl_oen <= (others => '1'); fiscl_oen_chg <= '0';
                  fisda_oen <= '1'; fisda_oen_chg <= '0';
	        elsif (clk'event and clk = '1') then
	          if (rst = '1') or (ena = '0') then                    
                    filtcnt <= (others => '0');
                    fSCL <= (others => '1'); fSDA <= (others => '1');
                    fSCL_chg <= '0'; fSDA_chg <= '0';
                    fiscl_oen <= (others => '1'); fiscl_oen_chg <= '0';
                    fisda_oen <= '1'; fisda_oen_chg <= '0';
                  else
                    if (sSCL(1) xor fSCL(0)) = '0' then scl_chg := '0'; end if;
                    if (sSDA(1) xor fSDA(0)) = '0' then sda_chg := '0'; end if;
                    if (discl_oen xor fiscl_oen(0)) = '0' then iscl_oen_chg := '0'; end if;
                    if (disda_oen xor fisda_oen) = '0' then isda_oen_chg := '0'; end if;
                    if filtcnt = zero32((filter-1)*dynfilt downto 0) then
                      filtcnt <= filt;
                      fSCL <= fSCL(0) & (fSCL(0) xor scl_chg);
                      fSDA <= fSDA(0) & (fSDA(0) xor sda_chg);
                      fSCL_chg <= '1'; fSDA_chg <= '1';
                      fiscl_oen <= fiscl_oen(0) & (fiscl_oen(0) xor iscl_oen_chg);
                      fiscl_oen_chg <= '1';
                      fisda_oen <= fisda_oen xor isda_oen_chg;
                      fisda_oen_chg <= '1';
                    else
                      filtcnt <= filtcnt - 1;
                      fSDA <= fSDA; fSCL <= fSCL;
                      fSCL_chg <= scl_chg; fSDA_chg <= sda_chg;
                      fiscl_oen <= fiscl_oen;
                      fiscl_oen_chg <= iscl_oen_chg;
                      fisda_oen <= fisda_oen;
                      fisda_oen_chg <= isda_oen_chg;
                    end if;
                  end if;
                  sSCL <= sSCL(0) & scl_i;
                  sSDA <= sSDA(0) & sda_i;
	        end if;
              end process sync_SCL_SDA;

              -- whenever the slave is not ready it can delay the cycle by pulling SCL low
              -- delay scl_oen
              process (clk)
              begin
                if (clk'event and clk = '1') then
                  if rst = '1' then
                    discl_oen <= '1';
                    slvw_dis <= '0';
                  else
                    -- Keep SCL output enable values
                    discl_oen <= iscl_oen;
                    -- Disable slave stretch detection when other device drives SCL
                    -- H->L (only a master should to this).
                    slvw_dis <= (slvw_dis or csync) and discl_oen;
                  end if;
                end if;
              end process;        
              -- SCL forced low after master tried to assert, slave is stretching clock
              slave_wait <= andv(fiscl_oen) and not fSCL(0) and not (slvw_dis or fSCL(1));
              -- SCL HIGH time cut short, master clock synchronization
              csync <= andv(fiscl_oen) and not fSCL(0) and fSCL(1);

              -- generate arbitration lost signal
              -- aribitration lost when:
              -- 1) master drives SDA high, but the i2c bus is low
              -- 2) stop detected while not requested (detect during 'idle' state)
              gen_ald: process(clk, nReset)
              begin
                if (nReset = '0') then
                  cmd_stop  <= '0';
                  ial       <= '0';
                  disda_oen <= '1';
                elsif (clk'event and clk = '1') then
                  if (rst = '1') then
                    cmd_stop  <= '0';
                    ial       <= '0';
                    disda_oen <= '1';
                  else
                    if (clk_en = '1') then
                      if (cmd = I2C_CMD_STOP) then
                        cmd_stop <= '1';
                      else
                        cmd_stop <= '0';
                      end if;
                    end if;
                    if (c_state = idle) then
                      ial <= (sda_chk and not fSDA(0) and fisda_oen); 
                    else
                      ial <= (sda_chk and not fSDA(0) and fisda_oen) or
                             (sto_condition and not cmd_stop);
                    end if;
                    disda_oen <= isda_oen;
                  end if;
                end if;
              end process gen_ald;
            end block dfblock;
          end generate dynamicfilt;
          
          al <= ial;
          
          -- detect start condition => detect falling edge on SDA while SCL is high
          -- detect stop condition  => detect rising edge on SDA while SCL is high
          detect_sta_sto: process(clk, nReset)
	    begin
	        if (nReset = '0') then
	          sta_condition <= '0';
	          sto_condition <= '0';
	        elsif (clk'event and clk = '1') then
	          if (rst = '1') then
	            sta_condition <= '0';
	            sto_condition <= '0';
	          else
                    if fSCL = "11" and fSDA = "10" then
                      sta_condition <= '1';
                    else
                      sta_condition <= '0';
                    end if;
                    if fSCL = "11" and fSDA = "01" then
                      sto_condition <= '1';
                    else
                      sto_condition <= '0';
                    end if;
	          end if;
	        end if;
	    end process detect_sta_sto;

	    -- generate i2c-bus busy signal
	    gen_busy: process(clk, nReset)
	    begin
	        if (nReset = '0') then
	          ibusy <= '0';
	        elsif (clk'event and clk = '1') then
	          if (rst = '1') then
	            ibusy <= '0';
	          else
	            ibusy <= (sta_condition or ibusy) and not sto_condition;
	          end if;
	        end if;
	    end process gen_busy;
	    busy <= ibusy;

	    -- generate dout signal, store dout on rising edge of SCL
	    gen_dout: process(clk)
	    begin
	      if (clk'event and clk = '1') then
	        if fSCL = "01" then
	          dout <= fSDA(1);
	        end if;
	      end if;
	    end process gen_dout;
	end block bus_status_ctrl;


	-- generate statemachine
	nxt_state_decoder : process (clk, nReset, c_state, cmd)
	begin
	    if (nReset = '0') then
	      c_state   <= idle;
              s_state   <= idle;
	      cmd_ack   <= '0';
	      iscl_oen  <= '1';
	      isda_oen  <= '1';
              sda_chk   <= '0';
	    elsif (clk'event and clk = '1') then
	     if (rst = '1' or ial = '1') then
	        c_state   <= idle;
	        cmd_ack   <= '0';
	        iscl_oen  <= '1';
	        isda_oen  <= '1';
	        sda_chk   <= '0';
             elsif csync = '1' then
               c_state <= s_state;
             else
  
               cmd_ack <= '0'; -- default no acknowledge

               -- csync is always '0' here, but including it in the expression
               -- appears to let some compilers optimize the design more...
               if (clk_en or csync) = '1' then  

	          case (c_state) is
	             -- idle
	             when idle =>
	                case cmd is
	                  when I2C_CMD_START => c_state <= start_a;
                                                s_state <= start_g;
	                  when I2C_CMD_STOP  => c_state <= stop_a;
                                                s_state <= stop_d;
	                  when I2C_CMD_WRITE => c_state <= wr_a;
                                                s_state <= wr_d;
	                  when I2C_CMD_READ  => c_state <= rd_a;
                                                s_state <= rd_d;
	                  when others        => c_state <= idle; -- NOP command
                                                s_state <= idle;
	                end case;

	                iscl_oen <= iscl_oen; -- keep SCL in same state
	                isda_oen <= isda_oen; -- keep SDA in same state
	                sda_chk  <= '0';      -- don't check SDA

	             -- start
	             when start_a =>
	                c_state  <= start_b;
	                iscl_oen <= iscl_oen; -- keep SCL in same state (for repeated start)
	                isda_oen <= '1';      -- set SDA high
	                sda_chk  <= '0';      -- don't check SDA

                     when start_b =>
	                c_state  <= start_c;
	                iscl_oen <= '1'; -- set SCL high
	                isda_oen <= '1'; -- keep SDA high
	                sda_chk  <= '0'; -- don't check SDA

                     when start_c =>
	                c_state  <= start_d;
	                iscl_oen <= '1'; -- set SCL high
	                isda_oen <= '1'; -- keep SDA high
	                sda_chk  <= '0'; -- don't check SDA
                        
	             when start_d =>
	                c_state  <= start_e;
	                iscl_oen <= '1'; -- set SCL high
	                isda_oen <= '1'; -- keep SDA high
	                sda_chk  <= '0'; -- don't check SDA

	             when start_e =>
	                c_state  <= start_f;
	                iscl_oen <= '1'; -- keep SCL high
	                isda_oen <= '0'; -- set SDA low
	                sda_chk  <= '0'; -- don't check SDA

	             when start_f =>
	                c_state  <= start_g;
	                iscl_oen <= '1'; -- keep SCL high
	                isda_oen <= '0'; -- keep SDA low
	                sda_chk  <= '0'; -- don't check SDA

	             when start_g =>
	                c_state  <= idle;
	                cmd_ack  <= '1'; -- command completed
	                iscl_oen <= '0'; -- set SCL low
	                isda_oen <= '0'; -- keep SDA low
	                sda_chk  <= '0'; -- don't check SDA
                        s_state  <= idle;

	             -- stop
	             when stop_a =>
	                c_state  <= stop_b;
	                iscl_oen <= '0'; -- keep SCL low
	                isda_oen <= '0'; -- set SDA low
	                sda_chk  <= '0'; -- don't check SDA

	             when stop_b =>
	                c_state  <= stop_c;
	                iscl_oen <= '1'; -- set SCL high
	                isda_oen <= '0'; -- keep SDA low
	                sda_chk  <= '0'; -- don't check SDA

	             when stop_c =>
	                c_state  <= stop_d;
	                iscl_oen <= '1'; -- keep SCL high
	                isda_oen <= '0'; -- keep SDA low
	                sda_chk  <= '0'; -- don't check SDA

	             when stop_d =>
	                c_state  <= idle;
	                cmd_ack  <= '1'; -- command completed
	                iscl_oen <= '1'; -- keep SCL high
	                isda_oen <= '1'; -- set SDA high
	                sda_chk  <= '0'; -- don't check SDA
                        s_state  <= idle;

	             -- read
	             when rd_a =>
	                c_state  <= rd_b;
	                iscl_oen <= '0'; -- keep SCL low
	                isda_oen <= '1'; -- tri-state SDA
	                sda_chk  <= '0'; -- don't check SDA

	             when rd_b =>
	                c_state  <= rd_c;
	                iscl_oen <= '1'; -- set SCL high
	                isda_oen <= '1'; -- tri-state SDA
	                sda_chk  <= '0'; -- don't check SDA

	             when rd_c =>
	                c_state  <= rd_d;
	                iscl_oen <= '1'; -- keep SCL high
	                isda_oen <= '1'; -- tri-state SDA
	                sda_chk  <= '0'; -- don't check SDA

	             when rd_d =>
	                c_state  <= idle;
	                cmd_ack  <= '1'; -- command completed
	                iscl_oen <= '0'; -- set SCL low
	                isda_oen <= '1'; -- tri-state SDA
	                sda_chk  <= '0'; -- don't check SDA
                        s_state  <= idle;

	             -- write
	             when wr_a =>
	                c_state  <= wr_b;
	                iscl_oen <= '0'; -- keep SCL low
	                isda_oen <= din; -- set SDA
	                sda_chk  <= '0'; -- don't check SDA (SCL low)

	             when wr_b =>
	                c_state  <= wr_c;
	                iscl_oen <= '1'; -- set SCL high
	                isda_oen <= din; -- keep SDA
	                sda_chk  <= '0'; -- don't check SDA (allow signals to settle)

	             when wr_c =>
	                c_state  <= wr_d;
	                iscl_oen <= '1'; -- keep SCL high
	                isda_oen <= din; -- keep SDA
	                sda_chk  <= '1'; -- check SDA

	             when wr_d =>
	                c_state  <= idle;
	                cmd_ack  <= '1'; -- command completed
	                iscl_oen <= '0'; -- set SCL low
	                isda_oen <= din; -- keep SDA
	                sda_chk  <= '0'; -- don't check SDA (SCL low)
                        s_state  <= idle;

	             when others =>

	          end case;
	        end if;
	      end if;
	    end if;
	end process nxt_state_decoder;


	-- assign outputs
	scl_o   <= '0';
	scl_oen <= iscl_oen;
	sda_o   <= '0';
	sda_oen <= isda_oen;
end architecture structural;

