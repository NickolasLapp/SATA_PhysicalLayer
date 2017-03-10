library ieee;
use ieee.std_logic_1164.ALL;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.sata_defines.all;

entity phy_layer_32bit is
    port(
        fabric_clk_37_5 : in std_logic;           -- 50 MHz clock from AC18, driven by SL18860C
        reset         : in std_logic;       -- CPU_RESETn pushbutton. (Debounce this). Pin AD27

        --Interface with link layer
        tx_data_from_link   :   in std_logic_vector(31 downto 0);
        rx_data_to_link     :   out std_logic_vector(31 downto 0);
        phy_status_to_link  :   out std_logic_vector(PHY_STATUS_LENGTH-1 downto 0);       -- [primitive, PHYRDY/n, Dec_Err]
        link_status_to_phy  :   in  std_logic_vector(LINK_STATUS_LENGTH-1  downto 0);       -- [primitive, clear status signals]
--        perform_init     :   out std_logic); -- currently unused

        --Interface with transceivers
        rxclkout         : in std_logic;   -- recovered rx clock to clock receive datapath from XCVRs
        txclkout         : in  std_logic; -- tx clock from XCVRs to clock transmit datapath

        rx_pma_clkout    : in std_logic;

        rx_data          : in  std_logic_vector(31 downto 0); --raw received data from XCVRs
        rx_datak         : in  std_logic_vector(3 downto 0); --data or control symbol for receieved data
        rx_signaldetect  : in  std_logic; -- detect oob received oob signals

        rx_errdetect     : in  std_logic_vector(3 downto 0);

        tx_forceelecidle : out std_logic; -- send oob signals
        tx_data          : out std_logic_vector(31 downto 0); -- data to transmit
        tx_datak         : out std_logic_vector(3 downto 0); -- data or control symbol for transmitted data

        do_word_align    : out std_logic; -- signal native phy to perform word align
        rx_syncstatus    : in std_logic_vector(3 downto 0); -- detect word alignment successfull

        rx_set_locktoref  : out std_logic; -- control transceiver locking characteristics
        rx_set_locktodata : out std_logic -- control transceiver locking characteristics
        );
END phy_layer_32bit;

architecture phy_layer_32bit_arch of phy_layer_32bit is
    signal PHYRDY : std_logic;
    signal rate_match_clear     : std_logic;

    signal rx_data_from_phy_comb         : std_logic_vector(63 downto 0); -- from XCVRs, this is fed into the rate match blk
    signal rx_data_to_link_comb          : std_logic_vector(63 downto 0); -- to link layer. This is converted to status and data signals and passed to link
    signal tx_data_from_link_comb        : std_logic_vector(63 downto 0); -- from link, this is fed into the rate match blk
    signal tx_data_to_phy_comb           : std_logic_vector(63 downto 0); -- to xcvrs. This is converted to status and data signals and passed to transceivers

    signal link_status_to_phy_s            : std_logic_vector(31 downto 0);
    signal phy_status_to_link_s             : std_logic_vector(31 downto 0);

    signal tx_data_phy_init         : std_logic_vector(31 downto 0);
    signal tx_datak_phy_init        : std_logic_vector(3 downto 0);

    signal rx_data_from_phy         : std_logic_vector(31 downto 0);
    signal primitive_recvd          : std_logic;

    signal ppm_within_threshold     : std_logic;

    component PhyLayerInit is
        port(
            rxclkout         : in  std_logic;
            txclkout         : in  std_logic;
            reset            : in  std_logic;

            rx_ordered_data  : out std_logic_vector(31 downto 0);
            primitive_recvd  : out std_logic;

            rx_data          : in  std_logic_vector(31 downto 0);
            rx_datak         : in  std_logic_vector(3 downto 0);
            rx_signaldetect  : in  std_logic;

            rx_errdetect     : in std_logic_vector(3 downto 0);

            tx_forceelecidle : out std_logic;
            tx_data          : out std_logic_vector(31 downto 0);
            tx_datak         : out std_logic_vector(3 downto 0);

            do_word_align    : out std_logic;
            rx_syncstatus    : in std_logic_vector(3 downto 0);

            rx_set_locktoref  : out std_logic;
            rx_set_locktodata : out std_logic;

            ppm_within_threshold : in std_logic;
            PHYRDY         : out std_logic
        );
    end component PhyLayerInit;

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

    component ppm_detector is
        port(
            fabric_clk: in std_logic;
            rxclkout  : in std_logic;
            rst       : in std_logic;

            ppm_within_threshold : out std_logic
            );
    end component ppm_detector;

begin

    phyLayerInit1 : PhyLayerInit
        port map(
            rxclkout         => rxclkout,
            txclkout         => txclkout,
            reset            => reset,

            rx_ordered_data  => rx_data_from_phy,
            primitive_recvd  => primitive_recvd,

            rx_data          => rx_data,
            rx_datak         => rx_datak,
            rx_signaldetect  => rx_signaldetect,

            rx_errdetect     => rx_errdetect,

            tx_forceelecidle => tx_forceelecidle,
            tx_data          => tx_data_phy_init,
            tx_datak         => tx_datak_phy_init,

            do_word_align    => do_word_align,
            rx_syncstatus    => rx_syncstatus,

            rx_set_locktoref  => rx_set_locktoref,
            rx_set_locktodata => rx_set_locktodata,

            ppm_within_threshold => ppm_within_threshold,

            PHYRDY           => PHYRDY
        );

    i_rate_match_blk_1 : rate_match_blk
        port map(
            fabric_clk => fabric_clk_37_5,
            rst        => rate_match_clear,

            -- from XCVR block
            rxclkout  => rxclkout,
            txclkout  => txclkout,
            rx_data_from_phy    => rx_data_from_phy_comb,
            tx_data_to_phy      => tx_data_to_phy_comb,

            -- to link layer
            rx_data_to_link     => rx_data_to_link_comb,
            tx_data_from_link   => tx_data_from_link_comb
        );

    i_ppm_detector_1 : ppm_detector
    port map(
        fabric_clk => fabric_clk_37_5,
        rxclkout   => rx_pma_clkout,
        rst        => reset,

        ppm_within_threshold => ppm_within_threshold
        );

    -- assign signals into vector for fifo bufferring
    phy_status_to_link_s(c_l_primitive_in) <= primitive_recvd;
    phy_status_to_link_s(c_l_phyrdy) <= PHYRDY;
    phy_status_to_link_s(c_l_dec_err) <= '0';
    phy_status_to_link_s(31 downto PHY_STATUS_LENGTH) <= (others => '0');

    -- decode link signals from vector use
    link_status_to_phy_s <= tx_data_to_phy_comb(31 downto 0);

    -- decode signal from fifo
    rx_data_to_link <= rx_data_to_link_comb(63 downto 32);
    phy_status_to_link  <= rx_data_to_link_comb(PHY_STATUS_LENGTH-1 downto 0);

    -- combine signals before storage in fifo
    tx_data_from_link_comb(63 downto 32) <= tx_data_from_link;
    tx_data_from_link_comb(LINK_STATUS_LENGTH-1 downto 0) <= link_status_to_phy;

    rx_data_from_phy_comb  <= rx_data_from_phy  & phy_status_to_link_s;

    -- acl for fifos
    process(reset, rxclkout)
    begin
        if(reset = '1') then
            rate_match_clear <= '1';
        elsif(rising_edge(rxclkout)) then
            if(PHYRDY = '1') then
                rate_match_clear <= '0';
            else
                rate_match_clear <= '1';
            end if;
        end if;
    end process;

    -- assign tx_data, tx_datak
    process(reset, txclkout)
    begin
        if(reset = '1') then
            tx_data <= (others => '0');
            tx_datak <= (others => '0');
        elsif(rising_edge(txclkout)) then
            if(PHYRDY = '0') then
                tx_data  <= tx_data_phy_init;
                tx_datak <= tx_datak_phy_init;
            else
                tx_data <= tx_data_to_phy_comb(63 downto 32);
                if(link_status_to_phy_s(c_l_primitive_out) = '1') then
                    tx_datak <= DATAK_BYTE_ZERO;
                else
                    tx_datak <= DATAK_BYTE_NONE;
                end if;
            end if;
        end if;
    end process;
end architecture phy_layer_32bit_arch;
