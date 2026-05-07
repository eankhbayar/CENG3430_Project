library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

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

  type int_array_t is array (0 to SCREEN_W - 1) of integer range 0 to SCREEN_H - 1;
  type rgb_array_t is array (0 to SCREEN_W - 1) of std_logic_vector(11 downto 0);

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
  signal ray_write_col : integer range 0 to SCREEN_W - 1;
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
      MOVE_STEP_FP => 20,
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
      SCREEN_H => SCREEN_H
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
  begin
    if rising_edge(clk_pix) then
      if vga_active = '1' then
        if pix_y < wall_top_buf(pix_x) then
          c := x"37A";
        elsif pix_y <= wall_bottom_buf(pix_x) then
          c := wall_color_buf(pix_x);
        else
          c := x"242";
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
