library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.raycast_pkg.ALL;

entity raycaster_core is
  generic (
    SCREEN_W : integer := 640;
    SCREEN_H : integer := 480
  );
  port (
    clk : in std_logic;
    rst : in std_logic;
    calc_en : in std_logic;
    column_idx : in integer range 0 to SCREEN_W - 1;
    player_x_fp : in integer;
    player_y_fp : in integer;
    heading_idx : in integer range 0 to 15;
    wall_top : out integer range 0 to SCREEN_H - 1;
    wall_bottom : out integer range 0 to SCREEN_H - 1;
    wall_color : out std_logic_vector(11 downto 0);
    valid : out std_logic
  );
end entity;

architecture rtl of raycaster_core is
begin
  process(clk)
    variable dist_fp : integer;
    variable slice_h : integer;
    variable top_v : integer;
    variable bot_v : integer;
    variable color_v : std_logic_vector(11 downto 0);
    variable hidx : heading_t;
    variable ray_axis : integer;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        wall_top <= 0;
        wall_bottom <= SCREEN_H - 1;
        wall_color <= x"444";
        valid <= '0';
      elsif calc_en = '1' then
        hidx := wrap_heading(heading_idx);
        dist_fp := cast_ray_distance_fp(player_x_fp, player_y_fp, hidx, column_idx, SCREEN_W);

        if dist_fp < 100 then
          dist_fp := 100;
        end if;

        slice_h := (SCREEN_H * 160) / dist_fp;
        if slice_h > SCREEN_H then
          slice_h := SCREEN_H;
        end if;
        if slice_h < 6 then
          slice_h := 6;
        end if;

        top_v := (SCREEN_H / 2) - (slice_h / 2);
        bot_v := top_v + slice_h;

        if top_v < 0 then
          top_v := 0;
        end if;
        if bot_v > SCREEN_H - 1 then
          bot_v := SCREEN_H - 1;
        end if;

        ray_axis := abs(dir_x(hidx)) - abs(dir_y(hidx));

        if dist_fp < 260 then
          color_v := x"FD4";
        elsif dist_fp < 480 then
          color_v := x"DA3";
        elsif dist_fp < 760 then
          color_v := x"A72";
        else
          color_v := x"753";
        end if;

        if ray_axis < 0 then
          color_v(11 downto 8) := std_logic_vector(unsigned(color_v(11 downto 8)) - 1);
        end if;

        wall_top <= top_v;
        wall_bottom <= bot_v;
        wall_color <= color_v;
        valid <= '1';
      else
        valid <= '0';
      end if;
    end if;
  end process;
end architecture;
