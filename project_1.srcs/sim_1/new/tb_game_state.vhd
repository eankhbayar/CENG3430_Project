library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.env.all;
use work.raycast_pkg.ALL;

entity tb_game_state is
end entity;

architecture tb of tb_game_state is
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal btnu, btnd, btnl, btnr, btnc : std_logic := '0';
  signal px, py : integer;
  signal heading : integer range 0 to 15;
  signal shoot_pulse, shoot_hit, muzzle_flash : std_logic;
  signal enemy_alive, bullet_active : std_logic;
  signal done : boolean := false;
begin
  clk <= not clk after 5 ns when not done else '0';

  dut : entity work.game_state
    generic map (
      CLK_HZ => 1000,
      TICK_HZ => 100,
      MOVE_STEP_FP => 32,
      SHOOT_COOLDOWN_TICKS => 6
    )
    port map (
      clk => clk,
      rst => rst,
      btnu => btnu,
      btnd => btnd,
      btnl => btnl,
      btnr => btnr,
      btnc => btnc,
      player_x_fp => px,
      player_y_fp => py,
      heading_idx => heading,
      shoot_pulse => shoot_pulse,
      shoot_hit => shoot_hit,
      muzzle_flash => muzzle_flash,
      enemy_alive => enemy_alive,
      bullet_active => bullet_active
    );

  stim : process
    variable start_x, start_y : integer;
    variable tx, ty : integer;
  begin
    wait for 50 ns;
    rst <= '0';

    wait for 500 ns;
    start_x := px;
    start_y := py;

    btnr <= '1';
    wait for 280 ns;
    btnr <= '0';
    wait for 120 ns;
    assert heading /= 0 report "Turn-right did not change heading" severity failure;

    btnu <= '1';
    wait for 1200 ns;
    btnu <= '0';
    wait for 120 ns;

    assert (px /= start_x) or (py /= start_y) report "Forward movement did not change player position" severity failure;

    tx := px / TILE_SIZE_FP;
    ty := py / TILE_SIZE_FP;
    assert not map_is_wall(tx, ty) report "Player moved into wall tile" severity failure;

    btnc <= '1';
    wait for 110 ns;
    btnc <= '0';
    wait for 250 ns;

    assert muzzle_flash = '1' or muzzle_flash = '0' report "Muzzle flash unknown" severity failure;
    assert bullet_active = '1' or bullet_active = '0' report "Bullet activity unknown" severity failure;
    assert enemy_alive = '1' or enemy_alive = '0' report "Enemy state unknown" severity failure;

    done <= true;
    report "tb_game_state passed" severity note;
    stop;
  end process;
end architecture;
