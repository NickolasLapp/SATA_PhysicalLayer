library ieee;
use ieee.std_logic_1164.ALL;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.sata_defines.all;

entity ppm_detector is
    port(
        fabric_clk: in std_logic;
        rxclkout  : in std_logic;
        rst       : in std_logic;

        ppm_within_threshold : out std_logic
        );
END ppm_detector;


architecture rtl of ppm_detector is
    constant PPM_DETECT_NOM : std_logic_vector(15 downto 0) := x"0400";
    constant PPM_DETECT_MAX : std_logic_vector(15 downto 0) := x"0410";
    constant PPM_DETECT_MIN : std_logic_vector(15 downto 0) := x"0390";
    constant NUM_SYNC_STAGES: integer := 3;

    type sync_arr is array(0 to NUM_SYNC_STAGES) of std_logic;

    signal fabric_count : std_logic_vector(15 downto 0);
    signal rx_clk_count : std_logic_vector(15 downto 0);

    signal fabric_rollover : std_logic;
    signal fabric_rollover_sync : sync_arr;
    signal fabric_rollover_sync_prev : std_logic;

begin

    process(fabric_clk, rst)
    begin
        if(rst='1') then
            fabric_count <= (others => '0');
            fabric_rollover <= '0';
        elsif(rising_edge(fabric_clk)) then
            if(fabric_count < PPM_DETECT_NOM) then
                fabric_count <= fabric_count + '1';
                fabric_rollover <= fabric_rollover;
            else --(fabric_count = PPM_DETECT_NOM) then
                fabric_count <= (others => '0');
                fabric_rollover <= not fabric_rollover;
            end if;
        end if;
    end process;

    process(rxclkout, rst)
    begin
        if(rst='1') then
            rx_clk_count <= (others => '0');
            ppm_within_threshold <= '0';
            fabric_rollover_sync(0 to NUM_SYNC_STAGES) <= (others => '0');
            fabric_rollover_sync_prev <= '0';
        elsif(rising_edge(rxclkout)) then
            fabric_rollover_sync(0) <= fabric_rollover;
            for I in 0 to NUM_SYNC_STAGES-1 loop
                fabric_rollover_sync(I+1) <= fabric_rollover_sync(I);
            end loop;

            fabric_rollover_sync_prev <= fabric_rollover_sync(NUM_SYNC_STAGES);

            if(fabric_rollover_sync(NUM_SYNC_STAGES) = fabric_rollover_sync_prev) then -- no count rollover yet
                rx_clk_count <= rx_clk_count + '1';
            else -- rollover detected!
                rx_clk_count <= (others => '0');
                if(rx_clk_count-(NUM_SYNC_STAGES+1) < PPM_DETECT_MAX and rx_clk_count-(NUM_SYNC_STAGES+1) > PPM_DETECT_MIN) then
                    ppm_within_threshold <= '1';
                else
                    ppm_within_threshold <= '0';
                end if;
            end if;
        end if;
    end process;

end rtl;