library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.raycast_pkg.ALL;

entity raycaster_core is
  generic (
    SCREEN_W : integer := 640;
    SCREEN_H : integer := 480;
    COLUMN_SCALE : integer := 8
  );
  port (
    clk : in std_logic;
    rst : in std_logic;
    start : in std_logic;
    player_x_fp : in integer;
    player_y_fp : in integer;
    heading_idx : in integer range 0 to 15;
    write_en : out std_logic;
    write_column : out integer range 0 to (SCREEN_W / COLUMN_SCALE) - 1;
    wall_top : out integer range 0 to SCREEN_H - 1;
    wall_bottom : out integer range 0 to SCREEN_H - 1;
    wall_color : out std_logic_vector(11 downto 0);
    busy : out std_logic;
    frame_done : out std_logic
  );
end entity;

architecture rtl of raycaster_core is
  constant SAMPLE_W : integer := SCREEN_W / COLUMN_SCALE;
  constant MAX_STEPS : integer := 28;
  constant DIST_SCALE : integer := 1024;

  type state_t is (S_IDLE, S_INIT_COL, S_STEP, S_WRITE);
  signal state : state_t := S_IDLE;

  signal head_reg : heading_t := 0;
  signal col_reg : integer range 0 to SAMPLE_W - 1 := 0;

  signal map_x_reg : integer := 0;
  signal map_y_reg : integer := 0;
  signal step_x_reg : integer range -1 to 1 := 0;
  signal step_y_reg : integer range -1 to 1 := 0;
  signal delta_x_reg : integer := DIST_SCALE;
  signal delta_y_reg : integer := DIST_SCALE;
  signal side_x_reg : integer := 0;
  signal side_y_reg : integer := 0;
  signal ray_dx_reg : integer := 0;
  signal ray_dy_reg : integer := 0;
  signal step_count_reg : integer range 0 to MAX_STEPS := 0;
  signal hit_side_reg : integer range 0 to 1 := 0;
  signal hit_reg : std_logic := '0';
  signal perp_dist_reg : integer := DIST_SCALE;
begin
  process(clk)
    variable heading_ofs : integer;
    variable ray_heading : heading_t;
    variable player_tile_x : integer;
    variable player_tile_y : integer;
    variable frac_x : integer;
    variable frac_y : integer;
    variable inv_dx : integer;
    variable inv_dy : integer;
    variable nx : integer;
    variable ny : integer;
    variable dist_v : integer;
    variable slice_h : integer;
    variable top_v : integer;
    variable bot_v : integer;
    variable color_v : std_logic_vector(11 downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        state <= S_IDLE;
        head_reg <= 0;
        col_reg <= 0;
        map_x_reg <= 0;
        map_y_reg <= 0;
        step_x_reg <= 0;
        step_y_reg <= 0;
        delta_x_reg <= DIST_SCALE;
        delta_y_reg <= DIST_SCALE;
        side_x_reg <= 0;
        side_y_reg <= 0;
        ray_dx_reg <= 0;
        ray_dy_reg <= 0;
        step_count_reg <= 0;
        hit_side_reg <= 0;
        hit_reg <= '0';
        perp_dist_reg <= DIST_SCALE;
        write_en <= '0';
        write_column <= 0;
        wall_top <= 0;
        wall_bottom <= SCREEN_H - 1;
        wall_color <= x"444";
        busy <= '0';
        frame_done <= '0';
      else
        write_en <= '0';
        frame_done <= '0';

        case state is
          when S_IDLE =>
            busy <= '0';
            if start = '1' then
              head_reg <= wrap_heading(heading_idx);
              col_reg <= 0;
              busy <= '1';
              state <= S_INIT_COL;
            end if;

          when S_INIT_COL =>
            if (col_reg * 9) < (SAMPLE_W * 1) then
              heading_ofs := -4;
            elsif (col_reg * 9) < (SAMPLE_W * 2) then
              heading_ofs := -3;
            elsif (col_reg * 9) < (SAMPLE_W * 3) then
              heading_ofs := -2;
            elsif (col_reg * 9) < (SAMPLE_W * 4) then
              heading_ofs := -1;
            elsif (col_reg * 9) < (SAMPLE_W * 5) then
              heading_ofs := 0;
            elsif (col_reg * 9) < (SAMPLE_W * 6) then
              heading_ofs := 1;
            elsif (col_reg * 9) < (SAMPLE_W * 7) then
              heading_ofs := 2;
            elsif (col_reg * 9) < (SAMPLE_W * 8) then
              heading_ofs := 3;
            else
              heading_ofs := 4;
            end if;

            ray_heading := wrap_heading(head_reg + heading_ofs);
            ray_dx_reg <= dir_x(ray_heading);
            ray_dy_reg <= dir_y(ray_heading);

            player_tile_x := player_x_fp / TILE_SIZE_FP;
            player_tile_y := player_y_fp / TILE_SIZE_FP;
            frac_x := player_x_fp mod TILE_SIZE_FP;
            frac_y := player_y_fp mod TILE_SIZE_FP;

            map_x_reg <= player_tile_x;
            map_y_reg <= player_tile_y;

            if dir_x(ray_heading) >= 0 then
              step_x_reg <= 1;
            else
              step_x_reg <= -1;
            end if;

            if dir_y(ray_heading) >= 0 then
              step_y_reg <= 1;
            else
              step_y_reg <= -1;
            end if;

            if abs(dir_x(ray_heading)) < 8 then
              inv_dx := DIST_SCALE;
            else
              inv_dx := DIST_SCALE / abs(dir_x(ray_heading));
            end if;

            if abs(dir_y(ray_heading)) < 8 then
              inv_dy := DIST_SCALE;
            else
              inv_dy := DIST_SCALE / abs(dir_y(ray_heading));
            end if;

            delta_x_reg <= inv_dx;
            delta_y_reg <= inv_dy;

            if dir_x(ray_heading) >= 0 then
              side_x_reg <= (TILE_SIZE_FP - frac_x) * inv_dx;
            else
              side_x_reg <= frac_x * inv_dx;
            end if;

            if dir_y(ray_heading) >= 0 then
              side_y_reg <= (TILE_SIZE_FP - frac_y) * inv_dy;
            else
              side_y_reg <= frac_y * inv_dy;
            end if;

            step_count_reg <= 0;
            hit_side_reg <= 0;
            hit_reg <= '0';
            perp_dist_reg <= DIST_SCALE;
            state <= S_STEP;

          when S_STEP =>
            nx := map_x_reg;
            ny := map_y_reg;

            if side_x_reg < side_y_reg then
              nx := map_x_reg + step_x_reg;
              map_x_reg <= nx;
              side_x_reg <= side_x_reg + (TILE_SIZE_FP * delta_x_reg);
              hit_side_reg <= 0;
              perp_dist_reg <= side_x_reg;
            else
              ny := map_y_reg + step_y_reg;
              map_y_reg <= ny;
              side_y_reg <= side_y_reg + (TILE_SIZE_FP * delta_y_reg);
              hit_side_reg <= 1;
              perp_dist_reg <= side_y_reg;
            end if;

            if map_is_wall(nx, ny) then
              hit_reg <= '1';
              state <= S_WRITE;
            elsif step_count_reg = MAX_STEPS - 1 then
              hit_reg <= '0';
              state <= S_WRITE;
            else
              step_count_reg <= step_count_reg + 1;
            end if;

          when S_WRITE =>
            if hit_reg = '1' then
              dist_v := perp_dist_reg / TILE_SIZE_FP;
            else
              dist_v := MAX_STEPS * 2;
            end if;

            if dist_v < 2 then
              slice_h := SCREEN_H - 18;
              color_v := x"FD4";
            elsif dist_v < 4 then
              slice_h := (SCREEN_H * 3) / 4;
              color_v := x"DA3";
            elsif dist_v < 7 then
              slice_h := SCREEN_H / 2;
              color_v := x"B82";
            elsif dist_v < 12 then
              slice_h := SCREEN_H / 3;
              color_v := x"975";
            elsif dist_v < 18 then
              slice_h := SCREEN_H / 4;
              color_v := x"753";
            else
              slice_h := SCREEN_H / 5;
              color_v := x"532";
            end if;

            if hit_side_reg = 1 then
              color_v(11 downto 8) := std_logic_vector(unsigned(color_v(11 downto 8)) - 1);
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

            write_en <= '1';
            write_column <= col_reg;
            wall_top <= top_v;
            wall_bottom <= bot_v;
            wall_color <= color_v;

            if col_reg = SAMPLE_W - 1 then
              busy <= '0';
              frame_done <= '1';
              state <= S_IDLE;
            else
              col_reg <= col_reg + 1;
              state <= S_INIT_COL;
            end if;
        end case;
      end if;
    end if;
  end process;
end architecture;
