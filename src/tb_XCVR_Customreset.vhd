library ieee;
use ieee.std_logic_1164.ALL;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.sata_defines.all;

entity tb_XCVR_CustomReset is
end tb_XCVR_CustomReset;

architecture tb of tb_XCVR_CustomReset is

    component XCVR_CustomReset
        port (clk50              : in std_logic;
              master_reset       : in std_logic;
              pll_powerdown      : out std_logic;
              tx_digitalreset    : out std_logic;
              rx_analogreset     : out std_logic;
              rx_digitalreset    : out std_logic;
              rx_locktorefclk    : out std_logic;
              rx_locktodata      : out std_logic;
              busy               : in std_logic;
              pll_locked         : in std_logic;
              oob_handshake_done : in std_logic);
    end component;

    signal clk50              : std_logic;
    signal master_reset       : std_logic;
    signal pll_powerdown      : std_logic;
    signal tx_digitalreset    : std_logic;
    signal rx_analogreset     : std_logic;
    signal rx_digitalreset    : std_logic;
    signal rx_locktorefclk    : std_logic;
    signal rx_locktodata      : std_logic;
    signal busy               : std_logic;
    signal pll_locked         : std_logic;
    signal oob_handshake_done : std_logic;

    constant TbPeriod : time := 20 ns;
    signal TbClock : std_logic := '0';
    signal TbSimEnded : std_logic := '0';

begin

    dut : XCVR_CustomReset
    port map (clk50              => clk50,
              master_reset       => master_reset,
              pll_powerdown      => pll_powerdown,
              tx_digitalreset    => tx_digitalreset,
              rx_analogreset     => rx_analogreset,
              rx_digitalreset    => rx_digitalreset,
              rx_locktorefclk    => rx_locktorefclk,
              rx_locktodata      => rx_locktodata,
              busy               => busy,
              pll_locked         => pll_locked,
              oob_handshake_done => oob_handshake_done);

    -- Clock generation
    TbClock <= not TbClock after TbPeriod/2 when TbSimEnded /= '1' else '0';

    clk50 <= TbClock;

    stimuli : process
    begin

        busy <= '1';
        pll_locked <= '0';
        oob_handshake_done <= '0';

        master_reset <= '1';
        wait for 1000 ns;
        master_reset <= '0';
        wait for 10000 ns;
        pll_locked <= '1';
        wait until (tx_digitalreset'event and tx_digitalreset = '0');
        wait for 55 ns;
        busy <= '0';
        wait for 25000 ns;
        oob_handshake_done <= '1';
        wait for 1e6 ns;
        TbSimEnded <= '1';
        wait;
    end process;
end tb;
