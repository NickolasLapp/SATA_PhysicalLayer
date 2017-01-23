LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
use ieee.std_logic_unsigned.all;

entity top is
    port(
        clk50 : in std_logic;           -- 50 MHz clock from AC18, driven by SL18860C
        cpu_rst_n : in std_logic;       -- CPU_RESETn pushbutton. (Debounce this). Pin AD27

        pll_refclk_150 : in std_logic;  -- 150MHz PLL refclk for XCVR design,
                                        -- driven by Si570 (need to change clock frequency with Clock Control GUI)

        rx_serial_data : in  std_logic_vector(1 downto 0); -- XCVR input serial line.
        tx_serial_data : out std_logic_vector(1 downto 0); -- XCVR output serial line

        USER_LED_FPGA0 : out std_logic -- LED0 for heartbeat
        );
END top;

architecture top_arch of top is


--    constant ALIGNp : std_logic_vector(31 downto 0) :=  x"7B4A4ABC";
    constant ALIGNp : std_logic_vector(31 downto 0) :=  x"BCBCBCBC";

    signal reset : std_logic;
    signal ledCount         : std_logic_vector(63 downto 0);


    signal bitslip_wait_CH1 : std_logic_vector(63 downto 0) := (others => '0');
    signal bitslip_wait_CH2 : std_logic_vector(63 downto 0) := (others => '0');


    -- Channel Specific Settings
    -------------------------------------------------------
    -- CH1
    signal tx_forceelecidle_CH1         : std_logic := '0';
    signal rx_runningdisp_CH1           : std_logic_vector(3 downto 0);
    signal rx_is_lockedtoref_CH1        : std_logic;
    signal rx_is_lockedtodata_CH1       : std_logic;
    signal rx_signaldetect_CH1          : std_logic;
    signal rx_bitslip_CH1               : std_logic := '0';
    signal rx_clkout_CH1                : std_logic := '0';
    signal tx_datak_CH1                 : std_logic_vector(3 downto 0)   := (others => '0');
    signal rx_parallel_data_CH1         : std_logic_vector(31 downto 0);
    signal tx_parallel_data_CH1         : std_logic_vector(31 downto 0);
    signal rx_datak_CH1                 : std_logic_vector(3 downto 0);

    -- CH2
    signal tx_forceelecidle_CH2         : std_logic := '0';
    signal rx_runningdisp_CH2           : std_logic_vector(3 downto 0);
    signal rx_is_lockedtoref_CH2        : std_logic;
    signal rx_is_lockedtodata_CH2       : std_logic;
    signal rx_signaldetect_CH2          : std_logic;
    signal rx_bitslip_CH2               : std_logic;
    signal rx_clkout_CH2                : std_logic;
    signal tx_datak_CH2                 : std_logic_vector(3 downto 0)   := (others => '0');
    signal rx_parallel_data_CH2         : std_logic_vector(31 downto 0);
    signal tx_parallel_data_CH2         : std_logic_vector(31 downto 0);
    signal rx_datak_CH2                 : std_logic_vector(3 downto 0);

    -- Channel Combined
    signal tx_ready                 : std_logic;
    signal rx_ready                 : std_logic;
    signal tx_forceelecidle         : std_logic_vector(1 downto 0);
    signal rx_runningdisp           : std_logic_vector(7 downto 0);
    signal rx_is_lockedtoref        : std_logic_vector(1 downto 0);
    signal rx_is_lockedtodata       : std_logic_vector(1 downto 0);
    signal rx_signaldetect          : std_logic_vector(1 downto 0);
    signal rx_bitslip               : std_logic_vector(1 downto 0);
    signal rx_clkout                : std_logic_vector(1 downto 0);
    signal tx_parallel_data         : std_logic_vector(63 downto 0);
    signal tx_datak                 : std_logic_vector(7 downto 0);
    signal rx_parallel_data         : std_logic_vector(63 downto 0);
    signal rx_datak                 : std_logic_vector(7 downto 0);

    -- Channel Independent Settings
    -------------------------------------------------------
    signal pll_locked               : std_logic;
    signal tx_clkout                : std_logic;
    signal reconfig_from_xcvr       : std_logic_vector(137 downto 0);
    signal reconfig_to_xcvr         : std_logic_vector(209 downto 0);
    signal reconfig_busy            : std_logic;

    component CustomPhy is
        port (
            phy_mgmt_clk             : in  std_logic;
            phy_mgmt_clk_reset       : in  std_logic;
            phy_mgmt_address         : in  std_logic_vector(8 downto 0);
            phy_mgmt_read            : in  std_logic;
            phy_mgmt_readdata        : out std_logic_vector(31 downto 0);
            phy_mgmt_waitrequest     : out std_logic;
            phy_mgmt_write           : in  std_logic;
            phy_mgmt_writedata       : in  std_logic_vector(31 downto 0);
            tx_ready                 : out std_logic;
            rx_ready                 : out std_logic;
            pll_ref_clk              : in  std_logic;
            tx_serial_data           : out std_logic_vector(1 downto 0);
            tx_forceelecidle         : in  std_logic_vector(1 downto 0);
            tx_bitslipboundaryselect : in  std_logic_vector(9 downto 0);
            pll_locked               : out std_logic;
            rx_serial_data           : in  std_logic_vector(1 downto 0);
            rx_runningdisp           : out std_logic_vector(7 downto 0);
            rx_is_lockedtoref        : out std_logic_vector(1 downto 0);
            rx_is_lockedtodata       : out std_logic_vector(1 downto 0);
            rx_signaldetect          : out std_logic_vector(1 downto 0);
            rx_bitslip               : in  std_logic_vector(1 downto 0);
            tx_clkout                : out std_logic;
            rx_clkout                : out std_logic_vector(1 downto 0);
            tx_parallel_data         : in  std_logic_vector(63 downto 0);
            tx_datak                 : in  std_logic_vector(7 downto 0);
            rx_parallel_data         : out std_logic_vector(63 downto 0);
            rx_datak                 : out std_logic_vector(7 downto 0);
            reconfig_from_xcvr       : out std_logic_vector(137 downto 0);
            reconfig_to_xcvr         : in  std_logic_vector(209 downto 0)
        );
    end component CustomPhy;

    component CustomPhy_Reconf is
        port (
            reconfig_busy             : out std_logic;
            mgmt_clk_clk              : in  std_logic;
            mgmt_rst_reset            : in  std_logic;
            reconfig_mgmt_address     : in  std_logic_vector(6 downto 0);
            reconfig_mgmt_read        : in  std_logic;
            reconfig_mgmt_readdata    : out std_logic_vector(31 downto 0);
            reconfig_mgmt_waitrequest : out std_logic;
            reconfig_mgmt_write       : in  std_logic;
            reconfig_mgmt_writedata   : in  std_logic_vector(31 downto 0);
            reconfig_to_xcvr          : out std_logic_vector(209 downto 0);
            reconfig_from_xcvr        : in  std_logic_vector(137 downto 0)
        );
    end component CustomPhy_Reconf;

    component Debounce is
      port(
        clk50      : in  std_logic;
        button     : in  std_logic;
        debounced  : out std_logic);
    end component Debounce;

    begin

    custom_1 : CustomPhy
        port  map(
            phy_mgmt_clk             => clk50,
            phy_mgmt_clk_reset       => reset,
            phy_mgmt_address         => (others => '0'),
            phy_mgmt_read            => '0',
            --phy_mgmt_readdata
            --phy_mgmt_waitrequest
            phy_mgmt_write           => '0',
            phy_mgmt_writedata       => (others => '0'),
            tx_ready                 => tx_ready,
            rx_ready                 => rx_ready,
            pll_ref_clk              => pll_refclk_150,
            tx_serial_data           => tx_serial_data,
            tx_forceelecidle         => tx_forceelecidle,
            tx_bitslipboundaryselect => (others => '0'),
            pll_locked               => pll_locked,
            rx_serial_data           => rx_serial_data,
            rx_runningdisp           => rx_runningdisp,
            rx_is_lockedtoref        => rx_is_lockedtoref,
            rx_is_lockedtodata       => rx_is_lockedtodata,
            rx_signaldetect          => rx_signaldetect,
            rx_bitslip               => rx_bitslip,
            tx_clkout                => tx_clkout,
            rx_clkout                => rx_clkout,
            tx_parallel_data         => tx_parallel_data,
            tx_datak                 => tx_datak,
            rx_parallel_data         => rx_parallel_data,
            rx_datak                 => rx_datak,
            reconfig_from_xcvr       => reconfig_from_xcvr,
            reconfig_to_xcvr         => reconfig_to_xcvr
        );

    reconf_1 : CustomPhy_Reconf
        port map (
            reconfig_busy             => reconfig_busy,
            mgmt_clk_clk              => clk50,
            mgmt_rst_reset            => reset,
            reconfig_mgmt_address     => (others => '0'),
            reconfig_mgmt_read        => '0',
            --reconfig_mgmt_readdata
            --reconfig_mgmt_waitrequest
            reconfig_mgmt_write       => '0',
            reconfig_mgmt_writedata   => (others => '0'),
            reconfig_to_xcvr          => reconfig_to_xcvr,
            reconfig_from_xcvr        => reconfig_from_xcvr
        );

    resetDebounce_0 : Debounce
        port map(clk50, not cpu_rst_n, reset);

    process(clk50, reset)
    begin
        if(rising_edge(clk50)) then
            if(reset = '1') then
                ledCount <= (others => '0');
            else
                ledCount <= ledCount+1;
            end if;
        end if;
    end process;

    USER_LED_FPGA0 <= not ledCount(26) or bitslip_wait_CH1(63);


    -- COMBINE SIGNALS
    ---------------------------------------------------------------------------
    tx_forceelecidle         <= tx_forceelecidle_CH1 & tx_forceelecidle_CH1;
    rx_runningdisp           <= rx_runningdisp_CH1 & rx_runningdisp_CH2;
    rx_is_lockedtoref        <= rx_is_lockedtoref_CH1 & rx_is_lockedtoref_CH2;
    rx_is_lockedtodata       <= rx_is_lockedtodata_CH1 & rx_is_lockedtodata_CH2;
    rx_signaldetect          <= rx_signaldetect_CH1 & rx_signaldetect_CH2;
    rx_bitslip               <= rx_bitslip_CH1 & rx_bitslip_CH2;
    rx_clkout                <= rx_clkout_CH1 & rx_clkout_CH2;
    tx_parallel_data         <= tx_parallel_data_CH1 & tx_parallel_data_CH2;
    tx_datak                 <= tx_datak_CH1 & tx_datak_CH2;
    rx_parallel_data         <= rx_parallel_data_CH1 & rx_parallel_data_CH2;
    rx_datak                 <= rx_datak_CH1 & rx_datak_CH2;

    tx_parallel_data_CH1     <= ALIGNp;
    tx_parallel_data_CH2     <= ALIGNp;

    process(rx_clkout_CH1, reset)
	begin
	    if(rising_edge(rx_clkout_CH1)) then
            if(reset = '1') then
                bitslip_wait_CH1 <= (others => '0');
            else
                if(not rx_parallel_data_CH1 = ALIGNp) then
                    if(bitslip_wait_CH1 > 60) then
                        rx_bitslip_CH1 <= '0';
                        bitslip_wait_CH1 <= (others => '0');
                    elsif(bitslip_wait_CH1 > 50) then
                        rx_bitslip_CH1 <= '1';
                        bitslip_wait_CH1 <= bitslip_wait_CH1 + 1;
                    else
                        rx_bitslip_CH1 <= '0';
                        bitslip_wait_CH1 <= bitslip_wait_CH1 + 1;
                    end if;
                else
                    rx_bitslip_CH1 <= '0';
                end if;
           end if;
        end if;
    end process;

	process(rx_clkout_CH2, reset)
    begin
        if(rising_edge(rx_clkout_CH2)) then
            if(reset = '1') then
                bitslip_wait_CH2 <= (others => '0');
            else
                if(not rx_parallel_data_CH2 = ALIGNp) then
                    if(bitslip_wait_CH2 > 60) then
                        bitslip_wait_CH2 <= (others => '0');
                        rx_bitslip_CH2 <= '0';
                    elsif(bitslip_wait_CH2 > 50) then
                        rx_bitslip_CH2 <= '1';
                        bitslip_wait_CH2 <= bitslip_wait_CH2 + 1;
                    else
                        rx_bitslip_CH2 <= '0';
                        bitslip_wait_CH2 <= bitslip_wait_CH2 + 1;
                    end if;
                else
                    rx_bitslip_CH2 <= '0';
                end if;
            end if;
        end if;
    end process;
end top_arch;