library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity lab05 is
  Port (
    clk: in std_logic;
    hsync, vsync: out std_logic;
    red, green, blue : out std_logic_vector(3 downto 0);
    BTNU, BTND, BTNL, BTNR, BTNC: in std_logic
  );
end lab05;

architecture rtl of lab05 is
begin
  top_i : entity work.proj
    port map (
      clk => clk,
      hsync => hsync,
      vsync => vsync,
      red => red,
      green => green,
      blue => blue,
      BTNU => BTNU,
      BTND => BTND,
      BTNL => BTNL,
      BTNR => BTNR,
      BTNC => BTNC
    );
end architecture;
