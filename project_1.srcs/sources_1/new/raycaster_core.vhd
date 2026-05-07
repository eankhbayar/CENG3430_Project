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
  type state_t is (S_IDLE, S_RENDER);
  signal state : state_t := S_IDLE;
  signal col_reg : integer range 0 to SCREEN_W - 1 := 0;
  signal heading_reg : heading_t := 0;
begin
  process(clk)
    variable dist_class : integer;
    variable slice_h : integer;
    variable top_v : integer;
    variable bot_v : integer;
    variable color_v : std_logic_vector(11 downto 0);
    variable heading_band : integer;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        state <= S_IDLE;
        col_reg <= 0;
        heading_reg <= 0;
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
              col_reg <= 0;
              heading_reg <= wrap_heading(heading_idx);
              busy <= '1';
              state <= S_RENDER;
            end if;

          when S_RENDER =>
            if heading_reg < 4 then
              heading_band := 0;
            elsif heading_reg < 8 then
              heading_band := 1;
            elsif heading_reg < 12 then
              heading_band := 2;
            else
              heading_band := 3;
            end if;

            if col_reg < (SCREEN_W / 8) then
              dist_class := 4 + heading_band;
            elsif col_reg < (SCREEN_W / 4) then
              dist_class := 3 + heading_band;
            elsif col_reg < ((3 * SCREEN_W) / 8) then
              dist_class := 2 + heading_band;
            elsif col_reg < ((5 * SCREEN_W) / 8) then
              dist_class := 1 + heading_band;
            elsif col_reg < ((3 * SCREEN_W) / 4) then
              dist_class := 2 + heading_band;
            elsif col_reg < ((7 * SCREEN_W) / 8) then
              dist_class := 3 + heading_band;
            else
              dist_class := 4 + heading_band;
            end if;

            if dist_class <= 1 then
              slice_h := SCREEN_H - 20;
              color_v := x"FD4";
            elsif dist_class = 2 then
              slice_h := (SCREEN_H * 3) / 4;
              color_v := x"DA3";
            elsif dist_class = 3 then
              slice_h := SCREEN_H / 2;
              color_v := x"B82";
            elsif dist_class = 4 then
              slice_h := SCREEN_H / 3;
              color_v := x"975";
            else
              slice_h := SCREEN_H / 4;
              color_v := x"753";
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

            if col_reg = SCREEN_W - 1 then
              busy <= '0';
              frame_done <= '1';
              state <= S_IDLE;
            else
              col_reg <= col_reg + 1;
            end if;
        end case;
      end if;
    end if;
  end process;
end architecture;
