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

  constant DIGIT_W : integer := 14;
  constant DIGIT_H : integer := 24;
  constant HUD_Y : integer := 8;

  type int_array_t is array (0 to SAMPLE_W - 1) of integer range 0 to SCREEN_H - 1;
  type rgb_array_t is array (0 to SAMPLE_W - 1) of std_logic_vector(11 downto 0);

  function seg_lit(d : integer; s : integer) return boolean is
  begin
    case d is
      when 0 => return (s = 0) or (s = 1) or (s = 2) or (s = 3) or (s = 4) or (s = 5);
      when 1 => return (s = 1) or (s = 2);
      when 2 => return (s = 0) or (s = 1) or (s = 6) or (s = 4) or (s = 3);
      when 3 => return (s = 0) or (s = 1) or (s = 6) or (s = 2) or (s = 3);
      when 4 => return (s = 5) or (s = 6) or (s = 1) or (s = 2);
      when 5 => return (s = 0) or (s = 5) or (s = 6) or (s = 2) or (s = 3);
      when 6 => return (s = 0) or (s = 5) or (s = 6) or (s = 2) or (s = 3) or (s = 4);
      when 7 => return (s = 0) or (s = 1) or (s = 2);
      when 8 => return true;
      when 9 => return (s = 0) or (s = 1) or (s = 2) or (s = 3) or (s = 5) or (s = 6);
      when others => return false;
    end case;
  end function;

  function digit_pixel(d : integer; lx : integer; ly : integer) return boolean is
  begin
    if (seg_lit(d, 0) and (ly <= 1) and (lx >= 2) and (lx <= 11)) or
       (seg_lit(d, 1) and (lx >= 12) and (ly >= 2) and (ly <= 10)) or
       (seg_lit(d, 2) and (lx >= 12) and (ly >= 12) and (ly <= 20)) or
       (seg_lit(d, 3) and (ly >= 22) and (lx >= 2) and (lx <= 11)) or
       (seg_lit(d, 4) and (lx <= 1) and (ly >= 12) and (ly <= 20)) or
       (seg_lit(d, 5) and (lx <= 1) and (ly >= 2) and (ly <= 10)) or
       (seg_lit(d, 6) and (ly >= 10) and (ly <= 13) and (lx >= 2) and (lx <= 11)) then
      return true;
    end if;
    return false;
  end function;

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
  signal enemy_alive : std_logic;
  signal bullet_active : std_logic;
  signal enemy_x_tile : integer range 0 to MAP_W - 1;
  signal enemy_y_tile : integer range 0 to MAP_H - 1;
  signal kill_count : integer range 0 to 99;
  signal score : integer range 0 to 9999;
  signal level : integer range 0 to 9;

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
  signal enemy_visible_frame : std_logic := '0';
  signal enemy_screen_x_frame : integer range 0 to SCREEN_W - 1 := SCREEN_W / 2;
  signal enemy_size_frame : integer range 12 to 120 := 48;

  signal score_d3 : integer range 0 to 9 := 0;
  signal score_d2 : integer range 0 to 9 := 0;
  signal score_d1 : integer range 0 to 9 := 0;
  signal score_d0 : integer range 0 to 9 := 0;
  signal kills_d1 : integer range 0 to 9 := 0;
  signal kills_d0 : integer range 0 to 9 := 0;

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
      muzzle_flash => muzzle_flash,
      enemy_alive => enemy_alive,
      bullet_active => bullet_active,
      enemy_x_tile => enemy_x_tile,
      enemy_y_tile => enemy_y_tile,
      kill_count => kill_count,
      score => score,
      level => level
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
    variable player_tile_x : integer;
    variable player_tile_y : integer;
    variable enemy_vec_x : integer;
    variable enemy_vec_y : integer;
    variable dir_code : integer;
    variable look_dx : integer;
    variable look_dy : integer;
    variable dot_v : integer;
    variable cross_v : integer;
    variable sx : integer;
    variable sz : integer;
  begin
    if rising_edge(clk_pix) then
      ray_start <= '0';

      if frame_start = '1' and ray_busy = '0' then
        player_x_frame <= player_x_fp;
        player_y_frame <= player_y_fp;
        heading_frame <= heading_idx;
        ray_start <= '1';

        score_d3 <= (score / 1000) mod 10;
        score_d2 <= (score / 100) mod 10;
        score_d1 <= (score / 10) mod 10;
        score_d0 <= score mod 10;
        kills_d1 <= (kill_count / 10) mod 10;
        kills_d0 <= kill_count mod 10;

        player_tile_x := player_x_fp / TILE_SIZE_FP;
        player_tile_y := player_y_fp / TILE_SIZE_FP;
        enemy_vec_x := enemy_x_tile - player_tile_x;
        enemy_vec_y := enemy_y_tile - player_tile_y;

        dir_code := heading_idx / 2;
        case dir_code is
          when 0 => look_dx := 1;  look_dy := 0;
          when 1 => look_dx := 1;  look_dy := 1;
          when 2 => look_dx := 0;  look_dy := 1;
          when 3 => look_dx := -1; look_dy := 1;
          when 4 => look_dx := -1; look_dy := 0;
          when 5 => look_dx := -1; look_dy := -1;
          when 6 => look_dx := 0;  look_dy := -1;
          when others => look_dx := 1; look_dy := -1;
        end case;

        dot_v := enemy_vec_x * look_dx + enemy_vec_y * look_dy;
        cross_v := enemy_vec_x * look_dy - enemy_vec_y * look_dx;

        if (enemy_alive = '1') and (dot_v > 0) and (dot_v <= 16) and (abs(cross_v) <= dot_v + 1) then
          enemy_visible_frame <= '1';
          sx := (SCREEN_W / 2) + (cross_v * 20);
          if sx < 40 then
            enemy_screen_x_frame <= 40;
          elsif sx > SCREEN_W - 40 then
            enemy_screen_x_frame <= SCREEN_W - 40;
          else
            enemy_screen_x_frame <= sx;
          end if;

          if dot_v < 3 then
            sz := 104;
          elsif dot_v < 6 then
            sz := 80;
          elsif dot_v < 9 then
            sz := 60;
          else
            sz := 44;
          end if;
          enemy_size_frame <= sz;
        else
          enemy_visible_frame <= '0';
          enemy_screen_x_frame <= SCREEN_W / 2;
          enemy_size_frame <= 44;
        end if;
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
    variable body_top : integer;
    variable body_bot : integer;
    variable lx : integer;
    variable ly : integer;
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

        if enemy_visible_frame = '1' then
          body_top := 240 - enemy_size_frame;
          body_bot := 240 + enemy_size_frame;

          if (pix_x >= enemy_screen_x_frame - (enemy_size_frame / 5)) and
             (pix_x <= enemy_screen_x_frame + (enemy_size_frame / 5)) and
             (pix_y >= body_top + (enemy_size_frame / 2)) and
             (pix_y <= body_bot) then
            c := x"000";
          elsif (pix_x >= enemy_screen_x_frame - (enemy_size_frame / 4)) and
                (pix_x <= enemy_screen_x_frame + (enemy_size_frame / 4)) and
                (pix_y >= body_top) and
                (pix_y <= body_top + (enemy_size_frame / 3)) then
            c := x"000";
          elsif (pix_y = body_top + (enemy_size_frame / 2)) and
                (pix_x >= enemy_screen_x_frame - (enemy_size_frame / 2)) and
                (pix_x <= enemy_screen_x_frame + (enemy_size_frame / 2)) then
            c := x"000";
          elsif ((pix_x - enemy_screen_x_frame) = (pix_y - (body_top + (enemy_size_frame * 3 / 4)))) and
                (pix_y >= body_top + (enemy_size_frame * 3 / 4)) and (pix_y <= body_bot) then
            c := x"000";
          elsif ((enemy_screen_x_frame - pix_x) = (pix_y - (body_top + (enemy_size_frame * 3 / 4)))) and
                (pix_y >= body_top + (enemy_size_frame * 3 / 4)) and (pix_y <= body_bot) then
            c := x"000";
          end if;
        end if;

        if bullet_active = '1' and (pix_x >= 318 and pix_x <= 322) and (pix_y >= 170 and pix_y <= 320) then
          c := x"FF0";
        end if;

        if (pix_x >= 285 and pix_x <= 355) and (pix_y >= 410 and pix_y <= 479) then
          c := x"44A";
          if (pix_x >= 300 and pix_x <= 340) and (pix_y >= 430 and pix_y <= 479) then
            c := x"66C";
          end if;
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

          if (enemy_alive = '1') and (map_tile_x = enemy_x_tile) and (map_tile_y = enemy_y_tile) then
            c := x"0FF";
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

        -- Score digits (top-right)
        if (pix_y >= HUD_Y) and (pix_y < HUD_Y + DIGIT_H) then
          if (pix_x >= 500) and (pix_x < 500 + DIGIT_W) then
            lx := pix_x - 500; ly := pix_y - HUD_Y;
            if digit_pixel(score_d3, lx, ly) then c := x"FF0"; end if;
          elsif (pix_x >= 516) and (pix_x < 516 + DIGIT_W) then
            lx := pix_x - 516; ly := pix_y - HUD_Y;
            if digit_pixel(score_d2, lx, ly) then c := x"FF0"; end if;
          elsif (pix_x >= 532) and (pix_x < 532 + DIGIT_W) then
            lx := pix_x - 532; ly := pix_y - HUD_Y;
            if digit_pixel(score_d1, lx, ly) then c := x"FF0"; end if;
          elsif (pix_x >= 548) and (pix_x < 548 + DIGIT_W) then
            lx := pix_x - 548; ly := pix_y - HUD_Y;
            if digit_pixel(score_d0, lx, ly) then c := x"FF0"; end if;
          end if;

          if (pix_x >= 576) and (pix_x < 576 + DIGIT_W) then
            lx := pix_x - 576; ly := pix_y - HUD_Y;
            if digit_pixel(kills_d1, lx, ly) then c := x"0FF"; end if;
          elsif (pix_x >= 592) and (pix_x < 592 + DIGIT_W) then
            lx := pix_x - 592; ly := pix_y - HUD_Y;
            if digit_pixel(kills_d0, lx, ly) then c := x"0FF"; end if;
          elsif (pix_x >= 620) and (pix_x < 620 + DIGIT_W) then
            lx := pix_x - 620; ly := pix_y - HUD_Y;
            if digit_pixel(level, lx, ly) then c := x"F0F"; end if;
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
