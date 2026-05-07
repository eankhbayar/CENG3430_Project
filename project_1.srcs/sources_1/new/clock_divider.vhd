library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity clock_divider is
  generic (N : integer := 2);
  port (
    clk : in std_logic;
    clk_out : out std_logic
  );
end entity;

architecture rtl of clock_divider is
  signal pulse : std_logic := '0';
  signal count : integer range 0 to N - 1 := 0;
begin
  process(clk)
  begin
    if rising_edge(clk) then
      if count = N - 1 then
        pulse <= not pulse;
        count <= 0;
      else
        count <= count + 1;
      end if;
    end if;
  end process;

  clk_out <= pulse;
end architecture;
