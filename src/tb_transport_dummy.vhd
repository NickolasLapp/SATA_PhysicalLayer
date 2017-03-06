library ieee;
use ieee.std_logic_1164.ALL;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.sata_defines.all;

entity tb_transport_dummy is

end entity tb_transport_dummy;

architecture behavioral of tb_transport_dummy is

    component transport_dummy is
        port(
                fabric_clk          :   in std_logic;
                reset               :   in std_logic;

                --Interface with link Layer
                trans_status_to_link:   out std_logic_vector(7 downto 0);  -- [FIFO_RDY/n, transmit request, data complete, escape, bad FIS, error, good FIS]
                link_status_to_trans:   in  std_logic_vector(6 downto 0);  -- [Link Idle, transmit bad status, transmit good status, crc good/bad, comm error, fail transmit]
                tx_data_to_link     :   out std_logic_vector(31 downto 0);
                rx_data_from_link   :   in  std_logic_vector(31 downto 0)
                );
    end component transport_dummy;

    signal fabric_clk : std_logic := '0';
    signal rst        : std_logic := '0';

    signal trans_status_to_link : std_logic_vector(7 downto 0);
    signal link_status_to_trans : std_logic_vector(6 downto 0);
    signal tx_data_to_link      : std_logic_vector(31 downto 0);
    signal rx_data_from_link    : std_logic_vector(31 downto 0);

    constant CLK75_PERIOD : time := 20 ns;
begin


    dut : transport_dummy
    port map(
            fabric_clk => fabric_clk,
            reset      => rst,
            trans_status_to_link => trans_status_to_link,
            link_status_to_trans => link_status_to_trans,
            tx_data_to_link => tx_data_to_link,
            rx_data_from_link => rx_data_from_link
        );

    -- Clock generation
    fabric_clk <= not fabric_clk after CLK75_PERIOD/2 when rst = '1' else '0';

    stimuli : process
    begin
        link_status_to_trans <= (others => '0');
        rst <= '0';
        wait for 100 ns;
        rst <= '1';
        wait until rising_edge(fabric_clk);
        link_status_to_trans(5) <= '1';
        wait until rising_edge(fabric_clk);
        wait until trans_status_to_link(5) = '0';
        link_status_to_trans(5) <= '0';
        wait for 200 ns;
        wait until rising_edge(fabric_clk);
        rx_data_from_link <= x"00000039";
        wait until rising_edge(fabric_clk);
        rx_data_from_link <= x"00000000";
        wait until trans_status_to_link(5) = '1';
        wait until rising_edge(fabric_clk);
        wait until rising_edge(fabric_clk);
        link_status_to_trans(5) <= '1';
        wait until rising_edge(fabric_clk);
        
        wait for 1000 ms;

    end process;

end behavioral;