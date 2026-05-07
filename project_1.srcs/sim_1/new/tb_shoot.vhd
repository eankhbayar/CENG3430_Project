library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.env.all;

entity tb_shoot is
end entity;

architecture tb of tb_shoot is
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal btnu, btnd, btnl, btnr, btnc : std_logic := '0';
  signal px, py : integer;
  signal heading : integer range 0 to 15;
  signal shoot_pulse, shoot_hit, muzzle_flash : std_logic;
  signal done : boolean := false;
begin
  clk <= not clk after 5 ns when not done else '0';

  dut : entity work.game_state
    generic map (
      CLK_HZ => 1000,
      TICK_HZ => 100,
      MOVE_STEP_FP => 16,
      SHOOT_COOLDOWN_TICKS => 8
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
      muzzle_flash => muzzle_flash
    );

  stim : process
    variable pulse_count : integer := 0;
  begin
    wait for 40 ns;
    rst <= '0';

    wait for 110 ns;
    btnc <= '1';
    wait for 20 ns;
    btnc <= '0';

    for i in 0 to 40 loop
      wait until rising_edge(clk);
      if shoot_pulse = '1' then
        pulse_count := pulse_count + 1;
      end if;
    end loop;

    btnc <= '1';
    wait for 20 ns;
    btnc <= '0';

    for i in 0 to 30 loop
      wait until rising_edge(clk);
      if shoot_pulse = '1' then
        pulse_count := pulse_count + 1;
      end if;
    end loop;

    assert pulse_count <= 2 report "Cooldown failed: too many shoot pulses" severity failure;
    assert muzzle_flash = '1' or muzzle_flash = '0' report "muzzle_flash unknown" severity failure;

    done <= true;
    report "tb_shoot passed" severity note;
    stop;
  end process;
end architecture;
