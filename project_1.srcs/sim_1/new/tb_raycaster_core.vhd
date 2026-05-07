library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.env.all;

entity tb_raycaster_core is
end entity;

architecture tb of tb_raycaster_core is
  constant SCREEN_W_TB : integer := 64;
  constant SCREEN_H_TB : integer := 120;
  constant SCALE_TB : integer := 4;
  constant SAMPLE_W_TB : integer := SCREEN_W_TB / SCALE_TB;

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal start : std_logic := '0';

  signal write_en : std_logic;
  signal write_column : integer range 0 to SAMPLE_W_TB - 1;
  signal wall_top : integer range 0 to SCREEN_H_TB - 1;
  signal wall_bottom : integer range 0 to SCREEN_H_TB - 1;
  signal wall_color : std_logic_vector(11 downto 0);
  signal busy : std_logic;
  signal frame_done : std_logic;

  signal done : boolean := false;
begin
  clk <= not clk after 10 ns when not done else '0';

  dut : entity work.raycaster_core
    generic map (
      SCREEN_W => SCREEN_W_TB,
      SCREEN_H => SCREEN_H_TB,
      COLUMN_SCALE => SCALE_TB
    )
    port map (
      clk => clk,
      rst => rst,
      start => start,
      player_x_fp => 3 * 256 + 128,
      player_y_fp => 3 * 256 + 128,
      heading_idx => 0,
      write_en => write_en,
      write_column => write_column,
      wall_top => wall_top,
      wall_bottom => wall_bottom,
      wall_color => wall_color,
      busy => busy,
      frame_done => frame_done
    );

  stim : process
    variable writes_seen : integer := 0;
    variable nonzero_color_seen : boolean := false;
    variable min_top : integer := SCREEN_H_TB;
    variable max_bottom : integer := 0;
  begin
    wait for 60 ns;
    rst <= '0';

    wait until rising_edge(clk);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';

    while frame_done = '0' loop
      wait until rising_edge(clk);
      if write_en = '1' then
        writes_seen := writes_seen + 1;
        assert wall_bottom > wall_top report "Invalid wall slice bounds" severity failure;
        if wall_top < min_top then
          min_top := wall_top;
        end if;
        if wall_bottom > max_bottom then
          max_bottom := wall_bottom;
        end if;
        if wall_color /= x"000" then
          nonzero_color_seen := true;
        end if;
      end if;
    end loop;

    assert writes_seen = SAMPLE_W_TB report "Did not produce one write per sampled column" severity failure;
    assert nonzero_color_seen report "Wall color unexpectedly black" severity failure;
    assert (max_bottom - min_top) > 20 report "Wall profile variation too small" severity failure;
    assert busy = '0' report "Raycaster remained busy after frame completion" severity failure;

    done <= true;
    report "tb_raycaster_core passed" severity note;
    stop;
  end process;
end architecture;
