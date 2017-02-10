library ieee;
use ieee.std_logic_1164.ALL;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.sata_defines.all;

entity word_aligner is
    port(
        rxclkout         : in  std_logic;
        reset            : in  std_logic;
        do_word_align    : in  std_logic;

        rx_parallel_data : in  std_logic_vector(31 downto 0);
        rx_datak         : in  std_logic_vector(3 downto 0);

        is_word_aligned  : out std_logic;
        rx_aligned_data  : out std_logic_vector(31 downto 0)
    );
end entity word_aligner;

architecture word_aligner_arch of word_aligner is
    type align_buffer is array(7 downto 0) of std_logic_vector(7 downto 0);
    signal receive_word_buffer : align_buffer;
    signal rx_datak_prev : std_logic_vector(3 downto 0);
    signal aligned_datak : std_logic_vector(3 downto 0);
begin

    process(rxclkout, reset)
    begin
        if(reset = '1') then
            is_word_aligned <= '0';
            receive_word_buffer(7) <= (others => '0');
            receive_word_buffer(6) <= (others => '0');
            receive_word_buffer(5) <= (others => '0');
            receive_word_buffer(4) <= (others => '0');
            receive_word_buffer(3) <= (others => '0');
            receive_word_buffer(2) <= (others => '0');
            receive_word_buffer(1) <= (others => '0');
            receive_word_buffer(0) <= (others => '0');
            rx_datak_prev <= DATAK_BYTE_NONE;
         elsif(rising_edge(rxclkout)) then
            receive_word_buffer(3 downto 0) <= (rx_parallel_data(31 downto 24), rx_parallel_data(23 downto 16), rx_parallel_data(15 downto 8), rx_parallel_data(7 downto 0));
            receive_word_buffer(7 downto 4) <= receive_word_buffer(3 downto 0);
            rx_datak_prev <= rx_datak;

            if(do_word_align = '1') then
                if(rx_datak = rx_datak_prev and rx_datak /= DATAK_BYTE_NONE) then
                    is_word_aligned <= '1';
                    aligned_datak <= rx_datak;
                else
                    is_word_aligned <= '0';
                end if;
            end if;


            if(aligned_datak = DATAK_BYTE_ZERO)  then
                rx_aligned_data <= receive_word_buffer(7) & receive_word_buffer(6) & receive_word_buffer(5) & receive_word_buffer(4);
            elsif(aligned_datak = DATAK_BYTE_ONE)   then
                rx_aligned_data <= receive_word_buffer(0) & receive_word_buffer(7) & receive_word_buffer(6) & receive_word_buffer(5);
            elsif(aligned_datak = DATAK_BYTE_TWO)   then
                rx_aligned_data <= receive_word_buffer(1) & receive_word_buffer(0) & receive_word_buffer(7) & receive_word_buffer(6);
            elsif(aligned_datak = DATAK_BYTE_THREE) then
                rx_aligned_data <= receive_word_buffer(2) & receive_word_buffer(1) & receive_word_buffer(0) & receive_word_buffer(7);
            else
                rx_aligned_data <= (others => 'X');
            end if;
        end if;
    end process;
end architecture word_aligner_arch;