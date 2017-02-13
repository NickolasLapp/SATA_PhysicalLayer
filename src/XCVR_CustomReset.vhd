library ieee;
use ieee.std_logic_1164.ALL;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.sata_defines.all;

entity XCVR_CustomReset is
    port (
        clk50           : in std_logic;
        master_reset    : in std_logic;

-- RESET Signals
        pll_powerdown   : out std_logic;
        tx_digitalreset : out std_logic;
--        tx_analogreset  : out std_logic; -- not needed?
        rx_analogreset  : out std_logic;
        rx_digitalreset : out std_logic;

-- CDR Control Signals
        rx_locktorefclk : out std_logic;
        rx_locktodata   : out std_logic;

-- Output Status Signals
        busy            : in std_logic;
        pll_locked      : in std_logic;
        oob_handshake_done : in std_logic

    );
end entity XCVR_CustomReset;

architecture XCVR_CustomReset_arch of XCVR_CustomReset is

    constant CLOCK_FREQUENCY_MHZ : integer     := 50; -- 50 MHz core clock
    constant FOUR_MICRO_SEC_COUNT: integer     := 4 * CLOCK_FREQUENCY_MHZ;
    constant TWO_MICRO_SEC_COUNT : integer     := 2 * CLOCK_FREQUENCY_MHZ;
    constant ONE_MICRO_SEC_COUNT : integer     := 1 * CLOCK_FREQUENCY_MHZ;
    constant AFTER_BUSY_PAUSE    : integer     := 5;

    signal timer : std_logic_vector(9 downto 0);
    type   RESET_STATE_TYPE is (R1_PLL_POWERDOWN,
                                R2_WAIT_PLL_LOCKED,
                                R3_PLL_LOCKED_DONE,
                                R4_IDLE_DONE,
                                R5_WAIT_OOB_HANDSHAKE,
                                R6_OOB_HANDSHAKE_DONE,
                                R7_OOB_HANDSHAKE_DELAY_DONE,
                                R8_RESET_COMPLETE);

    signal reset_state : RESET_STATE_TYPE;
    signal reset_nextstate : RESET_STATE_TYPE;

begin

    -- State logic
    process(clk50, master_reset)
    begin
        if(master_reset = '1') then
            reset_state <= R1_PLL_POWERDOWN;
        elsif(rising_edge(clk50)) then
            reset_state <= reset_nextstate;
        end if;
    end process;

    -- Timer Logic
    process(clk50, master_reset)
    begin
        if(master_reset = '1') then
            timer <= (others => '0');
        elsif(rising_edge(clk50)) then
            if(reset_state = reset_nextstate) then
                timer <= timer + 1;
            else
                timer <= (others => '0');
            end if;
        end if;
    end process;

    -- Next state logic
    process(timer, master_reset, busy, pll_locked, reset_state, oob_handshake_done)
    begin
        case reset_state is
            when R1_PLL_POWERDOWN            =>
                if(timer > ONE_MICRO_SEC_COUNT) then
                    reset_nextstate <= R2_WAIT_PLL_LOCKED;
                else
                    reset_nextstate <= R1_PLL_POWERDOWN;
                end if;

            when R2_WAIT_PLL_LOCKED          =>
                if(pll_locked = '1') then
                    reset_nextstate <= R3_PLL_LOCKED_DONE;
                else
                    reset_nextstate <= R2_WAIT_PLL_LOCKED;
                end if;

            when R3_PLL_LOCKED_DONE          =>
                if(busy = '1') then
                    reset_nextstate <= R3_PLL_LOCKED_DONE;
                else
                    reset_nextstate <= R4_IDLE_DONE;
                end if;

            when R4_IDLE_DONE                =>
                if(timer > AFTER_BUSY_PAUSE) then
                    reset_nextstate <= R5_WAIT_OOB_HANDSHAKE;
                else
                    reset_nextstate <= R4_IDLE_DONE;
                end if;

            when R5_WAIT_OOB_HANDSHAKE       =>
                if(oob_handshake_done = '1') then
                    reset_nextstate <= R6_OOB_HANDSHAKE_DONE;
                else
                    reset_nextstate <= R5_WAIT_OOB_HANDSHAKE;
                end if;

            when R6_OOB_HANDSHAKE_DONE       =>
                if(timer > ONE_MICRO_SEC_COUNT) then
                    reset_nextstate <= R7_OOB_HANDSHAKE_DELAY_DONE;
                else
                    reset_nextstate <= R6_OOB_HANDSHAKE_DONE;
                end if;

            when R7_OOB_HANDSHAKE_DELAY_DONE =>
                if(timer > FOUR_MICRO_SEC_COUNT) then
                    reset_nextstate <= R8_RESET_COMPLETE;
                else
                    reset_nextstate <= R7_OOB_HANDSHAKE_DELAY_DONE;
                end if;

            when R8_RESET_COMPLETE           =>
                reset_nextstate <= reset_nextstate;

            when others                      =>
                reset_nextstate <= R1_PLL_POWERDOWN;
        end case;
end process;

    -- Output Logic
    process(clk50, master_reset)
    begin
        if(master_reset = '1') then
            pll_powerdown   <= '1';
            tx_digitalreset <= '1';
            rx_analogreset  <= '1';
            rx_digitalreset <= '1';
            rx_locktorefclk <= '1';
            rx_locktodata   <= '0';
        elsif(rising_edge(clk50)) then
            case reset_state is
                when R1_PLL_POWERDOWN            =>
                    pll_powerdown   <= '1';
                    tx_digitalreset <= '1';
                    rx_analogreset  <= '1';
                    rx_digitalreset <= '1';
                    rx_locktorefclk <= '1';
                    rx_locktodata   <= '0';

                when R2_WAIT_PLL_LOCKED          =>
                    pll_powerdown   <= '0';
                    tx_digitalreset <= '1';
                    rx_analogreset  <= '1';
                    rx_digitalreset <= '1';
                    rx_locktorefclk <= '1';
                    rx_locktodata   <= '0';

                when R3_PLL_LOCKED_DONE          =>
                    pll_powerdown   <= '0';
                    tx_digitalreset <= '0';
                    rx_analogreset  <= '1';
                    rx_digitalreset <= '1';
                    rx_locktorefclk <= '1';
                    rx_locktodata   <= '0';

                when R4_IDLE_DONE                =>
                    pll_powerdown   <= '0';
                    tx_digitalreset <= '0';
                    rx_analogreset  <= '1';
                    rx_digitalreset <= '1';
                    rx_locktorefclk <= '1';
                    rx_locktodata   <= '0';

                when R5_WAIT_OOB_HANDSHAKE       =>
                    pll_powerdown   <= '0';
                    tx_digitalreset <= '0';
                    rx_analogreset  <= '0';
                    rx_digitalreset <= '1';
                    rx_locktorefclk <= '1';
                    rx_locktodata   <= '0';

                when R6_OOB_HANDSHAKE_DONE       =>
                    pll_powerdown   <= '0';
                    tx_digitalreset <= '0';
                    rx_analogreset  <= '0';
                    rx_digitalreset <= '1';
                    rx_locktorefclk <= '1';
                    rx_locktodata   <= '0';

                when R7_OOB_HANDSHAKE_DELAY_DONE =>
                    pll_powerdown   <= '0';
                    tx_digitalreset <= '0';
                    rx_analogreset  <= '0';
                    rx_digitalreset <= '1';
                    rx_locktorefclk <= '0';
                    rx_locktodata   <= '1';

                when R8_RESET_COMPLETE           =>
                    pll_powerdown   <= '0';
                    tx_digitalreset <= '0';
                    rx_analogreset  <= '0';
                    rx_digitalreset <= '0';
                    rx_locktorefclk <= '0';
                    rx_locktodata   <= '1';

                when others                      =>
                    pll_powerdown   <= '1';
                    tx_digitalreset <= '1';
                    rx_analogreset  <= '1';
                    rx_digitalreset <= '1';
                    rx_locktorefclk <= '1';
                    rx_locktodata   <= '0';
            end case;
        end if;
    end process;

end architecture XCVR_CustomReset_arch;