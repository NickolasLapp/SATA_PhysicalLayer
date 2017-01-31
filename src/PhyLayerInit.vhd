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

        rx_parallel_data : in  std_logic_vector(31 downto 0);
        rx_signaldetect  : in  std_logic;

        tx_forceelecidle : out std_logic;
        tx_parallel_data : out std_logic_vector(31 downto 0);

        rx_bitslip       : out std_logic;

        PHYRDY         : out std_logic
    );
end entity PhyLayerInit;

architecture PhyLayerInit_arch of PhyLayerInit is

    signal phyInitState     : PHYINIT_STATE_TYPE := HP1_HR_RESET;
    signal phyInitNextState : PHYINIT_STATE_TYPE := HP1_HR_RESET;
    signal phyInitPrevState : PHYINIT_STATE_TYPE := HP1_HR_RESET;

    signal ResumePending : std_logic := '0';

    signal oobSignalToSend  : OOB_SIGNAL := NONE;
    signal oobSignalReceived: OOB_SIGNAL := NONE;
    signal readyForNewSignal: std_logic;

    signal oobRxIdle : std_logic;
    signal oobTxIdle : std_logic;


    signal forceQuiescent   : std_logic  := '0';
    signal forceActive      : std_logic  := '0';
    signal tx_forceelecidle_oobDetector : std_logic := '0';

    signal retryTimeElapsed : std_logic_vector(31 downto 0) := (others => '0');

    signal bitslip_reset            : std_logic;
    signal bitslip_parallel_data_in : std_logic_vector(31 downto 0);
    signal bitslip_done     : std_logic;
    signal bitslip_rx_bitslip : std_logic;
    signal AlignpDetected : std_logic;
    signal consecutiveNonAligns : std_logic_vector(7 downto 0) := (others => '0');


    component OOB_SignalDetect is
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
    end component OOB_SignalDetect;

    component bitslip_gen is
    port(
        clk : in std_logic;
        reset: in std_logic;
        data_in : in std_logic_vector(31 downto 0);
        bitslip : out std_logic;
        bitslip_done : out std_logic
    );
    end component bitslip_gen;

    begin

    tx_forceelecidle <= '1' when forceQuiescent = '1' and oobTxIdle = '1' else
                        '0' when forceActive    = '1' else
                        tx_forceelecidle_oobDetector;

    signalDetect1 : OOB_SignalDetect
        port map(
            rxclkout            => rxclkout,
            txclkout            => txclkout,
            reset               => reset,

            rx_parallel_data    => rx_parallel_data,
            rx_signaldetect     => rx_signaldetect,

            oobSignalToSend     => oobSignalToSend,
            readyForNewSignal   => readyForNewSignal,
            oobRxIdle           => oobRxIdle,
            oobTxIdle           => oobTxIdle,

            oobSignalReceived   => oobSignalReceived,
            tx_forceelecidle    => tx_forceelecidle_oobDetector
        );

    bitslipGen1 : bitslip_gen
        port map(
            clk    => rxclkout,
            reset  => reset,
            data_in => bitslip_parallel_data_in,
            bitslip => bitslip_rx_bitslip,
            bitslip_done => bitslip_done
        );


    -- RetryInterval Counter
    process(txclkout, reset)
    begin
        if(reset = '1') then
            retryTimeElapsed <= (others => '0');
        elsif(rising_edge(txclkout)) then
            if(phyInitState = phyInitNextState) then
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
            phyInitPrevState <= phyInitState;
            phyInitState <= phyInitNextState;
        end if;
    end process;

    -- Output Logic
    process(txclkout, reset)
    begin
        if(reset = '1') then
            forceQuiescent <= '1';
            forceActive    <= '0';
            oobSignalToSend <= NONE;
            tx_parallel_data <= (others => '0');
        elsif(rising_edge(txclkout)) then
            case phyInitState is
                when    HP1_HR_Reset                =>
                -- transmit COMRESET
                    forceQuiescent <= '0';
                    forceActive    <= '0';
                    tx_parallel_data <= ALIGNp;
                    oobSignalToSend <= COMRESET;
                when    HP2_HR_AwaitCOMINIT         =>
                -- Quiescent
                    forceQuiescent <= '1';
                    forceActive    <= '0';
                    tx_parallel_data <= ALIGNp;
                    oobSignalToSend <= NONE;
                when    HP2B_HR_AwaitNoCOMINIT      =>
                --Quiescent
                    forceQuiescent <= '1';
                    forceActive    <= '0';
                    tx_parallel_data <= ALIGNp;
                    oobSignalToSend <= NONE;
                when    HP3_HR_Calibrate            =>
                -- Sending out Calibration Signals
                -- NOT SUPPORTED FOR NOW
                    forceQuiescent <= '1';
                    forceActive    <= '0';
                    tx_parallel_data <= ALIGNp;
                    oobSignalToSend <= NONE;
                when    HP4_HR_COMWAKE              =>
                -- Transmit COMWAKE
                    forceQuiescent <= '0';
                    forceActive    <= '0';
                    tx_parallel_data <= ALIGNp;
                    oobSignalToSend <= COMWAKE;
                when    HP5_HR_AwaitCOMWAKE         =>
                -- Quiescent
                    forceQuiescent <= '1';
                    forceActive    <= '0';
                    tx_parallel_data <= ALIGNp;
                    oobSignalToSend <= NONE;
                when    HP5B_HR_AwaitNoCOMWAKE      =>
                -- Quiescent
                    forceActive    <= '0';
                    forceQuiescent <= '1';
                    tx_parallel_data <= ALIGNp;
                    oobSignalToSend <= NONE;
                when    HP6_HR_AwaitAlign           =>
                -- Transmit d10.2 words! (tx_parallel_data <= 0h'4A4A4A4A')???
                    forceQuiescent <= '0';
                    forceActive    <= '1';
                    tx_parallel_data <= x"4A4A4A4A";
                    oobSignalToSend <= NONE;
                when    HP7_HR_SendAlign            =>
                -- Transmit ALIGNp
                    forceQuiescent <= '0';
                    forceActive    <= '1';
                    tx_parallel_data <= ALIGNp;
                    oobSignalToSend <= NONE;
                when    HP8_HR_Ready                =>
                -- tx_parallel_data <= tx_parallel_data (from link layer);
                    forceQuiescent <= '0';
                    forceActive    <= '1';
                    tx_parallel_data <= ALIGNp;
                    oobSignalToSend <= NONE;
                when    HP9_HR_Partial              =>
                -- not supported
                    forceQuiescent <= '1';
                    tx_parallel_data <= ALIGNp;
                    oobSignalToSend <= NONE;
                when    HP10_HR_Slumber             =>
                -- not supported
                    forceQuiescent <= '1';
                    tx_parallel_data <= ALIGNp;
                    oobSignalToSend <= NONE;
                when    HP11_HR_AdjustSpeed         =>
                -- not supported
                    forceQuiescent <= '1';
                    tx_parallel_data <= ALIGNp;
                    oobSignalToSend <= NONE;
                when    others                      =>
                -- not supported
                    forceQuiescent <= '1';
                    tx_parallel_data <= ALIGNp;
                    oobSignalToSend <= NONE;
            end case;
        end if;
    end process;

    -- Next State Logic
    process(phyInitState, readyForNewSignal, oobSignalReceived, retryTimeElapsed, oobRxIdle, oobTxIdle, ResumePending, AlignpDetected, consecutiveNonAligns)
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
                elsif(retryTimeElapsed >= RETRY_INTERVAL) then
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
                elsif(retryTimeElapsed > RETRY_INTERVAL) then
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
                if(AlignpDetected = '1') then
                    phyInitNextState <= HP7_HR_SendAlign;
                elsif(retryTimeElapsed > ALIGN_INTERVAL) then
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


    bitslip_reset <= '0' when phyInitState = HP6_HR_AwaitAlign and reset = '0' else
                     '1';
    bitslip_parallel_data_in <= rx_parallel_data when phyInitState = HP6_HR_AwaitAlign else
                     (others => '0');
    rx_bitslip <= bitslip_rx_bitslip when phyInitState = HP6_HR_AwaitAlign else
               '0';

    AlignpDetected <= '1' when (bitslip_done = '1') and (phyInitState = HP6_HR_AwaitAlign) else
                      '0';

    PHYRDY <= '1' when phyInitState = HP8_HR_Ready else
              '0';

end architecture PhyLayerInit_arch;