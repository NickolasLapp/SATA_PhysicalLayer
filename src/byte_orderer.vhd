library ieee;
use ieee.std_logic_1164.ALL;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.sata_defines.all;

entity byte_orderer is
    port(
        rxclkout         : in  std_logic;
        reset            : in  std_logic;
        do_byte_order    : in  std_logic;

        rx_parallel_data : in  std_logic_vector(31 downto 0);
        rx_datak         : in  std_logic_vector(3 downto 0);

        is_byte_ordered  : out std_logic;
        rx_ordered_data  : out std_logic_vector(31 downto 0)
    );
end entity byte_orderer;

architecture byte_orderer_arch of byte_orderer is
    type order_buffer is array(7 downto 0) of std_logic_vector(7 downto 0);
    signal receive_byte_buffer : order_buffer;
    signal rx_datak_prev : std_logic_vector(3 downto 0);
    signal ordered_datak : std_logic_vector(3 downto 0);
begin

    process(rxclkout, reset)
    begin
        if(reset = '1') then
            is_byte_ordered <= '0';
            receive_byte_buffer(7) <= (others => '0');
            receive_byte_buffer(6) <= (others => '0');
            receive_byte_buffer(5) <= (others => '0');
            receive_byte_buffer(4) <= (others => '0');
            receive_byte_buffer(3) <= (others => '0');
            receive_byte_buffer(2) <= (others => '0');
            receive_byte_buffer(1) <= (others => '0');
            receive_byte_buffer(0) <= (others => '0');
            rx_datak_prev <= DATAK_BYTE_NONE;
         elsif(rising_edge(rxclkout)) then
            receive_byte_buffer(3 downto 0) <= (rx_parallel_data(31 downto 24), rx_parallel_data(23 downto 16), rx_parallel_data(15 downto 8), rx_parallel_data(7 downto 0));
            receive_byte_buffer(7 downto 4) <= receive_byte_buffer(3 downto 0);
            rx_datak_prev <= rx_datak;

            if(do_byte_order = '1') then
                if(rx_datak = rx_datak_prev and rx_datak /= DATAK_BYTE_NONE) then
                    is_byte_ordered <= '1';
                    ordered_datak <= rx_datak;
                else
                    is_byte_ordered <= '0';
                end if;
            end if;


            if(ordered_datak = DATAK_BYTE_ZERO)  then
                rx_ordered_data <= receive_byte_buffer(7) & receive_byte_buffer(6) & receive_byte_buffer(5) & receive_byte_buffer(4);
            elsif(ordered_datak = DATAK_BYTE_ONE)   then
                rx_ordered_data <= receive_byte_buffer(0) & receive_byte_buffer(7) & receive_byte_buffer(6) & receive_byte_buffer(5);
            elsif(ordered_datak = DATAK_BYTE_TWO)   then
                rx_ordered_data <= receive_byte_buffer(1) & receive_byte_buffer(0) & receive_byte_buffer(7) & receive_byte_buffer(6);
            elsif(ordered_datak = DATAK_BYTE_THREE) then
                rx_ordered_data <= receive_byte_buffer(2) & receive_byte_buffer(1) & receive_byte_buffer(0) & receive_byte_buffer(7);
            else
                rx_ordered_data <= (others => 'X');
            end if;
        end if;
    end process;
end architecture byte_orderer_arch;