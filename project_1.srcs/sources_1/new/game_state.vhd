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
    muzzle_flash : out std_logic
  );
end entity;

architecture rtl of game_state is
  constant TICK_DIV : integer := CLK_HZ / TICK_HZ;

  signal tick_counter : integer range 0 to TICK_DIV - 1 := 0;
  signal tick_en : std_logic := '0';

  signal p_x_fp : integer := (3 * TILE_SIZE_FP) + (TILE_SIZE_FP / 2);
  signal p_y_fp : integer := (3 * TILE_SIZE_FP) + (TILE_SIZE_FP / 2);
  signal head_i : heading_t := 0;

  signal cooldown : integer range 0 to SHOOT_COOLDOWN_TICKS := 0;
  signal flash_cnt : integer range 0 to 10 := 0;
  signal turn_delay : integer range 0 to 2 := 0;

  signal btnc_d : std_logic := '0';

  signal shoot_evt : std_logic := '0';
  signal shoot_hit_i : std_logic := '0';
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
  begin
    if rising_edge(clk) then
      if rst = '1' then
        p_x_fp <= (3 * TILE_SIZE_FP) + (TILE_SIZE_FP / 2);
        p_y_fp <= (3 * TILE_SIZE_FP) + (TILE_SIZE_FP / 2);
        head_i <= 0;
        cooldown <= 0;
        flash_cnt <= 0;
        turn_delay <= 0;
        btnc_d <= '0';
        shoot_evt <= '0';
        shoot_hit_i <= '0';
      elsif tick_en = '1' then
        shoot_evt <= '0';
        shoot_hit_i <= '0';

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

        if (btnc = '1') and (btnc_d = '0') and (cooldown = 0) then
          shoot_evt <= '1';
          cooldown <= SHOOT_COOLDOWN_TICKS;
          flash_cnt <= 8;
          shoot_hit_i <= '0';
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
end architecture;
