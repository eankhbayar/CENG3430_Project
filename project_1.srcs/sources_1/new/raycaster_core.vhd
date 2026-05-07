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
    start : in std_logic;
    player_x_fp : in integer;
    player_y_fp : in integer;
    heading_idx : in integer range 0 to 15;
    write_en : out std_logic;
    write_column : out integer range 0 to SCREEN_W - 1;
    wall_top : out integer range 0 to SCREEN_H - 1;
    wall_bottom : out integer range 0 to SCREEN_H - 1;
    wall_color : out std_logic_vector(11 downto 0);
    busy : out std_logic;
    frame_done : out std_logic
  );
end entity;

architecture rtl of raycaster_core is
  type state_t is (S_IDLE, S_INIT_COL, S_STEP_RAY, S_WRITE_COL);

  signal state : state_t := S_IDLE;

  signal p_x_reg : integer := 0;
  signal p_y_reg : integer := 0;
  signal head_reg : heading_t := 0;

  signal col_reg : integer range 0 to SCREEN_W - 1 := 0;
  signal ray_heading_reg : heading_t := 0;
  signal step_x_fp_reg : integer := 0;
  signal step_y_fp_reg : integer := 0;
  signal sample_x_fp_reg : integer := 0;
  signal sample_y_fp_reg : integer := 0;
  signal dist_fp_reg : integer := 48;
  signal step_count_reg : integer range 0 to 47 := 0;

  signal hit_reg : std_logic := '0';
begin
  process(clk)
    variable heading_ofs : integer;
    variable next_x : integer;
    variable next_y : integer;
    variable next_dist : integer;
    variable tile_x : integer;
    variable tile_y : integer;
    variable slice_h : integer;
    variable top_v : integer;
    variable bot_v : integer;
    variable color_v : std_logic_vector(11 downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        state <= S_IDLE;
        p_x_reg <= 0;
        p_y_reg <= 0;
        head_reg <= 0;
        col_reg <= 0;
        ray_heading_reg <= 0;
        step_x_fp_reg <= 0;
        step_y_fp_reg <= 0;
        sample_x_fp_reg <= 0;
        sample_y_fp_reg <= 0;
        dist_fp_reg <= 48;
        step_count_reg <= 0;
        hit_reg <= '0';
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
              p_x_reg <= player_x_fp;
              p_y_reg <= player_y_fp;
              head_reg <= wrap_heading(heading_idx);
              col_reg <= 0;
              busy <= '1';
              state <= S_INIT_COL;
            end if;

          when S_INIT_COL =>
            if (col_reg * 8) < (SCREEN_W * 1) then
              heading_ofs := -3;
            elsif (col_reg * 8) < (SCREEN_W * 2) then
              heading_ofs := -2;
            elsif (col_reg * 8) < (SCREEN_W * 3) then
              heading_ofs := -1;
            elsif (col_reg * 8) < (SCREEN_W * 5) then
              heading_ofs := 0;
            elsif (col_reg * 8) < (SCREEN_W * 6) then
              heading_ofs := 1;
            elsif (col_reg * 8) < (SCREEN_W * 7) then
              heading_ofs := 2;
            else
              heading_ofs := 3;
            end if;

            ray_heading_reg <= wrap_heading(head_reg + heading_ofs);
            step_x_fp_reg <= (dir_x(wrap_heading(head_reg + heading_ofs)) * 48) / 256;
            step_y_fp_reg <= (dir_y(wrap_heading(head_reg + heading_ofs)) * 48) / 256;

            if ((dir_x(wrap_heading(head_reg + heading_ofs)) * 48) / 256 = 0) and
               ((dir_y(wrap_heading(head_reg + heading_ofs)) * 48) / 256 = 0) then
              step_x_fp_reg <= 1;
            end if;

            sample_x_fp_reg <= p_x_reg;
            sample_y_fp_reg <= p_y_reg;
            dist_fp_reg <= 48;
            step_count_reg <= 0;
            hit_reg <= '0';
            state <= S_STEP_RAY;

          when S_STEP_RAY =>
            next_x := sample_x_fp_reg + step_x_fp_reg;
            next_y := sample_y_fp_reg + step_y_fp_reg;
            next_dist := dist_fp_reg + 48;

            sample_x_fp_reg <= next_x;
            sample_y_fp_reg <= next_y;
            dist_fp_reg <= next_dist;

            tile_x := next_x / TILE_SIZE_FP;
            tile_y := next_y / TILE_SIZE_FP;

            if map_is_wall(tile_x, tile_y) then
              hit_reg <= '1';
              state <= S_WRITE_COL;
            elsif step_count_reg = 47 then
              hit_reg <= '0';
              state <= S_WRITE_COL;
            else
              step_count_reg <= step_count_reg + 1;
            end if;

          when S_WRITE_COL =>
            if dist_fp_reg < 96 then
              slice_h := SCREEN_H;
            else
              slice_h := (SCREEN_H * 140) / dist_fp_reg;
            end if;

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

            if hit_reg = '0' then
              color_v := x"444";
            elsif dist_fp_reg < 220 then
              color_v := x"FD4";
            elsif dist_fp_reg < 380 then
              color_v := x"DA3";
            elsif dist_fp_reg < 620 then
              color_v := x"A72";
            else
              color_v := x"753";
            end if;

            write_en <= '1';
            write_column <= col_reg;
            wall_top <= top_v;
            wall_bottom <= bot_v;
            wall_color <= color_v;

            if col_reg = SCREEN_W - 1 then
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
