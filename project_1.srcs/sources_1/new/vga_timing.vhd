library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity vga_timing is
  port (
    clk_pix     : in  std_logic;
    rst         : in  std_logic;
    hsync       : out std_logic;
    vsync       : out std_logic;
    active      : out std_logic;
    x           : out integer range 0 to 639;
    y           : out integer range 0 to 479;
    frame_start : out std_logic;
    line_start  : out std_logic
  );
end entity;

architecture rtl of vga_timing is
  constant H_ACTIVE : integer := 640;
  constant H_FRONT  : integer := 16;
  constant H_SYNC   : integer := 96;
  constant H_BACK   : integer := 48;
  constant H_TOTAL  : integer := H_ACTIVE + H_FRONT + H_SYNC + H_BACK;

  constant V_ACTIVE : integer := 480;
  constant V_FRONT  : integer := 10;
  constant V_SYNC   : integer := 2;
  constant V_BACK   : integer := 33;
  constant V_TOTAL  : integer := V_ACTIVE + V_FRONT + V_SYNC + V_BACK;

  signal h_count : integer range 0 to H_TOTAL - 1 := 0;
  signal v_count : integer range 0 to V_TOTAL - 1 := 0;
begin
  process(clk_pix)
  begin
    if rising_edge(clk_pix) then
      if rst = '1' then
        h_count <= 0;
        v_count <= 0;
      else
        if h_count = H_TOTAL - 1 then
          h_count <= 0;
          if v_count = V_TOTAL - 1 then
            v_count <= 0;
          else
            v_count <= v_count + 1;
          end if;
        else
          h_count <= h_count + 1;
        end if;
      end if;
    end if;
  end process;

  hsync <= '0' when (h_count >= H_ACTIVE + H_FRONT) and (h_count < H_ACTIVE + H_FRONT + H_SYNC) else '1';
  vsync <= '0' when (v_count >= V_ACTIVE + V_FRONT) and (v_count < V_ACTIVE + V_FRONT + V_SYNC) else '1';

  active <= '1' when (h_count < H_ACTIVE) and (v_count < V_ACTIVE) else '0';

  x <= h_count when h_count < H_ACTIVE else 0;
  y <= v_count when v_count < V_ACTIVE else 0;

  line_start <= '1' when h_count = 0 else '0';
  frame_start <= '1' when (h_count = 0 and v_count = 0) else '0';
end architecture;
