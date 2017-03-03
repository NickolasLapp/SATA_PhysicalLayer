library ieee;
use ieee.std_logic_1164.ALL;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.sata_defines.all;

entity rate_match_blk_tb is
end entity rate_match_blk_tb;

architecture rate_match_blk_tb_arch of rate_match_blk_tb is

    signal fabric_clk : std_logic := '0';
    signal rst        : std_logic := '0';

    -- from XCVR block
    signal rxclkout  : std_logic := '0';
    signal txclkout  : std_logic := '0';
    signal rx_data_from_phy : std_logic_vector(63 downto 0) := (others => '0');-- x"0000000a";
    signal rx_data_from_phy_data : std_logic_vector(31 downto 0);
    signal rx_data_from_phy_status : std_logic_vector(PHY_STATUS_LENGTH-1 downto 0);

    signal tx_data_to_phy : std_logic_vector(63 downto 0) := (others => '0');
    signal tx_data_to_phy_data : std_logic_vector(31 downto 0);
    signal tx_data_to_phy_status : std_logic_vector(LINK_STATUS_LENGTH-1 downto 0);

    -- to link layer
    signal rx_data_to_link    : std_logic_vector(63 downto 0) := (others => '0');
    signal rx_data_to_link_data: std_logic_vector(31 downto 0) := (others => '0');
    signal rx_data_to_link_status: std_logic_vector(PHY_STATUS_LENGTH-1 downto 0) := (others => '0');

    signal tx_data_from_link  : std_logic_vector(63 downto 0) := (others => '0');--x"00000001";
    signal tx_data_from_link_data  : std_logic_vector(31 downto 0) := (others => '0');--x"00000001";
    signal tx_data_from_link_status: std_logic_vector(LINK_STATUS_LENGTH-1 downto 0) := (others => '0');--x"00000001";

    constant TbPeriod : time := 20 ns;
    constant CLK75_PERIOD : time := 20 ns;
    constant RxClkoutPeriod : time := 20 ns;
    constant TxClkoutPeriod : time := 20 ns;
    signal TbSimEnded : std_logic := '0';


    component rate_match_blk
        port
        (
            fabric_clk : in std_logic;
            rst        : in std_logic;

            -- from XCVR block
            rxclkout  : in std_logic;
            txclkout  : in std_logic;
            rx_data_from_phy : in std_logic_vector(63 downto 0);
            tx_data_to_phy : out std_logic_vector(63 downto 0);

            -- to link layer
            rx_data_to_link    : out std_logic_vector(63 downto 0);
            tx_data_from_link  : in  std_logic_vector(63 downto 0)
        );
    end component;
begin

    dut : rate_match_blk
        port map(
            fabric_clk => fabric_clk,
            rst        => rst,

            -- from XCVR block
            rxclkout  => rxclkout,
            txclkout  => txclkout,
            rx_data_from_phy => rx_data_from_phy,
            tx_data_to_phy => tx_data_to_phy,

            -- to link layer
            rx_data_to_link    => rx_data_to_link,
            tx_data_from_link  => tx_data_from_link
            );

    -- Clock generation
    fabric_clk <= not fabric_clk after CLK75_PERIOD/2 when TbSimEnded /= '1' and rst = '0' else '0';

    stimuli : process
    begin
        rst <= '1';
        wait for 1000 ns;
        rst <= '0';
        wait for 1000 ms;
    end process;

    stimuli_rx : process
    begin
        rx_data_from_phy  <= x"0000000000000000";--(others => '0');
        rx_data_from_phy_data  <= (others => '0');
        rx_data_from_phy_status(PHY_STATUS_LENGTH-1 downto 0) <= "0110";
        wait until rst = '0';
        for I in 0 to 30000 loop
            wait until rising_edge(rxclkout);
            if(I mod 255 < 2) then
                rx_data_from_phy <= ALIGNp & x"00000000";
                rx_data_from_phy_data <= ALIGNp;
            elsif(I mod 255 = 2) then
                rx_data_from_phy <= (others => '0');
                rx_data_from_phy(63 downto 32) <= (others => '0');
                rx_data_from_phy(PHY_STATUS_LENGTH-1 downto 0) <= rx_data_from_phy_status;
            else
                rx_data_from_phy_data <= rx_data_from_phy_data + '1';
                rx_data_from_phy(63 downto 32) <= (rx_data_from_phy_data + '1');
                rx_data_from_phy(PHY_STATUS_LENGTH-1 downto 0) <= rx_data_from_phy_status;
            end if;
        end loop;
    end process;

    stimuli_tx : process
    begin
        tx_data_from_link <= x"0000000000000000";
        wait until rst = '0';
        for I in 0 to 30000 loop
            wait until rising_edge(fabric_clk);
            if(rx_data_to_link(c_l_pause_all) /= '1' and rx_data_to_link(c_l_phyrdy) = '1') then
                tx_data_from_link(63 downto 32) <= tx_data_from_link_data + '1';
                tx_data_from_link_data <= tx_data_from_link_data + '1';
            end if;
        end loop;
    end process;

    rx_data_to_link_data <= rx_data_to_link(63 downto 32);
    rx_data_to_link_status <= rx_data_to_link(PHY_STATUS_LENGTH-1 downto 0);


    tx_data_to_phy_data <= tx_data_to_phy(63 downto 32);
    tx_data_to_phy_status <= tx_data_to_phy(LINK_STATUS_LENGTH-1 downto 0);

    rxclkout <= not rxclkout after RxClkoutPeriod/2 when rst = '0' else '0';
    txclkout <= not txclkout after TxClkoutPeriod/2 when rst = '0' else '0';

end architecture rate_match_blk_tb_arch;