LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

entity top is
    port(
        clk50 : in std_logic;           -- 50 MHz clock from AC18, driven by SL18860C
        cpu_rst_n : in std_logic;       -- CPU_RESETn pushbutton. (Debounce this). Pin AD27

        pll_refclk_150 : in std_logic;  -- 150MHz PLL refclk for XCVR design,
                                        -- driven by Si570 (need to change clock frequency with Clock Control GUI)


        rx_serial_data : in std_logic;  -- XCVR input serial line

        tx_serial_data : out std_logic -- XCVR output serial line


        );
END top;

architecture top_arch of top is
    signal reset : std_logic;
    signal tx_ready : std_logic;
    signal rx_ready : std_logic;
    signal tx_forceelecidle : std_logic := '0';
    signal pll_locked       : std_logic;
    signal rx_runningdisp : std_logic_vector(3 downto 0);

    signal rx_is_lockedtoref        : std_logic;
    signal rx_is_lockedtodata       : std_logic;
    signal rx_signaldetect          : std_logic;
    signal rx_bitslip               : std_logic;
    signal tx_clkout                : std_logic;
    signal rx_clkout                : std_logic;

    signal tx_parallel_data         : std_logic_vector(31 downto 0);
    signal tx_datak                 : std_logic_vector(3 downto 0)   := (others => '0');
    signal rx_parallel_data         : std_logic_vector(31 downto 0);
    signal rx_datak                 : std_logic_vector(3 downto 0);
    signal reconfig_from_xcvr       : std_logic_vector(91 downto 0);
    signal reconfig_to_xcvr         : std_logic_vector(139 downto 0) := (others => '0');

    signal reconfig_busy            : std_logic;

    component CustomPhy is
        port (
            phy_mgmt_clk             : in  std_logic                      := '0';             --             phy_mgmt_clk.clk
            phy_mgmt_clk_reset       : in  std_logic                      := '0';             --       phy_mgmt_clk_reset.reset
            phy_mgmt_address         : in  std_logic_vector(8 downto 0)   := (others => '0'); --                 phy_mgmt.address
            phy_mgmt_read            : in  std_logic                      := '0';             --                         .read
            phy_mgmt_readdata        : out std_logic_vector(31 downto 0);                     --                         .readdata
            phy_mgmt_waitrequest     : out std_logic;                                         --                         .waitrequest
            phy_mgmt_write           : in  std_logic                      := '0';             --                         .write
            phy_mgmt_writedata       : in  std_logic_vector(31 downto 0)  := (others => '0'); --                         .writedata
            tx_ready                 : out std_logic;                                         --                 tx_ready.export
            rx_ready                 : out std_logic;                                         --                 rx_ready.export
            pll_ref_clk              : in  std_logic;                                         --              pll_ref_clk.clk
            tx_serial_data           : out std_logic;                                         --           tx_serial_data.export
            tx_forceelecidle         : in  std_logic;                                         --         tx_forceelecidle.export
            tx_bitslipboundaryselect : in  std_logic_vector(4 downto 0)   := (others => '0'); -- tx_bitslipboundaryselect.export
            pll_locked               : out std_logic;                                         --               pll_locked.export
            rx_serial_data           : in  std_logic;                                         --           rx_serial_data.export
            rx_runningdisp           : out std_logic_vector(3 downto 0);                      --           rx_runningdisp.export
            rx_is_lockedtoref        : out std_logic;                                         --        rx_is_lockedtoref.export
            rx_is_lockedtodata       : out std_logic;                                         --       rx_is_lockedtodata.export
            rx_signaldetect          : out std_logic;                                         --          rx_signaldetect.export
            rx_bitslip               : in  std_logic;                                         --               rx_bitslip.export
            tx_clkout                : out std_logic;                                         --                tx_clkout.export
            rx_clkout                : out std_logic;                                         --                rx_clkout.export
            tx_parallel_data         : in  std_logic_vector(31 downto 0)  := (others => '0'); --         tx_parallel_data.export
            tx_datak                 : in  std_logic_vector(3 downto 0)   := (others => '0'); --                 tx_datak.export
            rx_parallel_data         : out std_logic_vector(31 downto 0);                     --         rx_parallel_data.export
            rx_datak                 : out std_logic_vector(3 downto 0);                      --                 rx_datak.export
            reconfig_from_xcvr       : out std_logic_vector(91 downto 0);                     --       reconfig_from_xcvr.reconfig_from_xcvr
            reconfig_to_xcvr         : in  std_logic_vector(139 downto 0) := (others => '0')  --         reconfig_to_xcvr.reconfig_to_xcvr
        );
    end component CustomPhy;

    component CustomPhy_Reconf is
        port (
            reconfig_busy             : out std_logic;                                         --      reconfig_busy.reconfig_busy
            mgmt_clk_clk              : in  std_logic                      := '0';             --       mgmt_clk_clk.clk
            mgmt_rst_reset            : in  std_logic                      := '0';             --     mgmt_rst_reset.reset
            reconfig_mgmt_address     : in  std_logic_vector(6 downto 0)   := (others => '0'); --      reconfig_mgmt.address
            reconfig_mgmt_read        : in  std_logic                      := '0';             --                   .read
            reconfig_mgmt_readdata    : out std_logic_vector(31 downto 0);                     --                   .readdata
            reconfig_mgmt_waitrequest : out std_logic;                                         --                   .waitrequest
            reconfig_mgmt_write       : in  std_logic                      := '0';             --                   .write
            reconfig_mgmt_writedata   : in  std_logic_vector(31 downto 0)  := (others => '0'); --                   .writedata
            reconfig_to_xcvr          : out std_logic_vector(139 downto 0);                    --   reconfig_to_xcvr.reconfig_to_xcvr
            reconfig_from_xcvr        : in  std_logic_vector(91 downto 0)  := (others => '0')  -- reconfig_from_xcvr.reconfig_from_xcvr
        );
    end component CustomPhy_Reconf;

    component Debounce is
      port(
        clk50      : in  std_logic;
        button     : in  std_logic;
        debounced  : out std_logic);
    end component Debounce;

    begin

    custom_0 : CustomPhy
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

    reconf_0 : CustomPhy_Reconf
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


end top_arch;