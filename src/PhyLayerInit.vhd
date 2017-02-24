library ieee;
use ieee.std_logic_1164.ALL;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.sata_defines.all;

entity PhyLayerInit is
    port(
        rxclkout         : in  std_logic;
        txclkout         : in  std_logic;
        reset            : in  std_logic;

        rx_ordered_data  : out std_logic_vector(31 downto 0);
        primitive_recvd  : out std_logic;

        rx_data          : in  std_logic_vector(31 downto 0);
        rx_datak         : in  std_logic_vector(3 downto 0);
        rx_signaldetect  : in  std_logic;

        tx_forceelecidle : out std_logic;
        tx_data          : out std_logic_vector(31 downto 0);
        tx_datak         : out std_logic_vector(3 downto 0);

        do_word_align    : out std_logic;
        rx_syncstatus    : in std_logic_vector(3 downto 0);

        rx_set_locktodata: out std_logic;
        rx_set_locktoref : out std_logic;

        PHYRDY           : out std_logic
    );
end entity PhyLayerInit;

architecture PhyLayerInit_arch of PhyLayerInit is

    signal phyInitState     : PHYINIT_STATE_TYPE := HP1_HR_RESET;
    signal phyInitNextState : PHYINIT_STATE_TYPE := HP1_HR_RESET;
    signal phyInitPrevState : PHYINIT_STATE_TYPE := HP1_HR_RESET;

    signal ResumePending : std_logic := '0';

    signal oobSignalToSend  : OOB_SIGNAL := NONE;
    signal oobSignalReceived: OOB_SIGNAL := NONE;

    signal oobRxIdle : std_logic;
    signal oobTxIdle : std_logic;


    signal forceQuiescent   : std_logic  := '0';
    signal forceActive      : std_logic  := '0';
    signal tx_forceelecidle_oobDetector : std_logic := '0';

    signal retryTimeElapsed : std_logic_vector(31 downto 0) := (others => '0');

    signal consecutiveNonAligns : std_logic_vector(3 downto 0) := (others => '0');

    signal rx_ordered_data_s  : std_logic_vector(31 downto 0);
    signal primitive_recvd_s : std_logic;
    signal do_byte_order   : std_logic;
    signal is_byte_ordered : std_logic;

    component byte_orderer is
        port(
            rxclkout         : in  std_logic;
            reset            : in  std_logic;
            do_byte_order    : in  std_logic;

            rx_data          : in  std_logic_vector(31 downto 0);
            rx_datak         : in  std_logic_vector(3 downto 0);

            is_byte_ordered  : out std_logic;
            rx_ordered_data  : out std_logic_vector(31 downto 0);
            primitive_recvd_s: out std_logic

    component OOB_SignalDetect is
      port(
        rxclkout         : in  std_logic;
        txclkout         : in  std_logic;
        reset            : in  std_logic;

        rx_data          : in  std_logic_vector(31 downto 0);
        rx_signaldetect  : in  std_logic;

        oobSignalToSend  : in  OOB_SIGNAL;
        oobRxIdle        : out std_logic;
        oobTxIdle        : out std_logic;

        oobSignalReceived: out OOB_SIGNAL;

        tx_forceelecidle : out std_logic
        );
    end component OOB_SignalDetect;

    begin

    process(txclkout, reset)
    begin
        if(reset = '1') then
            tx_forceelecidle <= '0';
        elsif(rising_edge(txclkout)) then
            if(forceQuiescent = '1' and oobTxIdle = '1') then
                tx_forceelecidle <= '1';
            elsif(forceActive = '1') then
                tx_forceelecidle <= '0';
            else
                tx_forceelecidle <= tx_forceelecidle_oobDetector;
            end if;
        end if;
    end process;

    byteOrder1 : byte_orderer
        port map(
            rxclkout         => rxclkout,
            reset            => reset,
            do_byte_order    => do_byte_order,

            rx_data          => rx_data,
            rx_datak         => rx_datak,

            is_byte_ordered  => is_byte_ordered,
            rx_ordered_data  => rx_ordered_data_s,
            primitive_recvd  => primitive_recvd_s 
        );

    process(rxclkout, reset)
    begin
        if(reset = '1') then
            rx_ordered_data <= (others => '0');
            primitive_recvd <= '0';
            consecutiveNonAligns <= (others => '0');
        elsif(rising_edge(rxclkout)) then
            rx_ordered_data <= rx_ordered_data_s;
            primitive_recvd <= primitive_recvd_s;
            if(rx_ordered_data_s(7 downto 0) = DATAK_28_3) then
                consecutiveNonAligns <= consecutiveNonAligns + 1;
            else
                consecutiveNonAligns <= (others => '0');
            end if;
        end if;
    end process;

    signalDetect1 : OOB_SignalDetect
        port map(
            rxclkout            => rxclkout,
            txclkout            => txclkout,
            reset               => reset,

            rx_data             => rx_data,
            rx_signaldetect     => rx_signaldetect,

            oobSignalToSend     => oobSignalToSend,
            oobRxIdle           => oobRxIdle,
            oobTxIdle           => oobTxIdle,

            oobSignalReceived   => oobSignalReceived,
            tx_forceelecidle    => tx_forceelecidle_oobDetector
        );

    -- RetryInterval Counter
    process(txclkout, reset)
    begin
        if(reset = '1') then
            retryTimeElapsed <= (others => '0');
        elsif(rising_edge(txclkout)) then
            if(phyInitState = phyInitPrevState) then
                retryTimeElapsed <= retryTimeElapsed + 1;
            else
                retryTimeElapsed <= (others => '0');
            end if;
        end if;
    end process;



    -- State Register
    process(txclkout, reset)
    begin
        if(reset = '1') then
            phyInitState <= HP1_HR_RESET;
            phyInitPrevState <= HP1_HR_RESET;
        elsif(rising_edge(txclkout)) then
            phyInitState <= phyInitNextState;
            phyInitPrevState <= phyInitState;
        end if;
    end process;

    -- Output Logic
    process(txclkout, reset)
    begin
        if(reset = '1') then
            forceQuiescent <= '1';
            forceActive    <= '0';
            oobSignalToSend <= NONE;
            tx_data <= (others => '0');
            PHYRDY <= '0';
            rx_set_locktodata <= '0';
            rx_set_locktoref  <= '0';
            do_word_align <= '0';
            do_byte_order <= '0';
        elsif(rising_edge(txclkout)) then
            case phyInitState is
                when    HP1_HR_Reset                =>
                -- transmit COMRESET
                    rx_set_locktodata <= '0';
                    rx_set_locktoref  <= '1';
                    forceQuiescent <= '0';
                    forceActive    <= '0';
                    tx_data <= ALIGNp;
                    tx_datak <= DATAK_BYTE_ZERO;
                    oobSignalToSend <= COMRESET;
                    do_word_align <= '0';
                    do_byte_order <= '0';
                when    HP2_HR_AwaitCOMINIT         =>
                -- Quiescent
                    forceQuiescent <= '1';
                    forceActive    <= '0';
                    tx_data <= ALIGNp;
                    tx_datak <= DATAK_BYTE_ZERO;
                    oobSignalToSend <= NONE;
                when    HP2B_HR_AwaitNoCOMINIT      =>
                --Quiescent
                    forceQuiescent <= '1';
                    forceActive    <= '0';
                    tx_data <= ALIGNp;
                    tx_datak <= DATAK_BYTE_ZERO;
                    oobSignalToSend <= NONE;
                when    HP3_HR_Calibrate            =>
                -- Sending out Calibration Signals
                -- NOT SUPPORTED FOR NOW
                    forceQuiescent <= '1';
                    forceActive    <= '0';
                    tx_data <= ALIGNp;
                    tx_datak <= DATAK_BYTE_ZERO;
                    oobSignalToSend <= NONE;
                when    HP4_HR_COMWAKE              =>
                -- Transmit COMWAKE
                    forceQuiescent <= '0';
                    forceActive    <= '0';
                    tx_data <= ALIGNp;
                    tx_datak <= DATAK_BYTE_ZERO;
                    oobSignalToSend <= COMWAKE;
                when    HP5_HR_AwaitCOMWAKE         =>
                -- Quiescent
                    forceQuiescent <= '1';
                    forceActive    <= '0';
                    tx_data <= ALIGNp;
                    tx_datak <= DATAK_BYTE_ZERO;
                    oobSignalToSend <= NONE;
                when    HP5B_HR_AwaitNoCOMWAKE      =>
                -- Quiescent
                    forceActive    <= '0';
                    forceQuiescent <= '1';
                    tx_data <= ALIGNp;
                    tx_datak <= DATAK_BYTE_ZERO;
                    oobSignalToSend <= NONE;
                when    HP6_HR_AwaitAlign           =>
                -- Transmit d10.2 words! (tx_data <= 0h'4A4A4A4A')???
                    forceQuiescent <= '0';
                    forceActive    <= '1';
                    tx_data <= x"4A4A4A4A";
                    tx_datak <= DATAK_BYTE_NONE;
                    oobSignalToSend <= NONE;
                    rx_set_locktodata <= '1';
                    rx_set_locktoref  <= '0';
                    do_word_align <= '1';
                    if(rx_syncstatus = ALL_WORDS_SYNC) then
                        do_byte_order <= '1';
                    else
                        do_byte_order <= '0';
                    end if;
                when    HP7_HR_SendAlign            =>
                -- Transmit ALIGNp
                    forceQuiescent <= '0';
                    forceActive    <= '1';
                    tx_data <= ALIGNp;
                    tx_datak <= DATAK_BYTE_ZERO;
                    oobSignalToSend <= NONE;
                    do_word_align <= '0';
                    do_byte_order <= '0';
                when    HP8_HR_Ready                =>
                -- tx_data <= tx_data (from link layer);
                    forceQuiescent <= '0';
                    forceActive    <= '1';
                    tx_data <= SYNCp;
                    tx_datak <= DATAK_BYTE_ZERO;
                    oobSignalToSend <= NONE;
                    PHYRDY <= '1';
                when    HP9_HR_Partial              =>
                -- not supported
                    forceQuiescent <= '1';
                    tx_data <= ALIGNp;
                    tx_datak <= DATAK_BYTE_ZERO;
                    oobSignalToSend <= NONE;
                when    HP10_HR_Slumber             =>
                -- not supported
                    forceQuiescent <= '1';
                    tx_data <= ALIGNp;
                    tx_datak <= DATAK_BYTE_ZERO;
                    oobSignalToSend <= NONE;
                when    HP11_HR_AdjustSpeed         =>
                -- not supported
                    forceQuiescent <= '1';
                    tx_data <= ALIGNp;
                    tx_datak <= DATAK_BYTE_ZERO;
                    oobSignalToSend <= NONE;
                when    others                      =>
                -- not supported
                    forceQuiescent <= '1';
                    tx_data <= ALIGNp;
                    tx_datak <= DATAK_BYTE_ZERO;
                    oobSignalToSend <= NONE;
                    PHYRDY <= '0';
            end case;
        end if;
    end process;

    -- Next State Logic
    process(phyInitState, phyInitPrevState, oobSignalReceived, retryTimeElapsed, oobRxIdle, oobTxIdle, ResumePending, consecutiveNonAligns, is_byte_ordered, rx_syncstatus)
    begin
        case phyInitState is
            when    HP1_HR_Reset                =>
                if(oobTxIdle = '1') then
                    phyInitNextState <= HP2_HR_AwaitCOMINIT;
                else
                    phyInitNextState <= HP1_HR_Reset;
                end if;

            when    HP2_HR_AwaitCOMINIT         =>
                if(oobSignalReceived = COMINIT) then
                    phyInitNextState <= HP2B_HR_AwaitNoCOMINIT;
                elsif(retryTimeElapsed >= RETRY_INTERVAL and phyInitState = phyInitPrevState) then
                    phyInitNextState <= HP1_HR_Reset;
                else
                    phyInitNextState <= HP2_HR_AwaitCOMINIT;
                end if;

            when    HP2B_HR_AwaitNoCOMINIT      =>
                if(oobRxIdle = '1') then
                    phyInitNextState <= HP4_HR_COMWAKE;
                else
                    phyInitNextState <= HP2B_HR_AwaitNoCOMINIT;
                end if;

            when    HP3_HR_Calibrate            =>
            -- NOT SUPPORTED FOR NOW, should NEVER end up here since HP2B bypasses this step
                phyInitNextState <= HP4_HR_COMWAKE;

            when    HP4_HR_COMWAKE              =>
                if(oobTxIdle = '0') then
                    phyInitNextState <= HP4_HR_COMWAKE;
                elsif(oobSignalReceived = COMWAKE) then
                    phyInitNextState <= HP5B_HR_AwaitNoCOMWAKE;
                else
                    phyInitNextState <= HP5_HR_AwaitCOMWAKE;
                end if;

            when    HP5_HR_AwaitCOMWAKE         =>
                if(oobSignalReceived = COMWAKE) then
                    phyInitNextState <= HP5B_HR_AwaitNoCOMWAKE;
                elsif(retryTimeElapsed > RETRY_INTERVAL and phyInitState = phyInitPrevState) then
                    if(ResumePending = '0') then
                        phyInitNextState <= HP1_HR_RESET;
                    else
                        phyInitNextState <= HP4_HR_COMWAKE;
                    end if;
                else
                    phyInitNextState <= HP5_HR_AwaitCOMWAKE;
                end if;

            when    HP5B_HR_AwaitNoCOMWAKE      =>
                if(oobRxIdle = '1') then
                    phyInitNextState <= HP6_HR_AwaitAlign;
                else
                    phyInitNextState <= HP5B_HR_AwaitNoCOMWAKE;
                end if;

            when    HP6_HR_AwaitAlign           =>
                if(rx_syncstatus = ALL_WORDS_SYNC and is_byte_ordered = '1') then
                    phyInitNextState <= HP7_HR_SendAlign;
                elsif(retryTimeElapsed > ALIGN_INTERVAL and phyInitState = phyInitPrevState) then
                    phyInitNextState <= HP1_HR_RESET;
                else
                    phyInitNextState <= HP6_HR_AwaitAlign;
                end if;

            when    HP7_HR_SendAlign            =>
                if(consecutiveNonAligns >= 3) then
                    phyInitNextState <= HP8_HR_Ready;
                else
                    phyInitNextState <= HP7_HR_SendAlign;
                end if;

            when    HP8_HR_Ready                =>
                phyInitNextState <= HP8_HR_Ready;

            when    HP9_HR_Partial              =>
                -- currently not supported. Should never end here
                phyInitNextState <= HP1_HR_Reset;
            when    HP10_HR_Slumber             =>
                -- currently not supported. Should never end here
                phyInitNextState <= HP1_HR_Reset;
            when    HP11_HR_AdjustSpeed         =>
                -- currently not supported. Should never end here
                phyInitNextState <= HP1_HR_Reset;
            when    others                      =>
                -- currently not supported. Should never end here
                phyInitNextState <= HP1_HR_Reset;
        end case;
    end process;
end architecture PhyLayerInit_arch;
