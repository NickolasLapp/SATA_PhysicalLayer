library ieee;                   --! Use standard library.
use ieee.std_logic_1164.all;    --! Use standard logic elements
use ieee.numeric_std.all;       --! Use numeric standard

package transport_layer_pkg is

	constant DATA_WIDTH : integer := 32;
	constant BUFFER_DEPTH : integer := 128; --Using 16 dword buffers for simulation, 128 for hardware test, final will be 2048
	constant WRITE_SECTOR_COUNT : std_logic_vector(15 downto 0) := x"0001";

	--States for Transport FSM
	  type State_Type is (

	                    transport_reset, transport_idle,
						--================================================
	                    --Init States
	                    transport_init_start, transport_init_end, identify_device_0,
	                    identify_device_1, identify_device_2, identify_device_3,
	                    identify_device_4, rx_pio_setup, rx_identify_packet,
	                    wait_for_fis_end,
	                    --================================================
	                    --DMA Write States  --PRELIMINARY
	                     dma_write_idle, dma_write_reg_fis_0,
	                     dma_write_reg_fis_1, dma_write_reg_fis_2,
	                     dma_write_reg_fis_3,dma_write_reg_fis_4,
	                     dma_write_chk_activate, dma_write_data_idle,
	                     dma_write_data_fis, dma_write_data_frame,
	                     dma_write_chk_status, pause_data_tx,
	                    --================================================

	                    --================================================
	                    --DMA Read States --PRELIMINARY
	                     dma_read_idle, dma_read_reg_fis_0,
	                     dma_read_reg_fis_1, dma_read_reg_fis_2,
	                     dma_read_reg_fis_3, dma_read_reg_fis_4,
	                     dma_read_data_fis, dma_read_data_frame,
	                     dma_read_chk_status
	                    --================================================
	                    );
	--======================================================================================
	-- Type Field Values of supported SATA Frame Information Structures (FIS)
	-- Supported Register FIS Type Field Value
	constant REG_HOST_TO_DEVICE   : std_logic_vector(7 downto 0) := x"27";
	constant REG_DEVICE_TO_HOST   : std_logic_vector(7 downto 0) := x"34";
	constant PIO_SETUP_FIS		: std_logic_vector(7 downto 0) := x"5F";

	constant DMA_ACTIVATE_FIS     : std_logic_vector(7 downto 0) := x"39"; --Device to Host -- 1 dword
	  --constant DMA_SETUP_FIS      : std_logic_vector(7 downto 0) := x"41"; --Bidirectional  -- 7 dwords --not using
	constant DATA_FIS             : std_logic_vector(7 downto 0) := x"46"; --Bidirectional
	--======================================================================================


	--======================================================================================
	--Supported ATA Commands
	--need EXT commands to support 48 bit address
	constant READ_DMA_EXT   : std_logic_vector(7 downto 0) := x"25";
	constant WRITE_DMA_EXT  : std_logic_vector(7 downto 0) := x"35";
	constant IDENTIFY_DEVICE : std_logic_vector(7 downto 0) := x"EC";
	--======================================================================================

	--Record type for Host to Device register FIS
	type register_fis_type  is
	  record
	    fis_type :  std_logic_vector(7 downto 0);       --set to 27h
	    crrr_pm  :  std_logic_vector(7 downto 0);       --set to 80h
	    command : std_logic_vector(7 downto 0);         --see command support constants
	    features : std_logic_vector(7 downto 0);        --set to 00h
	    lba : std_logic_vector(23 downto 0);            --lower half of address
	    device: std_logic_vector(7 downto 0);           --set to 40h?
	    lba_ext : std_logic_vector(23 downto 0);        --upper half of address
	    features_ext : std_logic_vector(7 downto 0);    --set to 00h
	    count : std_logic_vector(15 downto 0);          --Will be size of tx buffer
	    icc   : std_logic_vector(7 downto 0);           --set to 00h
	    control : std_logic_vector(7 downto 0);         --set to 00h
	    aux     : std_logic_vector(31 downto 0);        --set to all zeros
	end record;

	type register_fis_array_type is array (1 downto 0) of register_fis_type;

	--array type: holds two std_logic_vectors of sys data width
	type data_width_array_type is array (1 downto 0) of std_logic_vector(DATA_WIDTH - 1 downto 0);

	type single_buffer is array(BUFFER_DEPTH - 1 downto 0) of std_logic_vector(DATA_WIDTH - 1 downto 0);
    type double_buffer is array (1 downto 0) of single_buffer;
end transport_layer_pkg;