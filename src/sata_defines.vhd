library ieee;
use ieee.std_logic_1164.ALL;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

package sata_defines is
    -- primitives
    constant ALIGNp   : std_logic_vector(31 downto 0) := x"7B4A4ABC";
    constant CONTp    : std_logic_vector(31 downto 0) := x"9999AA7C";
    constant DMATp    : std_logic_vector(31 downto 0) := x"3636B57C";
    constant EOFp     : std_logic_vector(31 downto 0) := x"D5D5B57C";
    constant HOLDp    : std_logic_vector(31 downto 0) := x"D5D5AA7C";
    constant HOLDAp   : std_logic_vector(31 downto 0) := x"9595AA7C";
    constant PMACKp   : std_logic_vector(31 downto 0) := x"9595957C";
    constant PMNAKp   : std_logic_vector(31 downto 0) := x"F5F5957C";
    constant PMREQ_Pp : std_logic_vector(31 downto 0) := x"1717B57C";
    constant PMREQ_Sp : std_logic_vector(31 downto 0) := x"7575957C";
    constant R_ERRp   : std_logic_vector(31 downto 0) := x"5656B57C";
    constant R_IPp    : std_logic_vector(31 downto 0) := x"5555B57C";
    constant R_OKp    : std_logic_vector(31 downto 0) := x"3535B57C";
    constant R_RDYp   : std_logic_vector(31 downto 0) := x"4A4A957C";
    constant SOFp     : std_logic_vector(31 downto 0) := x"3737B57C";
    constant SYNCp    : std_logic_vector(31 downto 0) := x"B5B5957C";
    constant WTRMp    : std_logic_vector(31 downto 0) := x"5858B57C";
    constant X_RDYp   : std_logic_vector(31 downto 0) := x"5757B57C";

    constant ALL_WORDS_SYNC : std_logic_vector(3 downto 0) := x"F";

    constant DATAK_28_3     : std_logic_vector(7 downto 0)  := x"7C";
    constant DATAK_28_5     : std_logic_vector(7 downto 0)  := x"BC";

    constant DATAK_BYTE_ZERO  : std_logic_vector(3 downto 0)  := "0001";
    constant DATAK_BYTE_ONE   : std_logic_vector(3 downto 0)  := "0010";
    constant DATAK_BYTE_TWO   : std_logic_vector(3 downto 0)  := "0100";
    constant DATAK_BYTE_THREE : std_logic_vector(3 downto 0)  := "1000";
    constant DATAK_BYTE_NONE  : std_logic_vector(3 downto 0)  := "0000";


    constant PHY_STATUS_LENGTH  : integer := 4;
    constant LINK_STATUS_LENGTH : integer := 2;
    constant PHY_STATUS_DEFAULT : std_logic_vector(31 downto 0)  := (31 downto PHY_STATUS_LENGTH => '0') & "0110";
    constant PHY_STATUS_PAUSED  : std_logic_vector(31 downto 0)  := (31 downto PHY_STATUS_LENGTH => '0') & "1110";
    constant LINK_STATUS_DEFAULT : std_logic_vector(31 downto 0) := (31 downto LINK_STATUS_LENGTH=> '0') & "10";
    constant RX_DATA_FILL_DEFAULT : std_logic_vector(63 downto 0)  := ALIGNp & PHY_STATUS_DEFAULT;
    constant RX_DATA_FILL_PAUSED  : std_logic_vector(63 downto 0)  := ALIGNp & PHY_STATUS_PAUSED;
    constant TX_DATA_FILL_DEFAULT : std_logic_vector(63 downto 0)  := ALIGNp & LINK_STATUS_DEFAULT;



    -- status signals
    -- constants (naming convention: c --> constant, l --> link layer)
        -- trans_status_in
    constant c_l_pause_transmit     : integer := 7;                     -- Asserted when Transport Layer is not ready to transmit
    constant c_l_fifo_ready         : integer := 6;                     -- Asserted when Transport Layer FIFO has room for more data
    constant c_l_transmit_request   : integer := 5;                     -- Asserted when Transport Layer wants to begin a transmission
    constant c_l_data_done          : integer := 4;                     -- Asserted the clock cycle after the last of the Transport Layer data has been transmitted
    constant c_l_escape             : integer := 3;                     -- Asserted when the Transport Layer wants to terminate a transmission
    constant c_l_bad_fis            : integer := 2;                     -- Asserted at the end of a "read" when a bad FIS is received by the Transport Layer
    constant c_l_error              : integer := 1;                     -- Asserted at the end of a "read" when there is a different error in the FIS received by the Transport Layer
    constant c_l_good_fis           : integer := 0;                     -- Asserted at the end of a "read" when a good FIS is received by the Transport Layer
        -- trans_status_out
    constant c_l_link_idle          : integer := 5;                     -- Asserted when the Link Layer is in the Idle state and is ready for a transmit request
    constant c_l_transmit_bad       : integer := 4;                     -- Asserted at the end of transmission to indicate in error
    constant c_l_transmit_good      : integer := 3;                     -- Asserted at the end of transmission to successful transmission
    constant c_l_crc_good           : integer := 2;                     -- Asserted when the CRC has been verified
    constant c_l_comm_err           : integer := 1;                     -- Asserted when there is an error in the communication channel (PHYRDYn)
    constant c_l_fail_transmit      : integer := 0;                     -- Asserted when the communication channel fails during transmission
        -- phy_status_in
    constant c_l_pause_all          : integer := 3;
    constant c_l_primitive_in       : integer := 2;                     -- Asserted when a valid primitive is being sent by the Physical Layer on the rx_data_in line
    constant c_l_phyrdy             : integer := 1;                     -- Asserted when the Physical Layer has successfully established a communication channel
    constant c_l_dec_err            : integer := 0;                     -- Asserted when there is an 8B10B encoding error
        -- phy_status_out
    constant c_l_primitive_out      : integer := 1;                     -- Asserted when a valid primitive is being sent to the Physical Layer on the tx_data_out line
    constant c_l_clear_status       : integer := 0;                     -- Asserted to indicate to the Physical Layer to clear its status vector

    -- constants
    constant CHARS_PER_WORD           : integer     := 40;

    constant TRANSMIT_PULSE_CHARS     : integer     := 160;
--    constant TRANSMIT_PULSE_COUNT     : integer     := TRANSMIT_PULSE_CHARS / CHARS_PER_WORD;
    constant TRANSMIT_PULSE_COUNT     : integer     := TRANSMIT_PULSE_CHARS / CHARS_PER_WORD - 1; -- Add minus 1 because counting from 0... probably not the best way to do this.
    constant MIN_DETECT_PULSE_COUNT   : integer    := TRANSMIT_PULSE_COUNT - 2;
    constant MAX_DETECT_PULSE_COUNT   : integer    := TRANSMIT_PULSE_COUNT + 2;


    constant COMRESET_PAUSE_CHARS     : integer     := 480;
--    constant COMRESET_PAUSE_COUNT     : integer     := COMRESET_PAUSE_CHARS / CHARS_PER_WORD;
    constant COMRESET_PAUSE_COUNT     : integer     := COMRESET_PAUSE_CHARS / CHARS_PER_WORD - 1; -- Add minus 1 because counting from 0... probably not the best way to do this.
    constant MIN_COMRESET_DETECT_PAUSE_COUNT    : integer    := COMRESET_PAUSE_COUNT - 2;
    constant MAX_COMRESET_DETECT_PAUSE_COUNT    : integer    := COMRESET_PAUSE_COUNT + 2;


    constant COMINIT_PAUSE_CHARS     : integer     := 480;
--    constant COMINIT_PAUSE_COUNT      : integer     := COMINIT_PAUSE_CHARS / CHARS_PER_WORD;
    constant COMINIT_PAUSE_COUNT      : integer     := COMINIT_PAUSE_CHARS / CHARS_PER_WORD - 1; -- Add minus 1 because couniclitng from 0... probably not the best way to do this.
    constant MIN_COMINIT_DETECT_PAUSE_COUNT : integer    := COMINIT_PAUSE_COUNT - 2;
    constant MAX_COMINIT_DETECT_PAUSE_COUNT : integer    := COMINIT_PAUSE_COUNT + 2;


    constant COMWAKE_PAUSE_CHARS      : integer     := 160;
--    constant COMWAKE_PAUSE_COUNT      : integer     := COMWAKE_PAUSE_CHARS / CHARS_PER_WORD;
    constant COMWAKE_PAUSE_COUNT      : integer     := COMWAKE_PAUSE_CHARS / CHARS_PER_WORD - 1; -- Add minus 1 because counting from 0... probably not the best way to do this.
    constant MIN_COMWAKE_DETECT_PAUSE_COUNT : integer    := COMWAKE_PAUSE_COUNT - 2;
    constant MAX_COMWAKE_DETECT_PAUSE_COUNT : integer    := COMWAKE_PAUSE_COUNT + 2;

--    constant NUM_PAUSES_TO_SEND       : integer     := 6;
--    constant NUM_PULSES_TO_SEND       : integer     := 6;
    constant NUM_PAUSES_TO_SEND       : integer     := 6 - 1; -- Add minus 1 because counting from 0... probably not the best way to do this.
    constant NUM_PULSES_TO_SEND       : integer     := 6 - 1; -- Add minus 1 because counting from 0... probably not the best way to do this.

    constant MIN_IDLE_DETECT_COUNT    : integer     := 20; -- minimum of 525 ns idle time

    constant RETRY_INTERVAL           : integer     := 375000; -- minimum of 10ms retry time
    constant ALIGN_INTERVAL           : integer     := 32768; -- minimum of 873.8us alignp time


     -- types
    type OOB_SIGNAL     is (COMWAKE, COMRESET, COMINIT, NONE, INVALID);
    type OOB_STATE_TYPE is (IDLE, SEND_PAUSE, SEND_PULSE);

    type PHYINIT_STATE_TYPE is (HP1_HR_Reset,
                                HP2_HR_AwaitCOMINIT,
                                HP2B_HR_AwaitNoCOMINIT,
                                HP3_HR_Calibrate,
                                HP4_HR_COMWAKE,
                                HP5_HR_AwaitCOMWAKE,
                                HP5B_HR_AwaitNoCOMWAKE,
                                HP6_HR_AwaitAlign,
                                HP7_HR_SendAlign,
                                HP8_HR_Ready,
                                HP9_HR_Partial,
                                HP10_HR_Slumber,
                                HP11_HR_AdjustSpeed);

     -- programs
end sata_defines;
