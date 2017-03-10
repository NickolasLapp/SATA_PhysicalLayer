library ieee;
use ieee.std_logic_1164.ALL;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.sata_defines.all;

entity top is
    port(
        clk50 : in std_logic;           -- 50 MHz clock from AC18, driven by SL18860C
        cpu_rst_n : in std_logic;       -- CPU_RESETn pushbutton. (Debounce this). Pin AD27

        pll_refclk_150 : in std_logic;  -- 150MHz PLL refclk for XCVR design,
                                        -- driven by Si570 (need to change clock frequency with Clock Control GUI)
        rx_serial_data : in  std_logic; -- XCVR input serial line.
        tx_serial_data : out std_logic; -- XCVR output serial line

        USER_PB_FPGA1  : in  std_logic; -- PB1, used as alternative reset so that we can reset without resetting the clock control circuits
        USER_LED_FPGA0 : out std_logic  -- LED0 for heartbeat
        );
end top;

architecture top_arch of top is
    -- top level signals
    signal reset            : std_logic;
    signal cpu_rst          : std_logic;
    signal cpu_rst_debounced: std_logic;
    signal pb_fpga1         : std_logic;

    signal fabric_clk_37_5  : std_logic; -- use this to clock the receive datapath
    -- xcvr signals
    --PHY Control Signals
    signal rxclkout                : std_logic; -- use this to clock the receive datapath
    signal txclkout                : std_logic; -- use this to clock the transmit datapath
    signal pll_locked               : std_logic; -- is the pll reference clock locked in

    signal rx_data         : std_logic_vector(31 downto 0); -- received data
    signal tx_data         : std_logic_vector(31 downto 0); -- data to transmit

    signal tx_forceelecidle         : std_logic; -- force signal idle for OOB signaling
    signal rx_signaldetect          : std_logic; -- detect signal idle for OOB signaling
    signal rx_is_lockedtoref        : std_logic; -- receiver is locked to pll reference clock
    signal rx_is_lockedtodata       : std_logic; -- receiver is locked to CDR block from received data


    signal rx_pma_clkout            : std_logic; -- recovered clock from cdr circuitry.

    signal do_word_align            : std_logic; -- perform word alignment to the comma 28.5 character
    signal rx_patterndetect         : std_logic_vector(3 downto 0); -- are we detecting the comma character in received data?
    signal rx_syncstatus            : std_logic_vector(3 downto 0); -- are we synced to data? (why is this 4 bits wide...?)

    signal rx_errdetect             : std_logic_vector(3 downto 0); -- reports a 8B/10B Code violation
    signal rx_disperr               : std_logic_vector(3 downto 0); -- reports a 8B/10B Disparity Error

    signal tx_datak                 : std_logic_vector(3 downto 0); -- send control character on specified byte instead of data character (k28.5 instead of d28.5)
    signal rx_datak                 : std_logic_vector(3 downto 0); -- reports which bytes contained control characters

    signal tx_ready           : std_logic; -- is the transmitter ready
    signal rx_ready           : std_logic; -- is the receiver ready

    --rst signals
    signal pll_powerdown      : std_logic; --      pll_powerdown.pll_powerdown
    signal tx_analogreset     : std_logic; --     tx_analogreset.tx_analogreset
    signal tx_digitalreset    : std_logic; --    tx_digitalreset.tx_digitalreset
    signal rx_analogreset     : std_logic; --     rx_analogreset.rx_analogreset
    signal rx_digitalreset    : std_logic; --    rx_digitalreset.rx_digitalreset

    signal tx_cal_busy        : std_logic; --        tx_cal_busy.tx_cal_busy
    signal rx_cal_busy        : std_logic; --        rx_cal_busy.rx_cal_busy

    signal rx_set_locktodata  : std_logic;
    signal rx_set_locktoref   : std_logic;

    -- reconfig signals
    signal reconfig_from_xcvr       : std_logic_vector(91 downto 0);
    signal reconfig_to_xcvr         : std_logic_vector(139 downto 0);
    signal reconfig_busy            : std_logic;

    -- link/phy hookup signals
    signal phy_status_to_link       : std_logic_vector(PHY_STATUS_LENGTH-1 downto 0);
    signal link_status_to_phy       : std_logic_vector(LINK_STATUS_LENGTH-1 downto 0);
    signal tx_data_from_link        : std_logic_vector(31 downto 0);
    signal rx_data_to_link          : std_logic_vector(31 downto 0);

    signal trans_status_in          : std_logic_vector(7 downto 0);
    signal trans_status_out         : std_logic_vector(6 downto 0);
    signal trans_tx_data_in         : std_logic_vector(31 downto 0);
    signal trans_rx_data_out        : std_logic_vector(31 downto 0);
    signal rst_n                    : std_logic;

    component transport_dummy is
        port(
                fabric_clk          :   in std_logic;
                reset               :   in std_logic;

                --Interface with link Layer
                trans_status_to_link:   out std_logic_vector(7 downto 0);  -- [FIFO_RDY/n, transmit request, data complete, escape, bad FIS, error, good FIS]
                link_status_to_trans:   in  std_logic_vector(6 downto 0);  -- [Link Idle, transmit bad status, transmit good status, crc good/bad, comm error, fail transmit]
                tx_data_to_link     :   out std_logic_vector(31 downto 0);
                rx_data_from_link   :   in  std_logic_vector(31 downto 0)
                );
    end component transport_dummy;


    component link_layer_32bit is
    port(-- Input
            clk             :   in std_logic;
            rst_n           :   in std_logic;

            --Interface with Transport Layer
            trans_status_in :   in std_logic_vector(7 downto 0);        -- [FIFO_RDY/n, transmit request, data complete, escape, bad FIS, error, good FIS]
            trans_status_out:   out std_logic_vector(6 downto 0);       -- [Link Idle, transmit bad status, transmit good status, crc good/bad, comm error, fail transmit]
            tx_data_in      :   in std_logic_vector(31 downto 0);
            rx_data_out     :   out std_logic_vector(31 downto 0);

            --Interface with Physical Layer
            tx_data_out     :   out std_logic_vector(31 downto 0);
            rx_data_in      :   in std_logic_vector(31 downto 0);
            phy_status_in   :   in std_logic_vector(3 downto 0);        -- [primitive, PHYRDY/n, Dec_Err]
            phy_status_out  :   out std_logic_vector(1 downto 0);       -- [primitive, clear status signals]
            perform_init    :   out std_logic);
    end component;

    component phy_layer_32bit is
        port(
            fabric_clk_37_5 : in std_logic;           -- 50 MHz clock from AC18, driven by SL18860C
            reset         : in std_logic;       -- CPU_RESETn pushbutton. (Debounce this). Pin AD27

            --Interface with link layer
            tx_data_from_link:   in std_logic_vector(31 downto 0);
            rx_data_to_link  :   out std_logic_vector(31 downto 0);
            phy_status_to_link : out std_logic_vector(PHY_STATUS_LENGTH-1 downto 0);
            link_status_to_phy : in std_logic_vector(LINK_STATUS_LENGTH-1 downto 0);

    --        perform_init     :   out std_logic); -- currently unused

            --Interface with transceivers
            rxclkout         : in std_logic;   -- recovered rx clock to clock receive datapath from XCVRs
            txclkout         : in  std_logic;  -- tx clock from XCVRs to clock transmit datapath
            rx_pma_clkout    : in std_logic;                      --           rx_pma_clkout.rx_pma_clkout

            rx_data : in  std_logic_vector(31 downto 0); --raw received data from XCVRs
            rx_datak         : in  std_logic_vector(3 downto 0); --data or control symbol for receieved data
            rx_signaldetect  : in  std_logic; -- detect oob received oob signals

            rx_errdetect     : in std_logic_vector(3 downto 0);

            tx_forceelecidle : out std_logic; -- send oob signals
            tx_data : out std_logic_vector(31 downto 0); -- parallel data to transmit
            tx_datak         : out std_logic_vector(3 downto 0); -- data or control symbol for transmitted data

            do_word_align    : out std_logic; -- signal native phy to perform word align
            rx_syncstatus    : in std_logic_vector(3 downto 0); -- detect word alignment successfull

            rx_set_locktoref  : out std_logic; -- control transceiver locking characteristics
            rx_set_locktodata : out std_logic -- control transceiver locking characteristics
            );
    end component phy_layer_32bit;

    component NativePhy is
        port (
            pll_powerdown           : in  std_logic; --           pll_powerdown.pll_powerdown
            tx_analogreset          : in  std_logic; --          tx_analogreset.tx_analogreset
            tx_digitalreset         : in  std_logic; --         tx_digitalreset.tx_digitalreset
            tx_pll_refclk           : in  std_logic; --           tx_pll_refclk.tx_pll_refclk
            tx_serial_data          : out std_logic;                      --          tx_serial_data.tx_serial_data
            pll_locked              : out std_logic;                      --              pll_locked.pll_locked
            rx_analogreset          : in  std_logic; --          rx_analogreset.rx_analogreset
            rx_digitalreset         : in  std_logic; --         rx_digitalreset.rx_digitalreset
            rx_cdr_refclk           : in  std_logic; --           rx_cdr_refclk.rx_cdr_refclk
            rx_pma_clkout           : out std_logic;                      --           rx_pma_clkout.rx_pma_clkout
            rx_serial_data          : in  std_logic; --          rx_serial_data.rx_serial_data
            rx_set_locktodata       : in  std_logic; --       rx_set_locktodata.rx_set_locktodata
            rx_set_locktoref        : in  std_logic; --        rx_set_locktoref.rx_set_locktoref
            rx_is_lockedtoref       : out std_logic;                      --       rx_is_lockedtoref.rx_is_lockedtoref
            rx_is_lockedtodata      : out std_logic;                      --      rx_is_lockedtodata.rx_is_lockedtodata
            tx_std_coreclkin        : in  std_logic; --        tx_std_coreclkin.tx_std_coreclkin
            rx_std_coreclkin        : in  std_logic; --        rx_std_coreclkin.rx_std_coreclkin
            tx_std_clkout           : out std_logic;                      --           tx_std_clkout.tx_std_clkout
            rx_std_clkout           : out std_logic;                      --           rx_std_clkout.rx_std_clkout
            rx_std_wa_patternalign  : in  std_logic; --  rx_std_wa_patternalign.rx_std_wa_patternalign
            tx_std_elecidle         : in  std_logic; --         tx_std_elecidle.tx_std_elecidle
            rx_std_signaldetect     : out std_logic;                      --     rx_std_signaldetect.rx_std_signaldetect
            tx_cal_busy             : out std_logic;                      --             tx_cal_busy.tx_cal_busy
            rx_cal_busy             : out std_logic;                      --             rx_cal_busy.rx_cal_busy
            reconfig_to_xcvr        : in  std_logic_vector(139 downto 0); --        reconfig_to_xcvr.reconfig_to_xcvr
            reconfig_from_xcvr      : out std_logic_vector(91 downto 0);                     --      reconfig_from_xcvr.reconfig_from_xcvr
            tx_parallel_data        : in  std_logic_vector(31 downto 0); --        tx_parallel_data.tx_parallel_data
            tx_datak                : in  std_logic_vector(3 downto 0); --                tx_datak.tx_datak
            unused_tx_parallel_data : in  std_logic_vector(7 downto 0); -- unused_tx_parallel_data.unused_tx_parallel_data
            rx_parallel_data        : out std_logic_vector(31 downto 0);                     --        rx_parallel_data.rx_parallel_data
            rx_datak                : out std_logic_vector(3 downto 0);                      --                rx_datak.rx_datak
            rx_errdetect            : out std_logic_vector(3 downto 0);                      --            rx_errdetect.rx_errdetect
            rx_disperr              : out std_logic_vector(3 downto 0);                      --              rx_disperr.rx_disperr
            rx_runningdisp          : out std_logic_vector(3 downto 0);                      --          rx_runningdisp.rx_runningdisp
            rx_patterndetect        : out std_logic_vector(3 downto 0);                      --        rx_patterndetect.rx_patterndetect
            rx_syncstatus           : out std_logic_vector(3 downto 0);                      --           rx_syncstatus.rx_syncstatus
            unused_rx_parallel_data : out std_logic_vector(7 downto 0)                       -- unused_rx_parallel_data.unused_rx_parallel_data
        );
    end component NativePhy;

    component XCVR_ResetController is
        port (
            clock              : in  std_logic;             --              clock.clk
            reset              : in  std_logic;             --              reset.reset
            pll_powerdown      : out std_logic;                    --      pll_powerdown.pll_powerdown
            tx_analogreset     : out std_logic;                    --     tx_analogreset.tx_analogreset
            tx_digitalreset    : out std_logic;                    --    tx_digitalreset.tx_digitalreset
            tx_ready           : out std_logic;                    --           tx_ready.tx_ready
            pll_locked         : in  std_logic; --         pll_locked.pll_locked
            pll_select         : in  std_logic; --         pll_select.pll_select
            tx_cal_busy        : in  std_logic; --        tx_cal_busy.tx_cal_busy
            rx_analogreset     : out std_logic;                    --     rx_analogreset.rx_analogreset
            rx_digitalreset    : out std_logic;                    --    rx_digitalreset.rx_digitalreset
            rx_ready           : out std_logic;                    --           rx_ready.rx_ready
            rx_is_lockedtodata : in  std_logic; -- rx_is_lockedtodata.rx_is_lockedtodata
            rx_cal_busy        : in  std_logic--        rx_cal_busy.rx_cal_busy
        );
    end component XCVR_ResetController;

    --component XCVR_CustomReset
    --    port (
    --        clk50              : in std_logic;
    --        master_reset       : in std_logic;
    --        pll_powerdown      : out std_logic;
    --        tx_digitalreset    : out std_logic;
    --        rx_analogreset     : out std_logic;
    --        rx_digitalreset    : out std_logic;
    --        rx_locktorefclk    : out std_logic;
    --        rx_locktodata      : out std_logic;
    --        busy               : in std_logic;
    --        pll_locked         : in std_logic;
    --        oob_handshake_done : in std_logic
    --    );
    --end component;

    component XCVR_Reconf is
        port (
            reconfig_busy             : out std_logic;                                         --      reconfig_busy.reconfig_busy
            mgmt_clk_clk              : in  std_logic;             --       mgmt_clk_clk.clk
            mgmt_rst_reset            : in  std_logic;             --     mgmt_rst_reset.reset
            reconfig_mgmt_address     : in  std_logic_vector(6 downto 0)   ; --      reconfig_mgmt.address
            reconfig_mgmt_read        : in  std_logic;             --                   .read
            reconfig_mgmt_readdata    : out std_logic_vector(31 downto 0);                     --                   .readdata
            reconfig_mgmt_waitrequest : out std_logic;                                         --                   .waitrequest
            reconfig_mgmt_write       : in  std_logic;             --                   .write
            reconfig_mgmt_writedata   : in  std_logic_vector(31 downto 0); --                   .writedata
            reconfig_to_xcvr          : out std_logic_vector(139 downto 0);                    --   reconfig_to_xcvr.reconfig_to_xcvr
            reconfig_from_xcvr        : in  std_logic_vector(91 downto 0)  -- reconfig_from_xcvr.reconfig_from_xcvr
        );
    end component XCVR_Reconf;

    component Debounce is
      port(
        clk50      : in  std_logic;
        button     : in  std_logic;
        debounced  : out std_logic);
    end component Debounce;


    component pll_50MHz_to_37_5MHz is
        port (
            refclk   : in  std_logic := '0'; --  refclk.clk
            rst      : in  std_logic := '0'; --   reset.reset
            outclk_0 : out std_logic;        -- outclk0.clk
            locked   : out std_logic         --  locked.export
        );
    end component pll_50MHz_to_37_5MHz;

    begin

    i_transdummy1 : transport_dummy
    port map(
            fabric_clk => txclkout,
            reset      => rst_n,
            trans_status_to_link => trans_status_in,
            link_status_to_trans => trans_status_out,
            tx_data_to_link      => trans_tx_data_in,
            rx_data_from_link    => trans_rx_data_out
        );

    i_linkLayer1 : link_layer_32bit
    port map(   -- Input
            clk             => txclkout,
            rst_n           => rst_n,

            --Interface with Transport Layer
            trans_status_in => trans_status_in,
            trans_status_out=> trans_status_out,
            tx_data_in      => trans_tx_data_in,
            rx_data_out     => trans_rx_data_out,

            --Interface with Physical Layer
            tx_data_out     => tx_data_from_link,
            rx_data_in      => rx_data_to_link,
            phy_status_in   => phy_status_to_link,
            phy_status_out  => link_status_to_phy
--            perform_init    => perform_init
        );

    i_phy_layer_1 : phy_layer_32bit
    port map(
            fabric_clk_37_5 => txclkout,
            reset         => reset,

            --Interface with link layer
            tx_data_from_link    => tx_data_from_link,
            rx_data_to_link      => rx_data_to_link,
            phy_status_to_link   => phy_status_to_link,
            link_status_to_phy   => link_status_to_phy,
    --        perform_init     :   out std_logic); -- currently unused

            --Interface with transceivers
            rxclkout         => rxclkout,
            txclkout         => txclkout,
            rx_pma_clkout    => rx_pma_clkout,

            rx_data          => rx_data,
            rx_datak         => rx_datak,
            rx_signaldetect  => rx_signaldetect,

            rx_errdetect     => rx_errdetect,

            tx_forceelecidle => tx_forceelecidle,
            tx_data          => tx_data,
            tx_datak         => tx_datak,

            do_word_align    => do_word_align,
            rx_syncstatus    => rx_syncstatus,

            rx_set_locktoref  => rx_set_locktoref,
            rx_set_locktodata => rx_set_locktodata
        );

    native1 : NativePhy
        port  map(
            pll_powerdown           => pll_powerdown,
            tx_analogreset          => tx_analogreset,
            tx_digitalreset         => tx_digitalreset,
            tx_pll_refclk           => pll_refclk_150,
            tx_serial_data          => tx_serial_data,
            pll_locked              => pll_locked,
            rx_analogreset          => rx_analogreset,
            rx_digitalreset         => rx_digitalreset,
            rx_cdr_refclk           => pll_refclk_150, -- cdr refclk is same as pll refclk!!!
            rx_pma_clkout           => rx_pma_clkout,
            rx_serial_data          => rx_serial_data,
            rx_set_locktodata       => rx_set_locktodata,
            rx_set_locktoref        => rx_set_locktoref,
            rx_is_lockedtoref       => rx_is_lockedtoref,
            rx_is_lockedtodata      => rx_is_lockedtodata,
            tx_std_coreclkin        => txclkout,
            rx_std_coreclkin        => rxclkout,
            tx_std_clkout           => txclkout,
            rx_std_clkout           => rxclkout,
            rx_std_wa_patternalign  => do_word_align,
            tx_std_elecidle         => tx_forceelecidle,
            rx_std_signaldetect     => rx_signaldetect,
            tx_cal_busy             => tx_cal_busy,
            rx_cal_busy             => rx_cal_busy,
            reconfig_to_xcvr        => reconfig_to_xcvr,
            reconfig_from_xcvr      => reconfig_from_xcvr,
            tx_parallel_data        => tx_data,
            tx_datak                => tx_datak,
            unused_tx_parallel_data => (others => '0'), -- don't need the unused parallel data
            rx_parallel_data        => rx_data,
            rx_datak                => rx_datak,
            rx_errdetect            => rx_errdetect, -- code violation or disparity error
            rx_disperr              => rx_disperr,   -- disparity error only
            rx_runningdisp          => OPEN, -- we don't care about what the current running disparity is.
            rx_patterndetect        => rx_patterndetect, -- word alignment detected the comma pattern, k28.5
            rx_syncstatus           => rx_syncstatus -- syncstatus high indicates word aligned
--            unused_rx_parallel_data => -- don't need the unused parallel data
       );

    reconf_1 : XCVR_Reconf
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

    --customRst1 : XCVR_CustomReset
    --    port map (
    --        clk50              => clk50,
    --        master_reset       => reset,
    --        pll_powerdown      => pll_powerdown,
    --        tx_digitalreset    => tx_digitalreset,
    --        rx_analogreset     => rx_analogreset,
    --        rx_digitalreset    => rx_digitalreset,
    --        rx_locktorefclk    => rx_set_locktoref,
    --        rx_locktodata      => rx_set_locktodata,
    --        busy               => tx_cal_busy,
    --        pll_locked         => pll_locked,
    --        oob_handshake_done => oob_handshake_done
    --    );


    xcvr_reset1 : XCVR_ResetController
        port map (
            clock              => clk50,
            reset              => reset,
            pll_powerdown      => pll_powerdown,
            tx_analogreset     => tx_analogreset,
            tx_digitalreset    => tx_digitalreset,
            tx_ready           => tx_ready,
            pll_locked         => pll_locked,
            pll_select         => '0',
            tx_cal_busy        => tx_cal_busy,
            rx_analogreset     => rx_analogreset,
            rx_digitalreset    => rx_digitalreset,
            rx_ready           => rx_ready,
            rx_is_lockedtodata => rx_is_lockedtodata,
            rx_cal_busy        => rx_cal_busy
        );

    i_pll_50MHz_to_37_5MHz_1 : pll_50MHz_to_37_5MHz
        port map(
            refclk   => clk50,
            rst      => reset,
            outclk_0 => fabric_clk_37_5
--            locked   : out std_logic         --  locked.export
        );

    -- debounce reset and pushbutton.
    cpu_rst <= not cpu_rst_n;
    resetDebounce_0 : Debounce
        port map(clk50, cpu_rst, cpu_rst_debounced);

    pb_debounce : Debounce
        port map(clk50, USER_PB_FPGA1, pb_fpga1);

    reset <= (not pb_fpga1) or cpu_rst_debounced;
    rst_n <= not reset;
    USER_LED_FPGA0 <= '1' when pb_fpga1 = '1' else '0';

    -- dummy status and data values
--    link_status_to_phy <= LINK_STATUS_DEFAULT(LINK_STATUS_LENGTH-1 downto 0);
--    tx_data_from_link  <= SYNCp;

end top_arch;
