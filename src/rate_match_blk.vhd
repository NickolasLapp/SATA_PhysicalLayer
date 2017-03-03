library ieee;
use ieee.std_logic_1164.ALL;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.sata_defines.all;

entity rate_match_blk is
    port(
        fabric_clk : in std_logic;
        rst        : in std_logic;

        -- from phy block
        rxclkout  : in std_logic;
        txclkout  : in std_logic;
        rx_data_from_phy : in std_logic_vector(63 downto 0); -- data received from XCVRS (XCVR clock domain)
        tx_data_to_phy   : out std_logic_vector(63 downto 0); -- data to be transmitted on XCVRS (XCVR clock domain)

        -- to link layer
        rx_data_to_link    : out std_logic_vector(63 downto 0); -- data to be handed off to link (fabric clk domain)
        tx_data_from_link  : in std_logic_vector(63 downto 0)   -- data received from link (fabric clk domain)

    );
end entity rate_match_blk;

architecture rate_match_blk_arch of rate_match_blk is
    signal send_pause    : std_logic;
    signal send_periodic_align : std_logic;
    signal align_counter : std_logic_vector(7 downto 0);

    signal tx_buff_empty : std_logic;
    signal tx_buff_full  : std_logic;
    signal tx_buff_usage_r : std_logic_vector(2 downto 0);
    signal tx_buff_usage_w : std_logic_vector(2 downto 0);

    signal tx_readreq : std_logic;
    signal tx_writereq : std_logic;

    signal rx_buff_empty : std_logic;
    signal rx_buff_full  : std_logic;
    signal rx_buff_usage_r : std_logic_vector(2 downto 0);
    signal rx_buff_usage_w : std_logic_vector(2 downto 0);

    signal rx_readreq : std_logic;
    signal rx_writereq : std_logic;

    signal rx_data_to_link_s : std_logic_vector(63 downto 0);
    signal tx_data_to_phy_s  : std_logic_vector(63 downto 0);

    component rate_match_fifo
        port
        (
            aclr        : in std_logic  := '0'; -- clear/reset
            data        : in std_logic_vector (63 downto 0); -- write data
            rdclk       : in std_logic ; -- read clock
            rdreq       : in std_logic ; -- read request (asserted 1 cycle before read data valid)
            wrclk       : in std_logic ; -- write clock
            wrreq       : in std_logic ; -- write clock (asserted as write data valid?)
            q           : out std_logic_vector (63 downto 0); -- read data out
            rdempty     : out std_logic ; -- is fifo empty (read request invalid)
            rdusedw     : out std_logic_vector (2 downto 0); -- number of words available to read
            wrfull      : out std_logic ; -- is fifo full (write request invalid)
            wrusedw     : out std_logic_vector (2 downto 0) -- number of words written (should be same as rdusedw?)
        );
    end component;

begin

    process(rx_buff_empty, tx_buff_empty, tx_buff_full, rst, send_periodic_align, tx_data_to_phy_s, rx_data_to_link_s)
    begin
        if(rst = '1') then
                rx_data_to_link <= (others => '0');
                tx_data_to_phy  <= (others => '0');
                rx_readreq <= '0';
                tx_readreq <= '0';
                send_pause <= '0';
        else
            if(send_periodic_align = '0') then
                if(tx_buff_full = '1') then
                    rx_data_to_link <= RX_DATA_FILL_PAUSED;
                    tx_data_to_phy  <= tx_data_to_phy_s;
                    rx_readreq <= '0';
                    tx_readreq <= '1';
                    send_pause <= '1';
                elsif(rx_buff_empty='1' and tx_buff_empty='1') then                -- Both empty. Send default signals either way
                    rx_data_to_link <= RX_DATA_FILL_PAUSED;
                    tx_data_to_phy  <= TX_DATA_FILL_DEFAULT;
                    rx_readreq <= '0';
                    tx_readreq <= '0';
                    send_pause <= '1';
                elsif(rx_buff_empty='1' and tx_buff_empty='0') then             -- Empty TX buffer, send default rx buffer;
                    rx_data_to_link <= RX_DATA_FILL_PAUSED;
                    tx_data_to_phy <= tx_data_to_phy_s;
                    rx_readreq <= '0';
                    tx_readreq <= '1';
                    send_pause <= '1';
                elsif(rx_buff_empty='0' and tx_buff_empty='1') then
                    rx_data_to_link <= rx_data_to_link_s;
                    tx_data_to_phy <= TX_DATA_FILL_DEFAULT;
                    rx_readreq <= '1';
                    tx_readreq <= '0';
                    send_pause <= '0';
                else --(rx_buff_empty='0' and tx_buff_empty='0') then
                    rx_data_to_link <= rx_data_to_link_s;
                    tx_data_to_phy <= tx_data_to_phy_s;
                    rx_readreq <= '1';
                    tx_readreq <= '1';
                    send_pause <= '0';
                end if;
            else -- (send_periodic_align = '1') then
                tx_readreq <= '0';
                tx_data_to_phy <= TX_DATA_FILL_DEFAULT;
                if(tx_buff_full = '1') then
                    rx_data_to_link <= RX_DATA_FILL_PAUSED;
                    rx_readreq <= '0';
                    send_pause <= '1';
                elsif(rx_buff_empty='1') then
                    rx_data_to_link <=  RX_DATA_FILL_PAUSED;
                    rx_readreq <= '0';
                    send_pause <= '1';
                else --(rx_buff_empty='0') then
                    rx_data_to_link <= rx_data_to_link_s;
                    rx_readreq <= '1';
                    send_pause <= '0';
                end if;
            end if;
        end if;
    end process;

    process(rst, rx_data_from_phy, rx_writereq, send_pause)
    begin
        if(rst = '1') then
            rx_writereq <= '0';
            tx_writereq <= '0';
        else
            if(rx_data_from_phy(63 downto 32) = ALIGNp) then
                rx_writereq <= '0';
            else
                rx_writereq <= '1';
            end if;

            if(send_pause = '1') then
                tx_writereq <= '0';
            else
                tx_writereq <= '1';
            end if;
        end if;
    end process;

    process(rst, txclkout)
    begin
        if(rst = '1') then
            align_counter <= (others => '0');
            send_periodic_align <= '0';
        elsif(rising_edge(txclkout)) then
            if(align_counter < 2) then
                send_periodic_align <= '1';
            else
                send_periodic_align <= '0';
            end if;
            align_counter <= align_counter + '1';
        end if;
    end process;

    -- this buffer will clock tx_data_from_link to tx_data_to_phy. May insert ALIGNp primitives before transfer to tx_data if the buffer becomes too empty, or elasticity requirements are not met.
    tx_fifo : rate_match_fifo PORT MAP (
            aclr     => rst,
            data     => tx_data_from_link,
            rdclk    => txclkout,
            rdreq    => tx_readreq,
            wrclk    => fabric_clk,
            wrreq    => tx_writereq,
            q        => tx_data_to_phy_s,
            rdempty  => tx_buff_empty,
            rdusedw  => tx_buff_usage_r,
            wrfull   => tx_buff_full,
            wrusedw  => tx_buff_usage_w
        );

    -- this buffer will clock rx_data_from_phy to rx_data_to_link. Should eat ALGINp primitives before storing if buffer is filling up
    rx_fifo : rate_match_fifo PORT MAP (
            aclr     => rst,
            data     => rx_data_from_phy,
            rdclk    => fabric_clk,
            rdreq    => rx_readreq,
            wrclk    => rxclkout,
            wrreq    => rx_writereq,
            q        => rx_data_to_link_s,
            rdempty  => rx_buff_empty,
            rdusedw  => rx_buff_usage_r,
            wrfull   => rx_buff_full,
            wrusedw  => rx_buff_usage_w
        );
end architecture rate_match_blk_arch;
