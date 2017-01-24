library ieee;
use ieee.std_logic_1164.ALL;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity Debounce is
  port(
    clk50        : in  std_logic;
    button     : in  std_logic;
    debounced  : out std_logic);
end Debounce;

architecture Debounce_arch of Debounce is
  signal prevVal    : std_logic;
  signal currVal     : std_logic;
  signal stableInput : std_logic;
  signal counter : std_logic_vector(20 downto 0) := (others => '0'); --counter output
begin

  stableInput <= not prevVal xor currVal;

  process(clk50)
  begin
    if(rising_edge(clk50)) then
      currVal <= button;
      prevVal <= currVal;
      if(stableInput = '0') then
        counter <= (others => '0');
      elsif(counter(counter'left) = '0') then
        counter <= counter + 1;
      else
        debounced <= currVal;
      end if;
    end if;
  end process;
end architecture Debounce_arch;