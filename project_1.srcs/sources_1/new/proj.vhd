library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.raycast_pkg.ALL;

entity proj is
  Port (
    clk : in std_logic;
    hsync : out std_logic;
    vsync : out std_logic;
    red : out std_logic_vector(3 downto 0);
    green : out std_logic_vector(3 downto 0);
    blue : out std_logic_vector(3 downto 0);
    BTNU : in std_logic;
    BTND : in std_logic;
    BTNL : in std_logic;
    BTNR : in std_logic;
    BTNC : in std_logic
  );
end proj;

architecture rtl of proj is
  constant SCREEN_W : integer := 640;
  constant SCREEN_H : integer := 480;
  constant COLUMN_SCALE : integer := 8;
  constant SAMPLE_W : integer := SCREEN_W / COLUMN_SCALE;
  constant MINIMAP_SCALE : integer := 4;
  constant MINIMAP_W_PX : integer := MAP_W * MINIMAP_SCALE;
  constant MINIMAP_H_PX : integer := MAP_H * MINIMAP_SCALE;

  type int_array_t is array (0 to SAMPLE_W - 1) of integer range 0 to SCREEN_H - 1;
  type rgb_array_t is array (0 to SAMPLE_W - 1) of std_logic_vector(11 downto 0);

  signal clk_pix : std_logic;
  signal rst : std_logic := '0';

  signal vga_active : std_logic;
  signal pix_x : integer range 0 to SCREEN_W - 1;
  signal pix_y : integer range 0 to SCREEN_H - 1;
  signal frame_start : std_logic;

  signal player_x_fp : integer;
  signal player_y_fp : integer;
  signal heading_idx : integer range 0 to 15;
  signal shoot_pulse : std_logic;
  signal shoot_hit : std_logic;
  signal muzzle_flash : std_logic;

  signal ray_start : std_logic := '0';
  signal ray_busy : std_logic;
  signal ray_frame_done : std_logic;
  signal ray_write_en : std_logic;
  signal ray_write_col : integer range 0 to SAMPLE_W - 1;
  signal wall_top : integer range 0 to SCREEN_H - 1;
  signal wall_bottom : integer range 0 to SCREEN_H - 1;
  signal wall_color : std_logic_vector(11 downto 0);

  signal wall_top_buf : int_array_t := (others => SCREEN_H / 3);
  signal wall_bottom_buf : int_array_t := (others => (2 * SCREEN_H) / 3);
  signal wall_color_buf : rgb_array_t := (others => x"753");

  signal player_x_frame : integer := 0;
  signal player_y_frame : integer := 0;
  signal heading_frame  : integer range 0 to 15 := 0;

  signal rgb : std_logic_vector(11 downto 0) := (others => '0');
begin
  pix_div : entity work.clock_divider
    generic map (N => 2)
    port map (
      clk => clk,
      clk_out => clk_pix
    );

  timing_i : entity work.vga_timing
    port map (
      clk_pix => clk_pix,
      rst => rst,
      hsync => hsync,
      vsync => vsync,
      active => vga_active,
      x => pix_x,
      y => pix_y,
      frame_start => frame_start,
      line_start => open
    );

  game_i : entity work.game_state
    generic map (
      CLK_HZ => 25000000,
      TICK_HZ => 120,
      MOVE_STEP_FP => 48,
      SHOOT_COOLDOWN_TICKS => 22
    )
    port map (
      clk => clk_pix,
      rst => rst,
      btnu => BTNU,
      btnd => BTND,
      btnl => BTNL,
      btnr => BTNR,
      btnc => BTNC,
      player_x_fp => player_x_fp,
      player_y_fp => player_y_fp,
      heading_idx => heading_idx,
      shoot_pulse => shoot_pulse,
      shoot_hit => shoot_hit,
      muzzle_flash => muzzle_flash
    );

  ray_i : entity work.raycaster_core
    generic map (
      SCREEN_W => SCREEN_W,
      SCREEN_H => SCREEN_H,
      COLUMN_SCALE => COLUMN_SCALE
    )
    port map (
      clk => clk_pix,
      rst => rst,
      start => ray_start,
      player_x_fp => player_x_frame,
      player_y_fp => player_y_frame,
      heading_idx => heading_frame,
      write_en => ray_write_en,
      write_column => ray_write_col,
      wall_top => wall_top,
      wall_bottom => wall_bottom,
      wall_color => wall_color,
      busy => ray_busy,
      frame_done => ray_frame_done
    );

  process(clk_pix)
  begin
    if rising_edge(clk_pix) then
      ray_start <= '0';

      if frame_start = '1' and ray_busy = '0' then
        player_x_frame <= player_x_fp;
        player_y_frame <= player_y_fp;
        heading_frame <= heading_idx;
        ray_start <= '1';
      end if;

      if ray_write_en = '1' then
        wall_top_buf(ray_write_col) <= wall_top;
        wall_bottom_buf(ray_write_col) <= wall_bottom;
        wall_color_buf(ray_write_col) <= wall_color;
      end if;
    end if;
  end process;

  process(clk_pix)
    variable c : std_logic_vector(11 downto 0);
    variable sample_col : integer range 0 to SAMPLE_W - 1;
    variable map_tile_x : integer;
    variable map_tile_y : integer;
    variable player_tile_x : integer;
    variable player_tile_y : integer;
    variable heading_code : integer;
    variable pov_dx : integer;
    variable pov_dy : integer;
  begin
    if rising_edge(clk_pix) then
      if vga_active = '1' then
        sample_col := pix_x / COLUMN_SCALE;

        if pix_y < wall_top_buf(sample_col) then
          c := x"37A";
        elsif pix_y <= wall_bottom_buf(sample_col) then
          c := wall_color_buf(sample_col);
        else
          c := x"242";
        end if;
        if (pix_x < MINIMAP_W_PX) and (pix_y < MINIMAP_H_PX) then
          map_tile_x := pix_x / MINIMAP_SCALE;
          map_tile_y := pix_y / MINIMAP_SCALE;
          player_tile_x := player_x_fp / TILE_SIZE_FP;
          player_tile_y := player_y_fp / TILE_SIZE_FP;
          heading_code := heading_idx / 2;

          case heading_code is
            when 0 => pov_dx := 1;  pov_dy := 0;
            when 1 => pov_dx := 1;  pov_dy := 1;
            when 2 => pov_dx := 0;  pov_dy := 1;
            when 3 => pov_dx := -1; pov_dy := 1;
            when 4 => pov_dx := -1; pov_dy := 0;
            when 5 => pov_dx := -1; pov_dy := -1;
            when 6 => pov_dx := 0;  pov_dy := -1;
            when others => pov_dx := 1; pov_dy := -1;
          end case;

          if map_is_wall(map_tile_x, map_tile_y) then
            c := x"333";
          else
            c := x"062";
          end if;

          if (map_tile_x = player_tile_x) and (map_tile_y = player_tile_y) then
            c := x"FFF";
          elsif (map_tile_x = player_tile_x + pov_dx) and (map_tile_y = player_tile_y + pov_dy) then
            c := x"F00";
          end if;

          if (pix_x = 0) or (pix_y = 0) or (pix_x = MINIMAP_W_PX - 1) or (pix_y = MINIMAP_H_PX - 1) then
            c := x"FFF";
          end if;
        end if;

        if ((pix_x >= 316 and pix_x <= 324) and (pix_y = 240)) or
           ((pix_y >= 236 and pix_y <= 244) and (pix_x = 320)) then
          c := x"FFF";
        end if;

        if muzzle_flash = '1' and (pix_x > 290 and pix_x < 350) and (pix_y > 420 and pix_y < 470) then
          if shoot_hit = '1' then
            c := x"F33";
          else
            c := x"FB0";
          end if;
        end if;

        rgb <= c;
      else
        rgb <= (others => '0');
      end if;
    end if;
  end process;

  red <= rgb(11 downto 8);
  green <= rgb(7 downto 4);
  blue <= rgb(3 downto 0);
end architecture;
