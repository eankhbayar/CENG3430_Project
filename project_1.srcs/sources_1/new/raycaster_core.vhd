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
  constant MAX_STEPS : integer := 24;

  type state_t is (S_IDLE, S_INIT_COL, S_STEP, S_WRITE);
  signal state : state_t := S_IDLE;

  signal head_reg : heading_t := 0;
  signal col_reg : integer range 0 to SAMPLE_W - 1 := 0;
  signal pos_phase_reg : integer range 0 to 7 := 0;

  signal tile_x_reg : integer := 0;
  signal tile_y_reg : integer := 0;
  signal step_dx_reg : integer range -1 to 1 := 0;
  signal step_dy_reg : integer range -1 to 1 := 0;
  signal step_count_reg : integer range 0 to MAX_STEPS := 0;
  signal hit_reg : std_logic := '0';
begin
  process(clk)
    variable heading_ofs : integer;
    variable ray_heading : heading_t;
    variable dir_code : integer;
    variable nx : integer;
    variable ny : integer;
    variable dist_class : integer;
    variable slice_h : integer;
    variable top_v : integer;
    variable bot_v : integer;
    variable color_v : std_logic_vector(11 downto 0);
    variable map_px : integer;
    variable map_py : integer;
    variable phase_accum : integer;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        state <= S_IDLE;
        head_reg <= 0;
        col_reg <= 0;
        tile_x_reg <= 0;
        tile_y_reg <= 0;
        step_dx_reg <= 0;
        step_dy_reg <= 0;
        step_count_reg <= 0;
        hit_reg <= '0';
        write_en <= '0';
        write_column <= 0;
        wall_top <= 0;
        wall_bottom <= SCREEN_H - 1;
        wall_color <= x"444";
        busy <= '0';
        frame_done <= '0';
        pos_phase_reg <= 0;
      else
        write_en <= '0';
        frame_done <= '0';

        case state is
          when S_IDLE =>
            busy <= '0';
            if start = '1' then
              head_reg <= wrap_heading(heading_idx);
              col_reg <= 0;
              phase_accum := ((player_x_fp / 32) + (player_y_fp / 32)) mod 8;
              if phase_accum < 0 then
                phase_accum := phase_accum + 8;
              end if;
              pos_phase_reg <= phase_accum;
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
            dir_code := ray_heading / 2;

            case dir_code is
              when 0 => step_dx_reg <= 1;  step_dy_reg <= 0;
              when 1 => step_dx_reg <= 1;  step_dy_reg <= 1;
              when 2 => step_dx_reg <= 0;  step_dy_reg <= 1;
              when 3 => step_dx_reg <= -1; step_dy_reg <= 1;
              when 4 => step_dx_reg <= -1; step_dy_reg <= 0;
              when 5 => step_dx_reg <= -1; step_dy_reg <= -1;
              when 6 => step_dx_reg <= 0;  step_dy_reg <= -1;
              when others => step_dx_reg <= 1; step_dy_reg <= -1;
            end case;

            map_px := player_x_fp / TILE_SIZE_FP;
            map_py := player_y_fp / TILE_SIZE_FP;
            tile_x_reg <= map_px;
            tile_y_reg <= map_py;
            step_count_reg <= 0;
            hit_reg <= '0';
            state <= S_STEP;

          when S_STEP =>
            nx := tile_x_reg + step_dx_reg;
            ny := tile_y_reg + step_dy_reg;

            tile_x_reg <= nx;
            tile_y_reg <= ny;

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
              dist_class := step_count_reg;
            else
              dist_class := MAX_STEPS;
            end if;

            dist_class := dist_class + (pos_phase_reg / 2);
            if (head_reg mod 2) = 1 then
              dist_class := dist_class + 1;
            end if;

            if dist_class < 2 then
              slice_h := SCREEN_H - 16;
              color_v := x"FD4";
            elsif dist_class < 4 then
              slice_h := (SCREEN_H * 3) / 4;
              color_v := x"DA3";
            elsif dist_class < 7 then
              slice_h := SCREEN_H / 2;
              color_v := x"B82";
            elsif dist_class < 12 then
              slice_h := SCREEN_H / 3;
              color_v := x"975";
            elsif dist_class < 18 then
              slice_h := SCREEN_H / 4;
              color_v := x"753";
            else
              slice_h := SCREEN_H / 5;
              color_v := x"532";
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
