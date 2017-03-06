-- Hannah D. Mohr
-- 02/08/2017
-- This test bench runs the Link Layer through a basic write followed by a basic read of the same data (encoded) with the CRC appended.
-- This test is under optimal condition, where there are no pauses, holds, or errors interrupting the data
-- The expected outcome of this test bench is that the read will move into states GoodCRC and GoodEnd after showing the 1, 2, 3, 4 output data values
-- Note that the read is initiated by the Physical Layer. It needs to be determined how the Physical Layer knows to send X_RDYp

library IEEE;
use IEEE.std_logic_1164.all;
use work.sata_defines.all;
use ieee.numeric_std.all;

entity link_layer_32bit_TB is
end entity;

architecture link_layer_32bit_TB_arch of link_layer_32bit_TB is

  constant t_clk_per : time := 50 ns;

  component link_layer_32bit
   port(-- Input
			clk				:	in std_logic;
			rst_n			:	in std_logic;

			--Interface with Transport Layer
			trans_status_in :	in std_logic_vector(7 downto 0);		-- [FIFO_RDY/n, transmit request, data complete, escape, bad FIS, error, good FIS]
			trans_status_out:	out std_logic_vector(6 downto 0);		-- [Link Idle, transmit bad status, transmit good status, crc good/bad, comm error, fail transmit]
			tx_data_in		:	in std_logic_vector(31 downto 0);
			rx_data_out		:	out std_logic_vector(31 downto 0);

			--Interface with Physical Layer
			tx_data_out		:	out std_logic_vector(31 downto 0);
			rx_data_in		:	in std_logic_vector(31 downto 0);
			phy_status_in	:	in std_logic_vector(3 downto 0);		-- [primitive, PHYRDY/n, Dec_Err]
			phy_status_out	:	out std_logic_vector(1 downto 0);		-- [primitive, clear status signals]
			perform_init	:	out std_logic);
  end component;


 -- Test bench signals
  signal clk_TB   				: std_logic;
  signal rst_n_TB 				: std_logic;

  signal trans_status_in_TB  	: std_logic_vector(7 downto 0);
  signal trans_status_out_TB  	: std_logic_vector(6 downto 0);
  signal tx_data_in_TB			: std_logic_vector(31 downto 0);
  signal rx_data_out_TB			: std_logic_vector(31 downto 0);

  signal tx_data_out_TB			: std_logic_vector(31 downto 0);
  signal rx_data_in_TB			: std_logic_vector(31 downto 0);
  signal phy_status_in_TB		: std_logic_vector(3 downto 0);		-- [PHYRDY/n, Dec_Err]
  signal phy_status_out_TB		: std_logic_vector(1 downto 0);		-- [clear status signals]
  signal perform_init_TB 		: std_logic;

	signal counter_temp : integer;
signal counter : std_logic_vector(31 downto 0);
signal start : std_logic;

begin

  DUT1 : link_layer_32bit port map (
			-- Input
			clk					=> clk_TB,
			rst_n				=> rst_n_TB,

			--Interface with Transport Layer
			trans_status_in 	=> trans_status_in_TB,
			trans_status_out	=> trans_status_out_TB,
			tx_data_in			=> tx_data_in_TB,
			rx_data_out			=> rx_data_out_TB,

			--Interface with Physical Layer
			tx_data_out			=> tx_data_out_TB,
			rx_data_in			=> rx_data_in_TB,
			phy_status_in		=> phy_status_in_TB,
			phy_status_out		=> phy_status_out_TB,
			perform_init		=> perform_init_TB);

-----------------------------------------------
      CLOCK_STIM : process
       begin
          clk_TB <= '0'; wait for 0.5*t_clk_per;
          clk_TB <= '1'; wait for 0.5*t_clk_per;
       end process;
-----------------------------------------------
      RESET_STIM : process
       begin
          rst_n_TB <= '0'; wait for 1.5*t_clk_per;
          rst_n_TB <= '1'; wait;
       end process;
-----------------------------------------------



counter_process : PROCESS(clk_TB, rst_n_TB)
		BEGIN
			IF(rst_n_TB = '0') THEN
				counter_temp <= 0;
			ELSIF(clk_TB 'EVENT AND clk_TB = '1') THEN
				IF(start = '1') THEN
					counter<= std_logic_vector(to_unsigned(counter_temp,32));
					counter_temp <= counter_temp + 1;
				END IF;
			END IF;
	END PROCESS;

	  DIN_STIM : process
       begin
			-- reset
			trans_status_in_TB 			<= "00000000";
			phy_status_in_TB 			<= "0000";
			rx_data_in_TB 				<= x"00000000";
			tx_data_in_TB 				<= x"00000000";
			start <= '0';

			wait for 3.5*t_clk_per; 					-- wait for reset

			-- initialize
			phy_status_in_TB(c_l_phyrdy) 		<= '1';			-- PHYRDY
			wait for 3.0*t_clk_per; 					-- SendAlign, Idle

			wait for 3.5*t_clk_per; 					-- reset occurring
			-- initialize
			phy_status_in_TB(1) 		<= '1';			-- PHYRDY
			wait for 3.0*t_clk_per; 					-- SendAlign, Idle

			-- start write
			trans_status_in_TB(5)	 	<= '1';			-- Transport Request
			wait for 1.0*t_clk_per;
			trans_status_in_TB(5) 		<= '0';
			rx_data_in_TB				<= R_RDYp;
			trans_status_in_TB(4) 		<= '1';			-- more data
			wait for 2.0*t_clk_per;						-- state transition
			-- send data
			start <= '1';
			tx_data_in_TB				<= counter;
			wait for 1.0*t_clk_per;
			trans_status_in_TB(4) 		<= '0';			-- data done
			-- wait for CRC
			wait for 2.0*t_clk_per;
			-- Physical received data
			rx_data_in_TB				<= R_OKp;


            wait;
       end process;

end architecture;

