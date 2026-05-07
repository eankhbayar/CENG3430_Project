library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.raycast_pkg.ALL;

entity game_state is
  generic (
    CLK_HZ : integer := 25000000;
    TICK_HZ : integer := 120;
    MOVE_STEP_FP : integer := 18;
    SHOOT_COOLDOWN_TICKS : integer := 18
  );
  port (
    clk : in std_logic;
    rst : in std_logic;
    btnu : in std_logic;
    btnd : in std_logic;
    btnl : in std_logic;
    btnr : in std_logic;
    btnc : in std_logic;
    player_x_fp : out integer;
    player_y_fp : out integer;
    heading_idx : out integer range 0 to 15;
    shoot_pulse : out std_logic;
    shoot_hit : out std_logic;
    muzzle_flash : out std_logic;
    enemy_alive : out std_logic;
    bullet_active : out std_logic;
    enemy_x_tile : out integer range 0 to MAP_W - 1;
    enemy_y_tile : out integer range 0 to MAP_H - 1;
    kill_count : out integer range 0 to 99;
    score : out integer range 0 to 9999;
    level : out integer range 0 to 9
  );
end entity;

architecture rtl of game_state is
  constant TICK_DIV : integer := CLK_HZ / TICK_HZ;
  constant ENEMY_RESPAWN_TICKS : integer := 360;
  constant ENEMY_RESPAWN_MIN_TICKS : integer := 120;
  constant ENEMY_RESPAWN_STEP : integer := 8;

  signal tick_counter : integer range 0 to TICK_DIV - 1 := 0;
  signal tick_en : std_logic := '0';

  signal p_x_fp : integer := (3 * TILE_SIZE_FP) + (TILE_SIZE_FP / 2);
  signal p_y_fp : integer := (3 * TILE_SIZE_FP) + (TILE_SIZE_FP / 2);
  signal head_i : heading_t := 0;

  signal cooldown : integer range 0 to SHOOT_COOLDOWN_TICKS := 0;
  signal flash_cnt : integer range 0 to 10 := 0;
  signal bullet_cnt : integer range 0 to 6 := 0;
  signal turn_delay : integer range 0 to 2 := 0;

  signal btnc_d : std_logic := '0';

  signal shoot_evt : std_logic := '0';
  signal shoot_hit_i : std_logic := '0';
  signal enemy_alive_i : std_logic := '1';
  signal enemy_respawn_cnt : integer range 0 to ENEMY_RESPAWN_TICKS := 0;
  signal enemy_x_i : integer range 0 to MAP_W - 1 := 20;
  signal enemy_y_i : integer range 0 to MAP_H - 1 := 6;
  signal kill_count_i : integer range 0 to 99 := 0;
  signal score_i : integer range 0 to 9999 := 0;
  signal lfsr : std_logic_vector(15 downto 0) := x"ACE1";
begin
  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        tick_counter <= 0;
        tick_en <= '0';
      else
        if tick_counter = TICK_DIV - 1 then
          tick_counter <= 0;
          tick_en <= '1';
        else
          tick_counter <= tick_counter + 1;
          tick_en <= '0';
        end if;
      end if;
    end if;
  end process;

  process(clk)
    variable dirx, diry : integer;
    variable n_x, n_y : integer;
    variable tx, ty : integer;
    variable dir_code : integer;
    variable look_dx, look_dy : integer;
    variable enemy_vec_x : integer;
    variable enemy_vec_y : integer;
    variable dot_v : integer;
    variable cross_v : integer;
    variable spawn_sel : integer;
    variable spawn_x : integer;
    variable spawn_y : integer;
    variable lfsr_n : std_logic_vector(15 downto 0);
    variable next_respawn : integer;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        p_x_fp <= (3 * TILE_SIZE_FP) + (TILE_SIZE_FP / 2);
        p_y_fp <= (3 * TILE_SIZE_FP) + (TILE_SIZE_FP / 2);
        head_i <= 0;
        cooldown <= 0;
        flash_cnt <= 0;
        bullet_cnt <= 0;
        turn_delay <= 0;
        btnc_d <= '0';
        shoot_evt <= '0';
        shoot_hit_i <= '0';
        enemy_alive_i <= '1';
        enemy_respawn_cnt <= 0;
        enemy_x_i <= 20;
        enemy_y_i <= 6;
        kill_count_i <= 0;
        score_i <= 0;
        lfsr <= x"ACE1";
      elsif tick_en = '1' then
        shoot_evt <= '0';
        shoot_hit_i <= '0';

        lfsr_n := lfsr(14 downto 0) & (lfsr(15) xor lfsr(13) xor lfsr(12) xor lfsr(10));
        lfsr <= lfsr_n;

        if btnl = '1' and btnr = '0' then
          if turn_delay = 0 then
            head_i <= wrap_heading(head_i - 1);
            turn_delay <= 2;
          else
            turn_delay <= turn_delay - 1;
          end if;
        elsif btnr = '1' and btnl = '0' then
          if turn_delay = 0 then
            head_i <= wrap_heading(head_i + 1);
            turn_delay <= 2;
          else
            turn_delay <= turn_delay - 1;
          end if;
        else
          turn_delay <= 0;
        end if;

        dirx := dir_x(head_i);
        diry := dir_y(head_i);

        if btnu = '1' and btnd = '0' then
          n_x := p_x_fp + ((dirx * MOVE_STEP_FP) / 256);
          n_y := p_y_fp + ((diry * MOVE_STEP_FP) / 256);

          tx := n_x / TILE_SIZE_FP;
          ty := n_y / TILE_SIZE_FP;
          if not map_is_wall(tx, ty) then
            p_x_fp <= n_x;
            p_y_fp <= n_y;
          end if;
        elsif btnd = '1' and btnu = '0' then
          n_x := p_x_fp - ((dirx * MOVE_STEP_FP) / 256);
          n_y := p_y_fp - ((diry * MOVE_STEP_FP) / 256);

          tx := n_x / TILE_SIZE_FP;
          ty := n_y / TILE_SIZE_FP;
          if not map_is_wall(tx, ty) then
            p_x_fp <= n_x;
            p_y_fp <= n_y;
          end if;
        end if;

        if cooldown > 0 then
          cooldown <= cooldown - 1;
        end if;

        if flash_cnt > 0 then
          flash_cnt <= flash_cnt - 1;
        end if;

        if bullet_cnt > 0 then
          bullet_cnt <= bullet_cnt - 1;
        end if;

        if enemy_alive_i = '0' then
          if enemy_respawn_cnt > 0 then
            enemy_respawn_cnt <= enemy_respawn_cnt - 1;
          else
            spawn_sel := to_integer(unsigned(lfsr_n(2 downto 0)));
            case spawn_sel is
              when 0 => spawn_x := 25; spawn_y := 6;
              when 1 => spawn_x := 26; spawn_y := 20;
              when 2 => spawn_x := 6;  spawn_y := 26;
              when 3 => spawn_x := 20; spawn_y := 9;
              when 4 => spawn_x := 28; spawn_y := 14;
              when 5 => spawn_x := 12; spawn_y := 28;
              when 6 => spawn_x := 4;  spawn_y := 20;
              when others => spawn_x := 22; spawn_y := 4;
            end case;

            if not map_is_wall(spawn_x, spawn_y) then
              enemy_x_i <= spawn_x;
              enemy_y_i <= spawn_y;
              enemy_alive_i <= '1';
            else
              enemy_x_i <= 20;
              enemy_y_i <= 6;
              enemy_alive_i <= '1';
            end if;
          end if;
        end if;

        if (btnc = '1') and (btnc_d = '0') and (cooldown = 0) then
          shoot_evt <= '1';
          cooldown <= SHOOT_COOLDOWN_TICKS;
          flash_cnt <= 8;
          bullet_cnt <= 3;

          if enemy_alive_i = '1' then
            tx := p_x_fp / TILE_SIZE_FP;
            ty := p_y_fp / TILE_SIZE_FP;

            enemy_vec_x := enemy_x_i - tx;
            enemy_vec_y := enemy_y_i - ty;

            dir_code := head_i / 2;
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

            if (dot_v > 0) and (dot_v <= 16) and (abs(cross_v) <= 1) then
              shoot_hit_i <= '1';
              enemy_alive_i <= '0';

              if kill_count_i < 99 then
                kill_count_i <= kill_count_i + 1;
              end if;

              if score_i <= 9899 then
                score_i <= score_i + 100;
              else
                score_i <= 9999;
              end if;

              next_respawn := ENEMY_RESPAWN_TICKS - (kill_count_i * ENEMY_RESPAWN_STEP);
              if next_respawn < ENEMY_RESPAWN_MIN_TICKS then
                next_respawn := ENEMY_RESPAWN_MIN_TICKS;
              end if;
              enemy_respawn_cnt <= next_respawn;
            end if;
          end if;
        end if;

        btnc_d <= btnc;
      end if;
    end if;
  end process;

  player_x_fp <= p_x_fp;
  player_y_fp <= p_y_fp;
  heading_idx <= head_i;
  shoot_pulse <= shoot_evt;
  shoot_hit <= shoot_hit_i;
  muzzle_flash <= '1' when flash_cnt > 0 else '0';
  enemy_alive <= enemy_alive_i;
  bullet_active <= '1' when bullet_cnt > 0 else '0';
  enemy_x_tile <= enemy_x_i;
  enemy_y_tile <= enemy_y_i;
  kill_count <= kill_count_i;
  score <= score_i;
  level <= kill_count_i / 5;
end architecture;
