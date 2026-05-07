library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.env.all;
use work.raycast_pkg.ALL;

entity tb_raycaster_core is
end entity;

architecture tb of tb_raycaster_core is
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal calc_en : std_logic := '0';
  signal column_idx : integer range 0 to 639 := 0;
  signal wall_top : integer range 0 to 479;
  signal wall_bottom : integer range 0 to 479;
  signal wall_color : std_logic_vector(11 downto 0);
  signal valid : std_logic;

  signal done : boolean := false;
begin
  clk <= not clk after 10 ns when not done else '0';

  dut : entity work.raycaster_core
    port map (
      clk => clk,
      rst => rst,
      calc_en => calc_en,
      column_idx => column_idx,
      player_x_fp => (3 * TILE_SIZE_FP) + (TILE_SIZE_FP / 2),
      player_y_fp => (3 * TILE_SIZE_FP) + (TILE_SIZE_FP / 2),
      heading_idx => 0,
      wall_top => wall_top,
      wall_bottom => wall_bottom,
      wall_color => wall_color,
      valid => valid
    );

  stim : process
    variable d_center, d_left, d_right : integer;
  begin
    wait for 60 ns;
    rst <= '0';

    d_left := cast_ray_distance_fp((3 * TILE_SIZE_FP) + (TILE_SIZE_FP / 2), (3 * TILE_SIZE_FP) + (TILE_SIZE_FP / 2), 0, 64, 640);
    d_center := cast_ray_distance_fp((3 * TILE_SIZE_FP) + (TILE_SIZE_FP / 2), (3 * TILE_SIZE_FP) + (TILE_SIZE_FP / 2), 0, 320, 640);
    d_right := cast_ray_distance_fp((3 * TILE_SIZE_FP) + (TILE_SIZE_FP / 2), (3 * TILE_SIZE_FP) + (TILE_SIZE_FP / 2), 0, 576, 640);

    assert d_center > 0 report "Center ray did not hit" severity failure;
    assert d_left > 0 and d_right > 0 report "Side rays did not hit" severity failure;

    column_idx <= 320;
    calc_en <= '1';
    wait until rising_edge(clk);
    calc_en <= '0';

    wait until rising_edge(clk);
    assert valid = '1' report "Raycaster did not assert valid" severity failure;
    assert wall_bottom > wall_top report "Invalid wall slice bounds" severity failure;
    assert wall_color /= x"000" report "Wall color unexpectedly black" severity failure;

    done <= true;
    report "tb_raycaster_core passed" severity note;
    stop;
  end process;
end architecture;
