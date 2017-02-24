

-- ########################################################################
-- CRC Engine RTL Design 
-- Copyright (C) www.ElectronicDesignworks.com 
-- Source code generated by ElectronicDesignworks IP Generator (CRC).
-- Documentation can be downloaded from www.ElectronicDesignworks.com 
-- ******************************** 
--            License     
-- ******************************** 
-- This source file may be used and distributed freely provided that this
-- copyright notice, list of conditions and the following disclaimer is
-- not removed from the file.                    
-- Any derivative work should contain this copyright notice and associated disclaimer.                    
-- This source code file is provided "AS IS" AND WITHOUT ANY WARRANTY, 
-- without even the implied warranty of MERCHANTABILITY or FITNESS FOR A 
-- PARTICULAR PURPOSE.
-- ********************************
--           Specification 
-- ********************************
-- File Name       : CRC32_DATA32.vhd    
-- Description     : CRC Engine ENTITY 
-- Clock           : Positive Edge 
-- Reset           : Active Low
-- First Serial    : MSB 
-- Data Bus Width  : 32 bits 
-- Polynomial      : (0 1 2 4 5 7 8 10 11 12 16 22 23 26 32)                   
-- Date            : 18-Jan-2017  
-- Version         : 1.0        
-- ########################################################################
                    
LIBRARY IEEE ;
USE ieee.std_logic_1164.all ;
USE ieee.std_logic_arith.all ;
USE ieee.std_logic_unsigned.all ;

entity crc_gen_32 is
   port(clk        : in  std_logic; 
        rst_n      : in  std_logic; 
        soc        : in  std_logic; 
        data       : in  std_logic_vector(31 downto 0); 
        data_valid : in  std_logic; 
        eoc        : in  std_logic; 
        crc        : out std_logic_vector(31 downto 0));
end entity;

ARCHITECTURE behave OF crc_gen_32 IS 

 SIGNAL crc_r           : STD_LOGIC_VECTOR(31 DOWNTO 0);
 SIGNAL crc_c           : STD_LOGIC_VECTOR(31 DOWNTO 0);
 SIGNAL crc_i           : STD_LOGIC_VECTOR(31 DOWNTO 0);
 constant crc_const     : STD_LOGIC_VECTOR(31 DOWNTO 0) := x"52325032";
 signal s_soc     : std_logic;

BEGIN 
  
--s_soc_process : PROCESS(clk, rst_n) 
--BEGIN                                    
 --IF(rst_n = '0') THEN  
 --   s_soc <= '0';
 --elsif(rising_edge(clk)) then
 --   IF(data_valid = '0') THEN 
         s_soc <= soc;
  --else
  --  s_soc <= '0';
  --  END IF; 
-- END IF;    
--END PROCESS s_soc_process;      

        
crc_i    <= crc_const when s_soc = '1' else
            crc_r;

crc_c(0) <= data(0) XOR data(6) XOR data(9) XOR data(10) XOR data(24) XOR crc_i(0) XOR crc_i(24) XOR data(29) XOR crc_i(29) XOR data(28) XOR crc_i(28) XOR crc_i(10) XOR data(26) XOR crc_i(26) XOR crc_i(9) XOR data(25) XOR crc_i(25) XOR data(12) XOR data(16) XOR data(30) XOR crc_i(6) XOR crc_i(30) XOR crc_i(16) XOR data(31) XOR crc_i(31) XOR crc_i(12); 
crc_c(1) <= data(0) XOR data(1) XOR data(7) XOR data(11) XOR crc_i(1) XOR crc_i(11) XOR data(27) XOR crc_i(27) XOR data(13) XOR data(17) XOR crc_i(7) XOR crc_i(17) XOR crc_i(13) XOR data(6) XOR data(9) XOR data(24) XOR crc_i(0) XOR crc_i(24) XOR data(28) XOR crc_i(28) XOR crc_i(9) XOR data(12) XOR data(16) XOR crc_i(6) XOR crc_i(16) XOR crc_i(12); 
crc_c(2) <= data(0) XOR data(1) XOR data(2) XOR data(8) XOR crc_i(2) XOR data(14) XOR data(18) XOR crc_i(8) XOR crc_i(18) XOR crc_i(14) XOR data(7) XOR crc_i(1) XOR data(13) XOR data(17) XOR crc_i(7) XOR crc_i(17) XOR crc_i(13) XOR data(6) XOR data(9) XOR data(24) XOR crc_i(0) XOR crc_i(24) XOR data(26) XOR crc_i(26) XOR crc_i(9) XOR data(16) XOR data(30) XOR crc_i(6) XOR crc_i(30) XOR crc_i(16) XOR data(31) XOR crc_i(31); 
crc_c(3) <= data(1) XOR data(2) XOR data(3) XOR data(9) XOR crc_i(3) XOR data(15) XOR data(19) XOR crc_i(9) XOR crc_i(19) XOR crc_i(15) XOR data(8) XOR crc_i(2) XOR data(14) XOR data(18) XOR crc_i(8) XOR crc_i(18) XOR crc_i(14) XOR data(7) XOR data(10) XOR data(25) XOR crc_i(1) XOR crc_i(25) XOR data(27) XOR crc_i(27) XOR crc_i(10) XOR data(17) XOR data(31) XOR crc_i(7) XOR crc_i(31) XOR crc_i(17); 
crc_c(4) <= data(0) XOR data(2) XOR data(3) XOR data(4) XOR crc_i(4) XOR data(20) XOR crc_i(20) XOR crc_i(3) XOR data(15) XOR data(19) XOR crc_i(19) XOR crc_i(15) XOR data(8) XOR data(11) XOR crc_i(2) XOR crc_i(11) XOR data(18) XOR crc_i(8) XOR crc_i(18) XOR data(6) XOR data(24) XOR crc_i(0) XOR crc_i(24) XOR data(29) XOR crc_i(29) XOR data(25) XOR crc_i(25) XOR data(12) XOR data(30) XOR crc_i(6) XOR crc_i(30) XOR data(31) XOR crc_i(31) XOR crc_i(12); 
crc_c(5) <= data(0) XOR data(1) XOR data(3) XOR data(4) XOR data(5) XOR crc_i(5) XOR data(21) XOR crc_i(21) XOR crc_i(4) XOR data(20) XOR crc_i(20) XOR crc_i(3) XOR data(19) XOR crc_i(19) XOR data(7) XOR crc_i(1) XOR data(13) XOR crc_i(7) XOR crc_i(13) XOR data(6) XOR data(10) XOR data(24) XOR crc_i(0) XOR crc_i(24) XOR data(29) XOR crc_i(29) XOR data(28) XOR crc_i(28) XOR crc_i(10) XOR crc_i(6); 
crc_c(6) <= data(1) XOR data(2) XOR data(4) XOR data(5) XOR data(6) XOR crc_i(6) XOR data(22) XOR crc_i(22) XOR crc_i(5) XOR data(21) XOR crc_i(21) XOR crc_i(4) XOR data(20) XOR crc_i(20) XOR data(8) XOR crc_i(2) XOR data(14) XOR crc_i(8) XOR crc_i(14) XOR data(7) XOR data(11) XOR data(25) XOR crc_i(1) XOR crc_i(25) XOR data(30) XOR crc_i(30) XOR data(29) XOR crc_i(29) XOR crc_i(11) XOR crc_i(7); 
crc_c(7) <= data(0) XOR data(2) XOR data(3) XOR data(5) XOR data(7) XOR crc_i(7) XOR data(23) XOR crc_i(23) XOR data(22) XOR crc_i(22) XOR crc_i(5) XOR data(21) XOR crc_i(21) XOR crc_i(3) XOR data(15) XOR crc_i(15) XOR data(8) XOR crc_i(2) XOR crc_i(8) XOR data(10) XOR data(24) XOR crc_i(0) XOR crc_i(24) XOR data(29) XOR crc_i(29) XOR data(28) XOR crc_i(28) XOR crc_i(10) XOR data(25) XOR crc_i(25) XOR data(16) XOR crc_i(16); 
crc_c(8) <= data(0) XOR data(1) XOR data(3) XOR data(4) XOR data(8) XOR crc_i(8) XOR data(23) XOR crc_i(23) XOR data(22) XOR crc_i(22) XOR crc_i(4) XOR crc_i(3) XOR data(11) XOR crc_i(1) XOR crc_i(11) XOR data(17) XOR crc_i(17) XOR data(10) XOR crc_i(0) XOR data(28) XOR crc_i(28) XOR crc_i(10) XOR data(12) XOR data(31) XOR crc_i(31) XOR crc_i(12); 
crc_c(9) <= data(1) XOR data(2) XOR data(4) XOR data(5) XOR data(9) XOR crc_i(9) XOR data(24) XOR crc_i(24) XOR data(23) XOR crc_i(23) XOR crc_i(5) XOR crc_i(4) XOR data(12) XOR crc_i(2) XOR crc_i(12) XOR data(18) XOR crc_i(18) XOR data(11) XOR crc_i(1) XOR data(29) XOR crc_i(29) XOR crc_i(11) XOR data(13) XOR crc_i(13); 
crc_c(10) <= data(0) XOR data(2) XOR data(3) XOR data(5) XOR crc_i(5) XOR data(13) XOR crc_i(3) XOR crc_i(13) XOR data(19) XOR crc_i(19) XOR crc_i(2) XOR data(14) XOR crc_i(14) XOR data(9) XOR crc_i(0) XOR data(29) XOR crc_i(29) XOR data(28) XOR crc_i(28) XOR data(26) XOR crc_i(26) XOR crc_i(9) XOR data(16) XOR crc_i(16) XOR data(31) XOR crc_i(31); 
crc_c(11) <= data(0) XOR data(1) XOR data(3) XOR data(4) XOR data(14) XOR crc_i(4) XOR crc_i(14) XOR data(20) XOR crc_i(20) XOR crc_i(3) XOR data(15) XOR crc_i(15) XOR crc_i(1) XOR data(27) XOR crc_i(27) XOR data(17) XOR crc_i(17) XOR data(9) XOR data(24) XOR crc_i(0) XOR crc_i(24) XOR data(28) XOR crc_i(28) XOR data(26) XOR crc_i(26) XOR crc_i(9) XOR data(25) XOR crc_i(25) XOR data(12) XOR data(16) XOR crc_i(16) XOR data(31) XOR crc_i(31) XOR crc_i(12); 
crc_c(12) <= data(0) XOR data(1) XOR data(2) XOR data(4) XOR data(5) XOR data(15) XOR crc_i(5) XOR crc_i(15) XOR data(21) XOR crc_i(21) XOR crc_i(4) XOR crc_i(2) XOR data(18) XOR crc_i(18) XOR crc_i(1) XOR data(27) XOR crc_i(27) XOR data(13) XOR data(17) XOR crc_i(17) XOR crc_i(13) XOR data(6) XOR data(9) XOR data(24) XOR crc_i(0) XOR crc_i(24) XOR crc_i(9) XOR data(12) XOR data(30) XOR crc_i(6) XOR crc_i(30) XOR data(31) XOR crc_i(31) XOR crc_i(12); 
crc_c(13) <= data(1) XOR data(2) XOR data(3) XOR data(5) XOR data(6) XOR data(16) XOR crc_i(6) XOR crc_i(16) XOR data(22) XOR crc_i(22) XOR crc_i(5) XOR crc_i(3) XOR data(19) XOR crc_i(19) XOR crc_i(2) XOR data(28) XOR crc_i(28) XOR data(14) XOR data(18) XOR crc_i(18) XOR crc_i(14) XOR data(7) XOR data(10) XOR data(25) XOR crc_i(1) XOR crc_i(25) XOR crc_i(10) XOR data(13) XOR data(31) XOR crc_i(7) XOR crc_i(31) XOR crc_i(13); 
crc_c(14) <= data(2) XOR data(3) XOR data(4) XOR data(6) XOR data(7) XOR data(17) XOR crc_i(7) XOR crc_i(17) XOR data(23) XOR crc_i(23) XOR crc_i(6) XOR crc_i(4) XOR data(20) XOR crc_i(20) XOR crc_i(3) XOR data(29) XOR crc_i(29) XOR data(15) XOR data(19) XOR crc_i(19) XOR crc_i(15) XOR data(8) XOR data(11) XOR data(26) XOR crc_i(2) XOR crc_i(26) XOR crc_i(11) XOR data(14) XOR crc_i(8) XOR crc_i(14); 
crc_c(15) <= data(3) XOR data(4) XOR data(5) XOR data(7) XOR data(8) XOR data(18) XOR crc_i(8) XOR crc_i(18) XOR data(24) XOR crc_i(24) XOR crc_i(7) XOR crc_i(5) XOR data(21) XOR crc_i(21) XOR crc_i(4) XOR data(30) XOR crc_i(30) XOR data(16) XOR data(20) XOR crc_i(20) XOR crc_i(16) XOR data(9) XOR data(12) XOR data(27) XOR crc_i(3) XOR crc_i(27) XOR crc_i(12) XOR data(15) XOR crc_i(9) XOR crc_i(15); 
crc_c(16) <= data(0) XOR data(4) XOR data(5) XOR data(8) XOR data(19) XOR crc_i(19) XOR crc_i(8) XOR data(22) XOR crc_i(22) XOR crc_i(5) XOR data(17) XOR data(21) XOR crc_i(21) XOR crc_i(17) XOR data(13) XOR crc_i(4) XOR crc_i(13) XOR data(24) XOR crc_i(0) XOR crc_i(24) XOR data(29) XOR crc_i(29) XOR data(26) XOR crc_i(26) XOR data(12) XOR data(30) XOR crc_i(30) XOR crc_i(12); 
crc_c(17) <= data(1) XOR data(5) XOR data(6) XOR data(9) XOR data(20) XOR crc_i(20) XOR crc_i(9) XOR data(23) XOR crc_i(23) XOR crc_i(6) XOR data(18) XOR data(22) XOR crc_i(22) XOR crc_i(18) XOR data(14) XOR crc_i(5) XOR crc_i(14) XOR data(25) XOR crc_i(1) XOR crc_i(25) XOR data(30) XOR crc_i(30) XOR data(27) XOR crc_i(27) XOR data(13) XOR data(31) XOR crc_i(31) XOR crc_i(13); 
crc_c(18) <= data(2) XOR data(6) XOR data(7) XOR data(10) XOR data(21) XOR crc_i(21) XOR crc_i(10) XOR data(24) XOR crc_i(24) XOR crc_i(7) XOR data(19) XOR data(23) XOR crc_i(23) XOR crc_i(19) XOR data(15) XOR crc_i(6) XOR crc_i(15) XOR data(26) XOR crc_i(2) XOR crc_i(26) XOR data(31) XOR crc_i(31) XOR data(28) XOR crc_i(28) XOR data(14) XOR crc_i(14); 
crc_c(19) <= data(3) XOR data(7) XOR data(8) XOR data(11) XOR data(22) XOR crc_i(22) XOR crc_i(11) XOR data(25) XOR crc_i(25) XOR crc_i(8) XOR data(20) XOR data(24) XOR crc_i(24) XOR crc_i(20) XOR data(16) XOR crc_i(7) XOR crc_i(16) XOR data(27) XOR crc_i(3) XOR crc_i(27) XOR data(29) XOR crc_i(29) XOR data(15) XOR crc_i(15); 
crc_c(20) <= data(4) XOR data(8) XOR data(9) XOR data(12) XOR data(23) XOR crc_i(23) XOR crc_i(12) XOR data(26) XOR crc_i(26) XOR crc_i(9) XOR data(21) XOR data(25) XOR crc_i(25) XOR crc_i(21) XOR data(17) XOR crc_i(8) XOR crc_i(17) XOR data(28) XOR crc_i(4) XOR crc_i(28) XOR data(30) XOR crc_i(30) XOR data(16) XOR crc_i(16); 
crc_c(21) <= data(5) XOR data(9) XOR data(10) XOR data(13) XOR data(24) XOR crc_i(24) XOR crc_i(13) XOR data(27) XOR crc_i(27) XOR crc_i(10) XOR data(22) XOR data(26) XOR crc_i(26) XOR crc_i(22) XOR data(18) XOR crc_i(9) XOR crc_i(18) XOR data(29) XOR crc_i(5) XOR crc_i(29) XOR data(31) XOR crc_i(31) XOR data(17) XOR crc_i(17); 
crc_c(22) <= data(0) XOR data(11) XOR data(14) XOR crc_i(14) XOR crc_i(11) XOR data(23) XOR data(27) XOR crc_i(27) XOR crc_i(23) XOR data(19) XOR crc_i(19) XOR data(18) XOR crc_i(18) XOR data(9) XOR data(24) XOR crc_i(0) XOR crc_i(24) XOR data(29) XOR crc_i(29) XOR data(26) XOR crc_i(26) XOR crc_i(9) XOR data(12) XOR data(16) XOR crc_i(16) XOR data(31) XOR crc_i(31) XOR crc_i(12); 
crc_c(23) <= data(0) XOR data(1) XOR data(15) XOR crc_i(15) XOR data(20) XOR crc_i(20) XOR data(19) XOR crc_i(19) XOR crc_i(1) XOR data(27) XOR crc_i(27) XOR data(13) XOR data(17) XOR crc_i(17) XOR crc_i(13) XOR data(6) XOR data(9) XOR crc_i(0) XOR data(29) XOR crc_i(29) XOR data(26) XOR crc_i(26) XOR crc_i(9) XOR data(16) XOR crc_i(6) XOR crc_i(16) XOR data(31) XOR crc_i(31); 
crc_c(24) <= data(1) XOR data(2) XOR data(16) XOR crc_i(16) XOR data(21) XOR crc_i(21) XOR data(20) XOR crc_i(20) XOR crc_i(2) XOR data(28) XOR crc_i(28) XOR data(14) XOR data(18) XOR crc_i(18) XOR crc_i(14) XOR data(7) XOR data(10) XOR crc_i(1) XOR data(30) XOR crc_i(30) XOR data(27) XOR crc_i(27) XOR crc_i(10) XOR data(17) XOR crc_i(7) XOR crc_i(17); 
crc_c(25) <= data(2) XOR data(3) XOR data(17) XOR crc_i(17) XOR data(22) XOR crc_i(22) XOR data(21) XOR crc_i(21) XOR crc_i(3) XOR data(29) XOR crc_i(29) XOR data(15) XOR data(19) XOR crc_i(19) XOR crc_i(15) XOR data(8) XOR data(11) XOR crc_i(2) XOR data(31) XOR crc_i(31) XOR data(28) XOR crc_i(28) XOR crc_i(11) XOR data(18) XOR crc_i(8) XOR crc_i(18); 
crc_c(26) <= data(0) XOR data(3) XOR data(4) XOR data(18) XOR crc_i(18) XOR data(23) XOR crc_i(23) XOR data(22) XOR crc_i(22) XOR crc_i(4) XOR data(20) XOR crc_i(20) XOR crc_i(3) XOR data(19) XOR crc_i(19) XOR data(6) XOR data(10) XOR data(24) XOR crc_i(0) XOR crc_i(24) XOR data(28) XOR crc_i(28) XOR crc_i(10) XOR data(26) XOR crc_i(26) XOR data(25) XOR crc_i(25) XOR crc_i(6) XOR data(31) XOR crc_i(31); 
crc_c(27) <= data(1) XOR data(4) XOR data(5) XOR data(19) XOR crc_i(19) XOR data(24) XOR crc_i(24) XOR data(23) XOR crc_i(23) XOR crc_i(5) XOR data(21) XOR crc_i(21) XOR crc_i(4) XOR data(20) XOR crc_i(20) XOR data(7) XOR data(11) XOR data(25) XOR crc_i(1) XOR crc_i(25) XOR data(29) XOR crc_i(29) XOR crc_i(11) XOR data(27) XOR crc_i(27) XOR data(26) XOR crc_i(26) XOR crc_i(7); 
crc_c(28) <= data(2) XOR data(5) XOR data(6) XOR data(20) XOR crc_i(20) XOR data(25) XOR crc_i(25) XOR data(24) XOR crc_i(24) XOR crc_i(6) XOR data(22) XOR crc_i(22) XOR crc_i(5) XOR data(21) XOR crc_i(21) XOR data(8) XOR data(12) XOR data(26) XOR crc_i(2) XOR crc_i(26) XOR data(30) XOR crc_i(30) XOR crc_i(12) XOR data(28) XOR crc_i(28) XOR data(27) XOR crc_i(27) XOR crc_i(8); 
crc_c(29) <= data(3) XOR data(6) XOR data(7) XOR data(21) XOR crc_i(21) XOR data(26) XOR crc_i(26) XOR data(25) XOR crc_i(25) XOR crc_i(7) XOR data(23) XOR crc_i(23) XOR crc_i(6) XOR data(22) XOR crc_i(22) XOR data(9) XOR data(13) XOR data(27) XOR crc_i(3) XOR crc_i(27) XOR data(31) XOR crc_i(31) XOR crc_i(13) XOR data(29) XOR crc_i(29) XOR data(28) XOR crc_i(28) XOR crc_i(9); 
crc_c(30) <= data(4) XOR data(7) XOR data(8) XOR data(22) XOR crc_i(22) XOR data(27) XOR crc_i(27) XOR data(26) XOR crc_i(26) XOR crc_i(8) XOR data(24) XOR crc_i(24) XOR crc_i(7) XOR data(23) XOR crc_i(23) XOR data(10) XOR data(14) XOR data(28) XOR crc_i(4) XOR crc_i(28) XOR crc_i(14) XOR data(30) XOR crc_i(30) XOR data(29) XOR crc_i(29) XOR crc_i(10); 
crc_c(31) <= data(5) XOR data(8) XOR data(9) XOR data(23) XOR crc_i(23) XOR data(28) XOR crc_i(28) XOR data(27) XOR crc_i(27) XOR crc_i(9) XOR data(25) XOR crc_i(25) XOR crc_i(8) XOR data(24) XOR crc_i(24) XOR data(11) XOR data(15) XOR data(29) XOR crc_i(5) XOR crc_i(29) XOR crc_i(15) XOR data(31) XOR crc_i(31) XOR data(30) XOR crc_i(30) XOR crc_i(11); 


crc_gen_process : PROCESS(clk, rst_n, data_valid) 
BEGIN                                    
 IF(rst_n = '0') THEN  
    crc_r <= crc_const;
 ELSIF(rising_edge(clk)) THEN 
    IF(data_valid = '1') THEN 
         crc_r <= crc_c; 
    END IF; 
 END IF;    
END PROCESS crc_gen_process;      

crc <= crc_r;

END behave;