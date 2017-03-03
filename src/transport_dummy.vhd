library ieee;
use ieee.std_logic_1164.ALL;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

--use work.sata_defines.all;

entity transport_dummy is
    port(
            fabric_clk          :   in std_logic;
            reset               :   in std_logic;

            --Interface with link Layer
            trans_status_to_link:   out std_logic_vector(7 downto 0);  -- [FIFO_RDY/n, transmit request, data complete, escape, bad FIS, error, good FIS]
            link_status_to_trans:   in  std_logic_vector(6 downto 0);  -- [Link Idle, transmit bad status, transmit good status, crc good/bad, comm error, fail transmit]
            tx_data_to_link     :   out std_logic_vector(31 downto 0);
            rx_data_from_link   :   in  std_logic_vector(31 downto 0)
            );
end entity transport_dummy;

architecture rtl of transport_dummy is

    type data_arr is array(0 to 5) of std_logic_vector(31 downto 0);
    type stat_arr is array(0 to 5) of std_logic_vector(7 downto 0);
    --type data_fis_array is array (511 downto 0) of std_logic_vector(31 downto 0);

 --   constant dataToSend : data_arr := (x"00358027", x"40000000", x"00000000", x"00000001", x"00000000", (others => 'X'));
 --   constant dataToSend : data_arr := (x"00358027", x"e0bbcb40", x"0000000d", x"00000001", x"00000000", (others => 'X'));
    constant dataToSend : data_arr := (x"00358027", x"e01DCD65", x"00000000", x"00000001", x"00000000", (others => 'X'));

    constant statToSend : stat_arr := ("01100000", "01100000", "01100000", "01100000", "01100000", "11010000");

    --constant data_fis : data_fis_array := (x"00000046", x"12345678", x"23456789", x"98765432", x"12341234", (others => '1'));

    signal idx : integer range 0 to 1000001;
    signal link_rdy : std_logic;

    signal dma_ack_rcv : std_logic;
    signal array_idx_offset : integer range 0 to 1000001;
--constant c_l_pause_transmit     : integer := 7;                     -- Asserted when Transport Layer is not ready to transmit
--constant c_l_fifo_ready         : integer := 6;                     -- Asserted when Transport Layer FIFO has room for more data
--constant c_l_transmit_request   : integer := 5;                     -- Asserted when Transport Layer wants to begin a transmission
--constant c_l_data_done          : integer := 4;                     -- Asserted the clock cycle after the last of the Transport Layer data has been transmitted
--constant c_l_escape             : integer := 3;                     -- Asserted when the Transport Layer wants to terminate a transmission
--constant c_l_bad_fis            : integer := 2;                     -- Asserted at the end of a "read" when a bad FIS is received by the Transport Layer
--constant c_l_error              : integer := 1;                     -- Asserted at the end of a "read" when there is a different error in the FIS received by the Transport Layer
--constant c_l_good_fis           : integer := 0;                     -- Asserted at the end of a "read" when a good FIS is received by the Transport Layer


--constant c_l_link_rdy          : integer := 5;                     -- Asserted when the Link Layer is in the Idle state and is ready for a transmit request
--constant c_l_transmit_bad       : integer := 4;                     -- Asserted at the end of transmission to indicate in error
--constant c_l_transmit_good      : integer := 3;                     -- Asserted at the end of transmission to successful transmission
--constant c_l_crc_good           : integer := 2;                     -- Asserted when the CRC has been verified
--constant c_l_comm_err           : integer := 1;                     -- Asserted when there is an error in the communication channel (PHYRDYn)
--constant c_l_fail_transmit      : integer := 0;                     -- Asserted when the communication channel fails during transmission

begin

    link_rdy <= link_status_to_trans(5);

    trans_status_to_link(7 downto 6) <= "01";
    trans_status_to_link(4 downto 0) <= "00001";

    process(fabric_clk, reset)
    begin
        if(reset = '0') then
            idx <= 0;
            trans_status_to_link(5) <= '0';
            tx_data_to_link <= (others => '0');
            dma_ack_rcv <='0';
            array_idx_offset <= 0;
        elsif(rising_edge(fabric_clk)) then
            if(link_rdy = '0' and idx = 0) then
                tx_data_to_link <= dataToSend(0);
                trans_status_to_link(5) <= '1';
                idx <= 0;
            elsif(idx < 4 and link_rdy = '1') then
                idx <= idx + 1;
                tx_data_to_link <= dataToSend(idx + 1);
            elsif(idx = 4)then --need to reset transport to link tx request flag
                trans_status_to_link(5) <= '0';
                tx_data_to_link <= (others => '1');
                idx <= idx + 1;
            elsif(idx < 1000000) then
                if(rx_data_from_link(7 downto 0) = x"39")then --dma act recievied
                    dma_ack_rcv <='1';
                    array_idx_offset <= idx;
                elsif(dma_ack_rcv = '1')then
                    --transmit test data
                    if((idx - array_idx_offset) < 512 and link_rdy = '0')then
                        tx_data_to_link <= x"00000046"; --start sending data fis
                        trans_status_to_link(5) <= '1';
                    elsif((idx - array_idx_offset) < 512 and link_rdy = '1') then
                        tx_data_to_link <= std_logic_vector(to_unsigned(idx - array_idx_offset,32));
                    else
                        trans_status_to_link(5) <= '0';
                        tx_data_to_link <= (others => '1');
                        dma_ack_rcv <='0';
                    end if;
                else
                    dma_ack_rcv <='0';
                    trans_status_to_link(5) <= '0';
                    tx_data_to_link <= (others => '1');
                end if;
                idx <= idx + 1;
            else
                idx <= 0;
            end if;
        end if;
    end process;
end rtl;
