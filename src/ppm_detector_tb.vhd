library ieee;
use ieee.std_logic_1164.ALL;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.sata_defines.all;

entity ppm_detector_tb is
end entity ppm_detector_tb;

architecture behavioral of ppm_detector_tb is

    signal fabric_clk : std_logic := '0';
    signal rxclkout: std_logic := '0';
    signal ppm_within_threshold: std_logic := '0';
    signal rst        : std_logic := '0';

    constant CLK75_PERIOD : time := 20.1 ns;
    constant RxClkoutPeriod : time := 20 ns;

    component ppm_detector is
        port(
            fabric_clk: in std_logic;
            rxclkout  : in std_logic;
            rst       : in std_logic;

            ppm_within_threshold : out std_logic
            );
    end component ppm_detector;
begin

    dut : ppm_detector
        port map(
            fabric_clk => fabric_clk,
            rxclkout => rxclkout,
            rst        => rst,

            ppm_within_threshold => ppm_within_threshold
            );

    -- Clock generation
    fabric_clk <= not fabric_clk after CLK75_PERIOD/2 when rst = '0' else '0';
    rxclkout   <= not rxclkout after RxClkoutPeriod/2 when rst = '0' else '0';

    stimuli : process
    begin
        rst <= '1';
        wait for 10 us;
        rst <= '0';
        wait for 1000 ms;
    end process;
end architecture behavioral;