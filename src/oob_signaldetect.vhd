library ieee;
use ieee.std_logic_1164.ALL;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.sata_defines.all;

entity OOB_SignalDetect is
    port(
        rxclkout         : in  std_logic;
        txclkout         : in  std_logic;
        reset            : in  std_logic;

        rx_parallel_data : in  std_logic_vector(31 downto 0);
        rx_signaldetect  : in  std_logic;

        oobSignalToSend  : in  OOB_SIGNAL;
        readyForNewSignal: out std_logic;
        oobRxIdle        : out std_logic;
        oobTxIdle        : out std_logic;

        oobSignalReceived: out OOB_SIGNAL;

        tx_forceelecidle : out std_logic
    );
end entity OOB_SignalDetect;

architecture OOB_SignalDetect_arch of OOB_SignalDetect is


    signal sendingSignal : OOB_SIGNAL := NONE;
    signal receivingSignal : OOB_SIGNAL := NONE;

    signal txState : OOB_STATE_TYPE := IDLE;
    signal txNextState : OOB_STATE_TYPE := IDLE;

    signal rx_signaldetect_prev : std_logic;

    signal UICountSent : std_logic_vector(15 downto 0);
    signal pausesSent  : std_logic_vector(7 downto 0);
    signal pulsesSent  : std_logic_vector(7 downto 0);

    signal UICountRecvd : std_logic_vector(15 downto 0);
    signal pausesRecvd  : std_logic_vector(7 downto 0);
    signal pulsesRecvd  : std_logic_vector(7 downto 0);

begin
    -- State Register
    process(txclkout, reset)
    begin
        if(rising_edge(txclkout)) then
            if(reset = '1') then
                txState <= IDLE;
            else
                txState <= txNextState;
            end if;
        end if;
    end process;

    -- Count Received Pauses/Signals
    process(rxclkout, reset)
    begin
        if(rising_edge(rxclkout)) then
            if(reset = '1') then
                UICountRecvd <= (others => '0');
                pausesRecvd  <= (others => '0');
                pulsesRecvd  <= (others => '0');
            else
                rx_signaldetect_prev <= rx_signaldetect;
                if(rx_signaldetect = rx_signaldetect_prev) then
                    UICountRecvd <= UICountRecvd + 1;
                else -- detect switch
                    UICountRecvd <= (others => '0');
                    if(rx_signaldetect = '0') then -- pulse just finished
                        if(UICountRecvd > MIN_DETECT_PULSE_COUNT and UICountRecvd < MAX_DETECT_PULSE_COUNT) then
                            pulsesRecvd <= pulsesRecvd + 1;
                        else
                            -- error on number of pulses received...
                            receivingSignal <= NONE;
                            pulsesRecvd <= (others => '0');
                            pausesRecvd <= (others => '0');
                            UICountRecvd <= (others => '0');
                        end if;
                    else -- pause just finished
                        if(UICountRecvd > MIN_COMINIT_DETECT_PAUSE_COUNT and UICountRecvd < MAX_COMINIT_DETECT_PAUSE_COUNT) then
                            if(receivingSignal = NONE or receivingSignal = COMINIT) then
                                pausesRecvd <= pausesRecvd + 1;
                                receivingSignal <= COMINIT;
                            else
                                receivingSignal <= NONE;
                                pulsesRecvd <= (others => '0');
                                pausesRecvd <= (others => '0');
                                UICountRecvd <= (others => '0');
                            end if;
                        elsif(UICountRecvd > MIN_COMWAKE_DETECT_PAUSE_COUNT and UICountRecvd < MAX_COMWAKE_DETECT_PAUSE_COUNT) then
                            if(receivingSignal = NONE or receivingSignal = COMWAKE) then
                                pausesRecvd <= pausesRecvd + 1;
                                receivingSignal <= COMWAKE;
                            else
                                receivingSignal <= NONE;
                                pulsesRecvd <= (others => '0');
                                pausesRecvd <= (others => '0');
                                UICountRecvd <= (others => '0');
                            end if;
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- transmit necessary signals
    process(txclkout, reset)
    begin
        if(rising_edge(txclkout)) then
            if(reset = '1') then
                UICountSent  <= (others => '0');
                pausesSent   <= (others => '0');
                pulsesSent   <= (others => '0');
            else
                case txState is
                    when IDLE       =>
                        UICountSent <= (others => '0');
                        pausesSent <= (others => '0');
                        pulsesSent <= (others => '0');
                        if(oobSignalToSend = COMWAKE or oobSignalToSend = COMRESET) then
                            sendingSignal <= oobSignalToSend;
                        end if;
                        tx_forceelecidle <= '1';

                    when SEND_PULSE =>
                        if(UICountSent = TRANSMIT_PULSE_COUNT) then
                            UICountSent <= (others =>'0');
                            pulsesSent <= pulsesSent + 1;
                        else
                            UICountSent <= UICountSent + 1;
                        end if;
                        tx_forceelecidle <= '0';

                    when SEND_PAUSE =>
                        if(UICountSent = COMWAKE_PAUSE_COUNT and sendingSignal = COMWAKE) then
                            UICountSent <= (others => '0');
                            pausesSent <= pausesSent + 1;
                        elsif(UICountSent = COMRESET_PAUSE_COUNT and sendingSignal = COMRESET) then
                            UICountSent <= (others => '0');
                            pausesSent <= pausesSent + 1;
                        else
                            UICountSent <= UICountSent + 1;
                        end if;
                        tx_forceelecidle <= '1';

                    when others     =>
                        tx_forceelecidle <= '0';
                end case;

            end if;
        end if;
    end process;



    -- Next State Logic
    process(UICountSent, pausesSent, pulsesSent, oobSignalToSend, txState, sendingSignal)
    begin
        case(txState) is
            when IDLE =>
                if(oobSignalToSend = COMWAKE or oobSignalToSend = COMRESET) then
                    txNextState <= SEND_PULSE;
                else
                    txNextState <= IDLE;
                end if;
            when SEND_PULSE =>
                if (UICountSent = TRANSMIT_PULSE_COUNT) then
                    txNextState <= SEND_PAUSE;
                else
                    txNextState <= SEND_PULSE;
                end if;

            when SEND_PAUSE =>
                if(sendingSignal = COMWAKE) then
                    if(UICountSent < COMWAKE_PAUSE_COUNT) then
                        txNextState <= SEND_PAUSE;
                    else
                        if(pausesSent >= NUM_PAUSES_TO_SEND and pulsesSent >= NUM_PULSES_TO_SEND) then
                            txNextState <= IDLE;
                        else
                            txNextState <= SEND_PULSE;
                        end if;
                    end if;
                else -- sendingSignal = COMRESET
                    if(UICountSent < COMRESET_PAUSE_COUNT) then
                        txNextState <= SEND_PAUSE;
                    else
                        if(pausesSent >= NUM_PAUSES_TO_SEND and pulsesSent >= NUM_PULSES_TO_SEND) then
                            txNextState <= IDLE;
                        else
                            txNextState <= SEND_PULSE;
                        end if;
                    end if;
                end if;
            when others =>
                txNextState <= IDLE;
        end case;
    end process;

    readyForNewSignal <= '1' when txState = IDLE else
                         '0';


    oobSignalReceived <= COMINIT when (pausesRecvd = 6) and receivingSignal = COMINIT else
                         COMWAKE when (pausesRecvd = 6) and receivingSignal = COMWAKE else
                         NONE;

    -- idle when >525ns have passed, which is 20*40 GEN 1 UI
    oobRxIdle <= '1' when UICountRecvd >= MIN_IDLE_DETECT_COUNT and rx_signaldetect = '0' else
                 '0';

    -- idle when txState = IDLE
    oobTxIdle <= '1' when txState = IDLE else
                 '0';



end architecture OOB_SignalDetect_arch;