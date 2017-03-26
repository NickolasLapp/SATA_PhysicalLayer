library ieee;                   --! Use standard library.
use ieee.std_logic_1164.all;    --! Use standard logic elements
use ieee.numeric_std.all;       --! Use numeric standard

use work.transport_layer_pkg.all;
----------------------------------------------------------------------------
--Status Truth Table:
-- XXX0 == Device Not Ready
-- XXX1 == Device Ready
-- XX01 == Write Not Ready
-- XX11 == Write Ready
-- X0X1 == Send Read Not Ready
-- X1X1 == Send Ready Ready
-- 0XX1 == Retrieve Read Not Ready
-- 1XX1 == Retrieve Read Ready

--Command truth table
-- 000 == Do Nothing
-- X01 == Send Write     (Command to write data at specified address in SSD)
-- X10 == Send Read      (Command to retrieve data at specified address from SSD)
-- 1XX == Retrieve Read  (Command to read value from Rx buffer)
----------------------------------------------------------------------------
entity transport_layer is
   port(
        --Interface with Application Layer
        rst_n           :   in std_logic;
        clk         :   in std_logic;

        data_from_user      :   in std_logic_vector(DATA_WIDTH - 1 downto 0);
        address_from_user   :   in std_logic_vector(DATA_WIDTH - 1 downto 0);

        user_command            :   in std_logic_vector(2 downto 0);
        status_to_user          :   out std_logic_vector(3 downto 0);

        data_to_user       :   out std_logic_vector(DATA_WIDTH - 1 downto 0);
        address_to_user    :   out std_logic_vector(DATA_WIDTH - 1 downto 0);

        --Interface with Link Layer
        status_to_link :    out std_logic_vector(7 downto 0); --for test just use bit 0 to indicate data ready
        status_from_link     :   in std_logic_vector(7 downto 0);
        data_to_link     :   out std_logic_vector(DATA_WIDTH - 1 downto 0);
        data_from_link      :   in std_logic_vector(DATA_WIDTH - 1 downto 0));

end transport_layer;

architecture transport_layer_arch of transport_layer is
--States for Transport FSM

  signal current_state, next_state : State_Type;

    --======================================================================================
    --Signals to create Register Host to Device FIS contents
    signal fis_type : std_logic_vector(7 downto 0);

    --Shadow Registers... Somewhat customized for ease of use
    signal feature : std_logic_vector(15 downto 0); -- a reserved field in DMA read ext, DMA write ext. Set to all zeros
    signal lba : std_logic_vector(47 downto 0);   --address to write to / read from
    signal control : std_logic_vector(7 downto 0);  --Field not defined for DMA read/write ext. Thus is "reserved", set to zeros
    signal command : std_logic_vector(7 downto 0);  --35h for dma write ext, 25h dma read ext
    signal c_bit       : std_logic;                 --Set to one when register transfer is due to update of command reg.
    signal count : std_logic_vector(15 downto 0);   --# of logical sectors to be transferred for DMA. 0000h indicates 65.536 sectors --not currently using
    --------------------------------------------------
    --  set bit 6 to 1, bit 4 is Transport Dependent, think it should be zero
    --Bits 7, 5 are obsolete? Currently planning on setting to zero
    signal device: std_logic_vector(7 downto 0);
    --------------------------------------------------
    signal i_bit        : std_logic;                    --used only for device to host
    signal status       : std_logic_vector(7 downto 0); --used only for device to host
    signal error        : std_logic_vector(7 downto 0); --used only for device to host
    --======================================================================================

    signal tx_fis_array, rx_fis_array   :   register_fis_array_type; -- signals to hold host to device register FIS contents

    --======================================================================================
    --Buffers

    signal tx_buffer : double_buffer;
    signal rx_buffer : double_buffer;

    signal tx_write_ptr, tx_read_ptr : integer range 0 to BUFFER_DEPTH;
    signal rx_write_ptr, rx_read_ptr : integer range 0 to BUFFER_DEPTH;
    signal tx_buffer_full, rx_buffer_full, tx_buffer_empty, rx_buffer_empty   : std_logic_vector(1 downto 0);

    signal tx0_locked, tx1_locked, rx0_locked, rx1_locked : std_logic; -- Custom signal to allow SM to take control of buffers
    signal tx_index : integer range 0 to 1; -- custom signal to use as index to array of tx register FISs
    signal rx_index : integer range 0 to 1; -- custom signal to use as index to array of tx register FISs
    --======================================================================================

    --temporary signal for testing
    signal tx0_read_valid, tx1_read_valid, rx0_read_valid, rx1_read_valid : std_logic;

    --
    signal device_ready : std_logic;

    --from link interface status signals
    signal link_rdy, pause, data_from_link_valid : std_logic;

    --to link interface status signals
    signal tx_to_link_request : std_logic;
    signal rx_from_link_ready : std_logic;


    signal paused_data_to_link : std_logic_vector(DATA_WIDTH - 1 downto 0);

    --signals to get this to compile
    signal fis_received : std_logic;
    signal link_fis_type : std_logic_vector(7 downto 0);

    --CONSTANTS UPDATE WITH CORRECT VALUES!!!!!
    constant STATUS_ERR : integer := 0;
    constant STATUS_DF : integer := 0;
    constant STATUS_BSY : integer := 0;

begin

--=================================================================================================================
--Transport Layer Finite State Machine
--=================================================================================================================
    transport_state_memory  :   process(clk, rst_n)
      begin
        if(rst_n = '0') then
            current_state <= transport_reset;
        elsif(rising_edge(clk)) then
            current_state <= next_state;
        end if;
    end process;

    transport_next_state_logic: process (current_state, status_from_link, link_rdy, data_from_link,link_fis_type, user_command,rst_n,
                                         pause, tx_index, rx_index, tx_buffer_full, rx_buffer_full, tx_read_ptr,data_from_link_valid)
      begin

        case (current_state) is
        ----------------------------------------------- -----------------------------------------------
            -- Idle SM states (top level)
        ----------------------------------------------- -----------------------------------------------
            when transport_reset =>
                if(rst_n = '0') then
                    next_state <= transport_reset;
                else
                    next_state <= transport_init_start;
                end if;
            when transport_init_start =>
                --if(data_from_link_valid = '1' and data_from_link(7 downto 0) = REG_DEVICE_TO_HOST)then--received initial status update
                if(data_from_link(7 downto 0) = REG_DEVICE_TO_HOST)then--received initial status update
                    next_state <= transport_init_end;
                else
                    next_state <= transport_init_start;
                end if;
            when transport_init_end =>    --wait until link has finished sending the register device to host FIS
                if(data_from_link_valid = '1' or pause = '1')then
                    next_state <= transport_init_end;
                else
                    next_state <= identify_device_0;
                end if;
            when identify_device_0    =>
                if(link_rdy = '1' and pause = '0')then
                    next_state <= identify_device_1;
                else
                    next_state <= identify_device_0;
                end if;
            when identify_device_1    =>
                if(link_rdy = '1' and pause = '0')then
                    next_state <= identify_device_2;
                else
                    next_state <= identify_device_1;
                end if;
            when identify_device_2    =>
                if(link_rdy = '1' and pause = '0')then
                    next_state <= identify_device_3;
                else
                    next_state <= identify_device_2;
                end if;
            when identify_device_3    =>
                if(link_rdy = '1' and pause = '0')then
                    next_state <= identify_device_4;
                else
                    next_state <= identify_device_3;
                end if;
            when identify_device_4    =>
                if(link_rdy = '1' and pause = '0')then
                    next_state <= rx_pio_setup;
                else
                    next_state <= identify_device_4;
                end if;
            when rx_pio_setup =>
                if(link_fis_type = PIO_SETUP_FIS) then
                    next_state <= rx_identify_packet;
                else
                    next_state <= rx_pio_setup;
                end if;
            when rx_identify_packet =>
                if(link_fis_type = DATA_FIS)then
                    next_state <= wait_for_fis_end;
                else
                    next_state <= rx_identify_packet;
                end if;
            when wait_for_fis_end =>
                if(data_from_link_valid = '1' or pause = '1')then--link still transmitting uninteresting data
                    next_state <= wait_for_fis_end;
                else
                    next_state <= transport_idle;
                end if;
            when transport_idle =>
                --if (status_from_link = x"00000001") then --FIS RECEIVED
                    --next_state <= decode_fis;
                if (tx_buffer_full(0) = '1') then   --User is sending "Write" command --Don't transition to DMA Write until a buffer is full
                    next_state <= dma_write_idle;
                elsif (tx_buffer_full(1) = '1') then
                    next_state <= dma_write_idle;
                elsif (user_command(1 downto 0) = "10") then
                    next_state <= dma_read_idle;
                --elsif (command(2)='1') then
                    --next_state <= read_rx_buffer;
                else
                    next_state <= transport_idle;
                end if;
    ----------------------------------------------- -----------------------------------------------
--========================================================================================
                -- DMA Write EXT SM states
            when dma_write_idle     =>
                next_state <= dma_write_reg_fis_0;
            when dma_write_reg_fis_0    =>
                if(link_rdy = '1' and pause = '0')then
                    next_state <= dma_write_reg_fis_1;
                else
                    next_state <= dma_write_reg_fis_0;
                end if;
            when dma_write_reg_fis_1    =>
                if(pause = '0')then
                    next_state <= dma_write_reg_fis_2;
                else
                    next_state <= dma_write_reg_fis_1;
                end if;
            when dma_write_reg_fis_2    =>
                if(pause = '0')then
                    next_state <= dma_write_reg_fis_3;
                else
                    next_state <= dma_write_reg_fis_2;
                end if;
            when dma_write_reg_fis_3    =>
                if(pause = '0')then
                    next_state <= dma_write_reg_fis_4;
                else
                    next_state <= dma_write_reg_fis_3;
                end if;
            when dma_write_reg_fis_4    =>
                if(pause = '0')then
                    next_state <= dma_write_chk_activate;
                else
                    next_state <= dma_write_reg_fis_4;
                end if;
            when dma_write_chk_activate =>
                if(link_fis_type = DMA_ACTIVATE_FIS) then
                    next_state <= dma_write_data_fis;
                    --next_state <= dma_write_data_idle;
                else
                    next_state <= dma_write_chk_activate;
                end if;
            --when dma_write_data_idle => --Activate received, wait until link is ready for data
            --    if(link_rdy = '1') then
            --        next_state <= dma_write_data_fis;
            --    else
            --        next_state <= dma_write_data_idle;
            --    end if;
            when dma_write_data_fis =>
                if(pause = '0' and link_rdy = '1')then
                    next_state <= dma_write_data_frame;
                else
                    next_state <= dma_write_data_fis;
                end if;
            when dma_write_data_frame   =>
                if(pause = '1')then
                    next_state <= pause_data_tx;
                elsif(tx_read_ptr < BUFFER_DEPTH and (link_rdy = '1' or pause = '1'))then
                    next_state <= dma_write_data_frame;
                else
                    next_state <= dma_write_chk_status;
                end if;
            when dma_write_chk_status   =>
                if(link_fis_type = REG_DEVICE_TO_HOST) then --link_fis_rdy = '1' and data_from_link (7 downto 0)
                    --check error bit and device fault bit in the  Status field.. if error is asserted can check error field
                    --TODO: create constants for ERROR, DEV_FAULT, etc
                    --if(data_from_link(STATUS_ERR) = '1' or data_from_link(STATUS_DF) = '1') then
                    --error occured, update this part!
                    --  next_state <= transport_idle;
                    --elsif(data_from_link(STATUS_BSY) = '0') then
                        next_state <= wait_for_fis_end;   --Go back to transport idle until error functionality added
                    --end if;
                else
                    next_state <= dma_write_chk_status;
                end if;
            when pause_data_tx =>
                if(pause = '0')then
                    next_state <= dma_write_data_frame;
                else
                    next_state <= pause_data_tx;
                end if;
--========================================================================================
            -- DMA Read EXT SM states
            --CHANGELOG:
            --Updated fis tx states to check pause flag
            --
            --TODO:
            when dma_read_idle      =>
                --if (link_rdy = '1' and pause = '0') then --Should pause check be here? depends on link timing
                    next_state <= dma_read_reg_fis_0;
                --else
                --    next_state <= dma_read_idle;
                --end if;
            when dma_read_reg_fis_0 =>
                if(link_rdy = '1' and pause = '0') then
                    next_state <= dma_read_reg_fis_1;
                else
                    next_state <= dma_read_reg_fis_0;
                    --next_state <= pause_fis_tx;
                end if;
            when dma_read_reg_fis_1 =>
                if(pause = '0') then
                    next_state <= dma_read_reg_fis_2;
                else
                    next_state <= dma_read_reg_fis_1;
                    --next_state <= pause_fis_tx;
                end if;
            when dma_read_reg_fis_2 =>
                if(pause = '0') then
                    next_state <= dma_read_reg_fis_3;
                else
                    next_state <= dma_read_reg_fis_2;
                    --next_state <= pause_fis_tx;
                end if;
            when dma_read_reg_fis_3 =>
                if(pause = '0') then
                    next_state <= dma_read_reg_fis_4;
                else
                    next_state <= dma_read_reg_fis_3;
                    --next_state <= pause_fis_tx;
                end if;
            when dma_read_reg_fis_4 =>
                if(pause = '0') then
                    next_state <= dma_read_data_fis;
                else
                    next_state <= dma_read_reg_fis_4;
                    --next_state <= pause_fis_tx;
                end if;
            when dma_read_data_fis  =>
            --add states to read entire fis
                if(data_from_link(7 downto 0)= DATA_FIS) then
                    next_state <= dma_read_data_frame;
                else
                    next_state <= dma_read_data_fis;
                end if;
            when dma_read_data_frame    =>
                --if(rx_full(rx_index) = '0') then
                if(rx_buffer_full(rx_index) = '0' and (data_from_link_valid = '1' or pause = '1'))then
                    next_state <= dma_read_data_frame;
                else
                    next_state <= dma_read_chk_status;
                end if;
            when dma_read_chk_status    =>
                if(link_fis_type = REG_DEVICE_TO_HOST) then
                    --check error bit and device fault bit in the  Status field.. if error is asserted can check error field
                    --TODO: create constants for ERROR, DEV_FAULT, etc
                    if(data_from_link(STATUS_ERR) = '1' or data_from_link(STATUS_DF) = '1') then
                    --error occured, add error state
                        next_state <= wait_for_fis_end;
                    elsif(data_from_link(STATUS_BSY) = '0') then
                        next_state <= wait_for_fis_end;   --Go back to transport idle until error state added
                    else
                        next_state <= dma_read_chk_status;  --should not get here
                    end if;
                else
                    next_state <= dma_read_chk_status;
                end if;
--=======================================================================================
            when others =>  next_state <= transport_idle;
        end case;
    end process;
--=================================================================================================================
    transport_output_logic: process(clk,rst_n)
      begin
        if(rst_n = '0')then
            rx0_locked <= '0';
            rx1_locked <= '0';
            tx0_locked <= '0';
            tx1_locked <= '0';

            --temporary signals for testing, may use later
            rx0_read_valid <= '0';
            rx1_read_valid <= '0';

            rx_from_link_ready <= '0';
            tx_to_link_request <= '0';

            tx_buffer_empty <= "11";
            rx_buffer_full <= "00";

            tx_read_ptr <= 0;
            rx_write_ptr <= 0;

            tx_index <= 0;
            device_ready <= '0';
            data_to_link <= (others => '0');
        elsif(rising_edge(clk))then
        case (current_state) is
        ----------------------------------------------- -----------------------------------------------
            -- Idle SM states (top level)
        ----------------------------------------------- -----------------------------------------------
            when transport_reset =>
                rx0_locked <= '0';
                rx1_locked <= '0';
                tx0_locked <= '0';
                tx1_locked <= '0';

                --temporary signal for testing
                rx0_read_valid <= '0';
                rx1_read_valid <= '0';


                rx_from_link_ready <= '0';
                tx_to_link_request <= '0';

                tx_buffer_empty <= "11";
                rx_buffer_full <= "00";

                tx_read_ptr <= 0;
                rx_write_ptr <= 0;

                tx_index <= 0;
                device_ready <= '0';
                data_to_link <= (others => '0');
            when transport_init_start =>
                rx_from_link_ready <= '1';
                tx_fis_array(tx_index).fis_type <= REG_HOST_TO_DEVICE;
                tx_fis_array(tx_index).crrr_pm <= x"80"; --80 sets C bit
                tx_fis_array(tx_index).command <= IDENTIFY_DEVICE;
                tx_fis_array(tx_index).features <= x"00";
                tx_fis_array(tx_index).lba <= (others => '0');
                tx_fis_array(tx_index).device <= x"E0";
                tx_fis_array(tx_index).features_ext <= x"00";
                tx_fis_array(tx_index).lba_ext <= (others => '0');
                tx_fis_array(tx_index).count <= (others => '0'); --on most drives 1 logical sector := 512 bytes
                tx_fis_array(tx_index).icc <= x"00";
                tx_fis_array(tx_index).control <= x"00";
                tx_fis_array(tx_index).aux <= x"00000000";
            when transport_init_end =>
                rx_from_link_ready <= '1';
                data_to_link <= (others => '1');
            when identify_device_0 =>
                rx_from_link_ready <= '0';
                tx_to_link_request <= '1';
                data_to_link <= tx_fis_array(tx_index).features & tx_fis_array(tx_index).command &
                               tx_fis_array(tx_index).crrr_pm & tx_fis_array(tx_index).fis_type;
            when identify_device_1 =>
                data_to_link <= tx_fis_array(tx_index).device & tx_fis_array(tx_index).lba;
            when identify_device_2 =>
                data_to_link <= tx_fis_array(tx_index).features_ext &
                                tx_fis_array(tx_index).lba_ext;
            when identify_device_3 =>
                data_to_link <= tx_fis_array(tx_index).control & tx_fis_array(tx_index).icc &
                                tx_fis_array(tx_index).count;
            when identify_device_4 =>
                data_to_link <= tx_fis_array(tx_index).aux;
            when rx_pio_setup =>
                tx_to_link_request <= '0';
                rx_from_link_ready <= '1';
                data_to_link <= x"AAAAAAAA";
            when rx_identify_packet =>
                data_to_link <= x"BBBBBBBB";
            when wait_for_fis_end =>
                tx_to_link_request <= '0';
                rx_from_link_ready <= '1';
                data_to_link <= x"00BEEF00";
            when transport_idle =>
                device_ready <= '1';
                rx_from_link_ready <= '0';
                tx_to_link_request <= '0';

                if(rx_buffer_empty(0) = '1')then rx_buffer_full(0) <= '0'; end if;
                if(rx_buffer_empty(1) = '1')then rx_buffer_full(1) <= '0'; end if;

                --if (status_from_link = FIS_RDY) then --FIS RECEIVED
                if (tx_buffer_full(0) = '1') then   --User is sending "Write" command --Don't transition to DMA Write until a buffer is full
                    --lock tx0 buffer
                    tx0_locked <= '1';
                    tx_buffer_empty(0) <= '0';
                    --set buffer index to zero
                    tx_index <= 0;
                    --Proceed to DMA Write
                elsif (tx_buffer_full(1) = '1') then
                        --lock tx1 buffer
                        tx1_locked <= '1';
                        tx_buffer_empty(0) <= '0';
                        --set buffer index to 1
                        tx_index <= 1;
                elsif (user_command(1 downto 0) = "10") then
                    --lock rx buffer
                    --rx_locked <= '1';
                    --build read register FIS?
                else
                    --next_state <= transport_idle;
                end if;
    ----------------------------------------------- --------------------------------------
--========================================================================================
            -- DMA Write EXT SM states
            when dma_write_idle     =>
                --build register host to device DMA Write FIS
                tx_read_ptr <= 0;
                tx_fis_array(tx_index).fis_type <= REG_HOST_TO_DEVICE;
                tx_fis_array(tx_index).crrr_pm <= x"80"; --80 sets C bit
                tx_fis_array(tx_index).command <= WRITE_DMA_EXT;
                tx_fis_array(tx_index).features <= x"00";
                tx_fis_array(tx_index).lba <= lba(23 downto 0);
                tx_fis_array(tx_index).device <= x"E0";
                tx_fis_array(tx_index).features_ext <= x"00";
                tx_fis_array(tx_index).lba_ext <= lba(47 downto 24);
                tx_fis_array(tx_index).count <= WRITE_SECTOR_COUNT; --on most drives 1 logical sector := 512 bytes
                tx_fis_array(tx_index).icc <= x"00";
                tx_fis_array(tx_index).control <= x"00";
                tx_fis_array(tx_index).aux <= x"00000000";
            when dma_write_reg_fis_0    =>
                tx_to_link_request <= '1';
                data_to_link <= tx_fis_array(tx_index).features & tx_fis_array(tx_index).command &
                               tx_fis_array(tx_index).crrr_pm & tx_fis_array(tx_index).fis_type;
            when dma_write_reg_fis_1    =>
                data_to_link <= tx_fis_array(tx_index).device & tx_fis_array(tx_index).lba;
            when dma_write_reg_fis_2    =>
                data_to_link <= tx_fis_array(tx_index).features_ext &
                               tx_fis_array(tx_index).lba_ext;
            when dma_write_reg_fis_3    =>
                data_to_link <= tx_fis_array(tx_index).control & tx_fis_array(tx_index).icc &
                               tx_fis_array(tx_index).count;
            when dma_write_reg_fis_4    =>
                data_to_link <= tx_fis_array(tx_index).aux;
            when dma_write_chk_activate =>
                tx_to_link_request <= '0';
                rx_from_link_ready <= '1';
                data_to_link <= x"F0F0F0F0";
            --when dma_write_data_idle => --Activate received, wait until link is ready for data
            --    rx_from_link_ready <= '0';
            --    data_to_link <= x"0F0F0F0F";
            when dma_write_data_fis =>
                rx_from_link_ready <= '0';
                tx_to_link_request <= '1';
                data_to_link <=  x"000000" & DATA_FIS;
            when dma_write_data_frame   =>
                if(pause = '0') then
                    if(tx_read_ptr < BUFFER_DEPTH)then
                        data_to_link <= tx_buffer(tx_index)(tx_read_ptr);
                        tx_read_ptr <= tx_read_ptr + 1;
                    else
                        tx_to_link_request <= '0';
                        if(tx_index = 0) then
                            tx0_locked <= '0';
                        else
                            tx1_locked <= '0';
                        end if;
                    end if;
                else
                    paused_data_to_link <= tx_buffer(tx_index)(tx_read_ptr);
                end if;
            when dma_write_chk_status   =>  ----UPDATE THIS STATE
                rx_from_link_ready <= '1';
                if(data_from_link (7 downto 0) = REG_DEVICE_TO_HOST) then
                    --rx_from_link_ready <= '0';
                    --check error bit and device fault bit in the  Status field.. if error is asserted can check error field
                    --TODO: create constants for ERROR, DEV_FAULT, etc
                    if(data_from_link(STATUS_ERR) = '1' or data_from_link(STATUS_DF) = '1') then
                        --error occured
                    elsif(data_from_link(STATUS_BSY) = '0') then
                    else
                    end if;
                --elsif(error) then
                end if;
            when pause_data_tx =>
                if(pause = '0')then
                    data_to_link <= paused_data_to_link;
                    tx_read_ptr <= tx_read_ptr + 1;
                else
                    data_to_link <= x"FFFFFFFF"; --value for debugging
                end if;
--========================================================================================
            -- DMA Read EXT SM states
            when dma_read_idle      =>
                rx_write_ptr <= 0;
                --rx_from_link_ready <= '0';
                --build register host to device DMA Read FIS
                rx_fis_array(rx_index).fis_type <= REG_HOST_TO_DEVICE;
                rx_fis_array(rx_index).crrr_pm <= x"80";
                rx_fis_array(rx_index).command <= READ_DMA_EXT;
                rx_fis_array(rx_index).features <= x"00";
                rx_fis_array(rx_index).lba <= lba(23 downto 0);
                rx_fis_array(rx_index).device <= x"E0";
                rx_fis_array(rx_index).features_ext <= x"00";
                rx_fis_array(rx_index).lba_ext <= lba(47 downto 24);
                rx_fis_array(rx_index).count <= WRITE_SECTOR_COUNT; --on most drives 1 logical sector := 512 bytes
                rx_fis_array(rx_index).icc <= x"00";
                rx_fis_array(rx_index).control <= x"00";
                rx_fis_array(rx_index).aux <= x"00000000";

            when dma_read_reg_fis_0 =>
                tx_to_link_request <= '1';
                data_to_link <= rx_fis_array(rx_index).features & rx_fis_array(rx_index).command &
                               rx_fis_array(rx_index).crrr_pm & rx_fis_array(rx_index).fis_type;
            when dma_read_reg_fis_1 =>
                data_to_link <= rx_fis_array(rx_index).device & rx_fis_array(rx_index).lba;
            when dma_read_reg_fis_2 =>
                data_to_link <= rx_fis_array(rx_index).features_ext &
                               rx_fis_array(rx_index).lba_ext;
            when dma_read_reg_fis_3 =>
                data_to_link <= rx_fis_array(rx_index).control & rx_fis_array(rx_index).icc &
                               rx_fis_array(rx_index).count;
            when dma_read_reg_fis_4 =>
                data_to_link <= rx_fis_array(rx_index).aux;
            when dma_read_data_fis  => --pick a buffer, must be completely empty
                tx_to_link_request <= '0';
                rx_from_link_ready <= '1';
                if(rx_buffer_empty(0) = '1') then
                    rx_index <= 0;
                    rx0_locked <= '1';
                    rx_buffer_full(0) <= '0';
                elsif(rx_buffer_empty(1) = '1') then
                    rx_index <= 1;
                    rx1_locked <= '1';
                    rx_buffer_full(1) <= '0';
                end if;
                --add states to read entire fis
                --HENDRICK LOOK HERE NOT SURE IF THIS WAS COMMENTED LAST COMPILE!!!
                --if(data_from_link(7 downto 0)= DATA_FIS) then
                --    rx_buffer(rx_index)(rx_write_ptr) <= data_from_link;
                --    rx_write_ptr <= rx_write_ptr + 1;
                --end if;
            when dma_read_data_frame    => --store data into rx buffer
                if(pause = '0')then
                    rx_buffer(rx_index)(rx_write_ptr) <= data_from_link;
                    if(rx_write_ptr < BUFFER_DEPTH - 1) then --Check data valid flag from link
                        rx_write_ptr <= rx_write_ptr + 1;
                    else
                        rx_buffer_full(rx_index) <= '1';
                        --rx_from_link_ready <= '0'; --not ready to receive more data, should be uncommented but link layer bug breaks stuff if it is
                        if(rx_index = 0) then
                            rx0_locked <= '0';
                        else
                            rx1_locked <= '0';
                        end if;
                    end if;
                --else
                end if;
            when dma_read_chk_status =>
                rx_from_link_ready <= '1';
                if(data_from_link (7 downto 0) = REG_DEVICE_TO_HOST) then
                    --rx_from_link_ready <= '0';
                    --check error bit and device fault bit in the  Status field.. if error is asserted can check error field
                    --TODO: create constants for ERROR, DEV_FAULT, etc
                    if(data_from_link(STATUS_ERR) = '1' or data_from_link(STATUS_DF) = '1') then
                        --error occured
                    elsif(data_from_link(STATUS_BSY) = '0') then
                    else
                    end if;
                --elsif(error) then
                end if;
--========================================================================================
            when others => -- state <= transport_idle;
        end case;
        end if;
    end process;
--=================================================================================================================
--Processes to control the flow of user data to/from the tx/rx buffers
--The dual-buffer system allows user data to be written to a buffer even when the Transort FSM is performing a command
 tx_buffer_control   : process(clk,rst_n)
    variable tx_w_buffer : integer range 0 to 1;
    variable user_write_valid : std_logic;
      begin
        if(rst_n = '0') then
            tx_write_ptr <= 0;
            tx_w_buffer := 0;
            user_write_valid := '0';
            tx_buffer_full(0) <= '0';
            tx_buffer_full(1) <= '0';
        elsif(rising_edge(clk)) then

            if(tx_buffer_full(0) = '0' and tx0_locked = '0')then
                tx_w_buffer := 0;   --write to tx_buffer(0)
                user_write_valid := '1';
            elsif(tx_buffer_full(1) = '0' and tx1_locked = '0')then
                tx_w_buffer := 1;   --write to tx_buffer(1)
                user_write_valid := '1';
            else
                user_write_valid := '0';
            end if;

            if(tx_read_ptr > 0)then
                if(tx0_locked = '1')then
                    tx_buffer_full(0) <= '0';
                elsif(tx1_locked = '1')then
                    tx_buffer_full(1) <= '0';
                end if;
            end if;

            if(user_command(1 downto 0) = "01" and user_write_valid = '1') then --user is sending data
                lba <= x"0000" &  address_from_user; --currently expecting user to keep address on line for entire write command
                tx_buffer(tx_w_buffer)(tx_write_ptr) <= data_from_user; --selected tx_buffer gets next user data word
                if(tx_write_ptr < BUFFER_DEPTH - 1)then
                    tx_write_ptr <= tx_write_ptr + 1;
                else
                    tx_write_ptr <= 0;
                    tx_buffer_full(tx_w_buffer) <= '1';
                end if;
            end if;

        end if;
    end process;


rx_buffer_control_reads : process(clk, rst_n)
    variable rx_buffer_read_select : integer range 0 to 1;
    variable user_rx_read_valid : std_logic;
      begin
        if(rst_n = '0') then
            rx_read_ptr <= 0;
            user_rx_read_valid := '0';
            data_to_user <= x"00000000";
            address_to_user <= x"00000000";
            rx_buffer_empty <= "11";--both buffers start empty after reset
        elsif(rising_edge(clk)) then

            --if we are writing to one of the buffers it is no longer empty
            if(rx_write_ptr > 0)then
                if(rx0_locked = '1')then
                    rx_buffer_empty(0) <= '0';
                elsif(rx1_locked = '1')then
                    rx_buffer_empty(1) <= '0';
                end if;
            end if;

            if(rx0_locked = '0' and rx_buffer_empty(0) = '0')then
                rx_buffer_read_select := 0;
                user_rx_read_valid := '1';
            elsif(rx1_locked = '0' and rx_buffer_empty(1) = '0')then
                rx_buffer_read_select := 1;
                user_rx_read_valid := '1';
            else
                user_rx_read_valid := '0';
            end if;

            if(user_command(2) = '1' and user_rx_read_valid = '1') then
                --give user read address?
                data_to_user <= rx_buffer(rx_buffer_read_select)(rx_read_ptr);

                if(rx_read_ptr < BUFFER_DEPTH - 1)then
                    rx_read_ptr <= rx_read_ptr + 1;
                else
                    rx_read_ptr <= 0;
                    rx_buffer_empty(rx_buffer_read_select) <= '1';
                end if;
            end if;

        end if;
    end process;
--============================================================================
    link_fis_type <= data_from_link(7 downto 0);
--============================================================================
    --update status vectors (In Beta)
    status_to_user(0) <= device_ready;

    update_status : process(current_state, tx_buffer_full, rx_buffer_full, rx_buffer_empty, rx0_locked, rx1_locked,tx0_locked,tx1_locked)
        begin
        if (((tx_buffer_full(0) = '0' and tx0_locked = '0') or (tx_buffer_full(1) = '0' and tx1_locked = '0')) and current_state = transport_idle) then--this needs to be able to work when current_state != trans_idle
            status_to_user(1) <= '1';
        else
                status_to_user(1) <= '0';
        end if;
        --if ((rx_buffer_full(0) = '0' and rx0_locked = '0') or (rx_buffer_full(1) = '0' and rx1_locked = '0')) then--add transmit read count flag??
        if (((rx_buffer_empty(0) = '1' and rx0_locked = '0') or (rx_buffer_empty(1) = '1' and rx1_locked = '0')) and current_state = transport_idle) then
            status_to_user(2) <= '1';
        else
                status_to_user(2) <= '0';
        end if;
        if ((rx_buffer_empty(0) = '0' and rx0_locked = '0') or (rx_buffer_empty(1) = '0' and rx1_locked = '0')) then
            status_to_user(3) <= '1';
        else
                status_to_user(3) <= '0';
        end if;
    end process;

    --status assignments
    link_rdy <= status_from_link (5);
    pause <= status_from_link(6);
    data_from_link_valid <= status_from_link(7);
    status_to_link <= "0" & rx_from_link_ready & tx_to_link_request & "00001";
end architecture;