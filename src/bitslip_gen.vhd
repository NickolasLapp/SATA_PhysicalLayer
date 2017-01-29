library IEEE;
use IEEE.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use IEEE.numeric_std.all;

use work.sata_defines.all;

entity bitslip_gen is
    port(
        clk : in std_logic;
        reset: in std_logic;
        data_in : in std_logic_vector(31 downto 0);
        bitslip : out std_logic;
        bitslip_done : out std_logic
    );
end bitslip_gen;

architecture bitslip_gen_arch of bitslip_gen is
    constant DELAY_0 : std_logic_vector(15 downto 0) := x"0020";

    type state_type is (IDLE, CHECK_SYNC, ASSERT_BITSLIP, WAIT_0, DEASSERT_BITSLIP, BITSLIP_SEQ_DONE);
    signal state : state_type;
    signal next_state : state_type;

    signal counter_0 : std_logic_vector(15 downto 0);

    signal bitslip_sig : std_logic;
    signal bitslip_reg : std_logic;
    signal bitslip_done_reg : std_logic;
    signal start_count : std_logic;
    signal count_val  : std_logic_vector(15 downto 0);

    signal count_done : std_logic;

    begin

    count_done <= '1' when counter_0 = count_val else '0';
    bitslip <= bitslip_reg;
    bitslip_done <= bitslip_done_reg;


    process(clk, reset)
    begin
        if(reset = '1') then
            counter_0 <= (others => '0');
        elsif(rising_edge(clk)) then
            if count_done = '1' then
                counter_0 <= (others => '0');
            elsif(start_count = '1') then
                counter_0 <= std_logic_vector (unsigned (counter_0) + 1);
            end if;
        end if;
    end process;

    process(clk, reset)
    begin
        if(reset = '1') then
            bitslip_reg <= '0';
        elsif (rising_edge(clk)) then
            if (state = ASSERT_BITSLIP or state = DEASSERT_BITSLIP) then
                bitslip_reg <= bitslip_sig;
            end if;
        end if;
    end process;

    process(clk, reset)
    begin
        if(reset = '1') then
            bitslip_done_reg <= '0';
        elsif (rising_edge(clk)) then
            if (state = BITSLIP_SEQ_DONE) then
                bitslip_done_reg <= '1';
            else
                bitslip_done_reg <= '0';
            end if;
        end if;
    end process;


    process(clk, reset)
    begin
        if(reset = '1') then
            state <= IDLE;
        elsif(rising_edge(clk)) then
            state <= next_state;
        end if;
    end process;


    bitslip_sig <= '1' when state = ASSERT_BITSLIP else '0';

    process(state, count_done, data_in)
    begin
        case state is
            when IDLE =>
                            next_state <= CHECK_SYNC;

            when CHECK_SYNC =>
                            if (data_in(7 downto 0) = SYNC_PATTERN or
                                data_in(15 downto 8) = SYNC_PATTERN or
                                data_in(23 downto 16) = SYNC_PATTERN or
                                data_in(31 downto 24) = SYNC_PATTERN) then
                                next_state <= BITSLIP_SEQ_DONE;
                            elsif (data_in = x"000000000") then
                                next_state <= CHECK_SYNC;
                            else
                                next_state <= ASSERT_BITSLIP;
                            end if;

            when ASSERT_BITSLIP =>
                            --bitslip_sig <= '1';
                            next_state <= WAIT_0;

            when WAIT_0 =>
                            start_count <= '1';
                            count_val <= DELAY_0;
                            if (count_done = '1') then
                                next_state <= DEASSERT_BITSLIP;
                            else
                                next_state <= WAIT_0;
                            end if;

            when DEASSERT_BITSLIP =>
                            --bitslip_sig <= '0';
                            next_state <= CHECK_SYNC;

            when BITSLIP_SEQ_DONE =>
                            next_state <= BITSLIP_SEQ_DONE;

            when others =>
                            next_state <= IDLE;
        end case;
    end process;

end architecture bitslip_gen_arch;