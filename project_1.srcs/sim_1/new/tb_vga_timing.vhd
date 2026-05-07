library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.env.all;

entity tb_vga_timing is
end entity;

architecture tb of tb_vga_timing is
  signal clk_pix : std_logic := '0';
  signal rst : std_logic := '1';
  signal hsync, vsync, active, frame_start, line_start : std_logic;
  signal x : integer range 0 to 639;
  signal y : integer range 0 to 479;

  signal done : boolean := false;
begin
  clk_pix <= not clk_pix after 20 ns when not done else '0';

  dut : entity work.vga_timing
    port map (
      clk_pix => clk_pix,
      rst => rst,
      hsync => hsync,
      vsync => vsync,
      active => active,
      x => x,
      y => y,
      frame_start => frame_start,
      line_start => line_start
    );

  stim : process
    variable cyc : integer := 0;
    variable active_cnt : integer := 0;
    variable hsync_low : integer := 0;
    variable vsync_low : integer := 0;
  begin
    wait for 100 ns;
    rst <= '0';

    for i in 0 to (800 * 525) - 1 loop
      wait until rising_edge(clk_pix);
      cyc := cyc + 1;
      if active = '1' then
        active_cnt := active_cnt + 1;
      end if;
      if hsync = '0' then
        hsync_low := hsync_low + 1;
      end if;
      if vsync = '0' then
        vsync_low := vsync_low + 1;
      end if;
    end loop;

    assert active_cnt = 640 * 480 report "Active area mismatch" severity failure;
    assert hsync_low = 96 * 525 report "HSYNC pulse width/count mismatch" severity failure;
    assert vsync_low = 2 * 800 report "VSYNC pulse width/count mismatch" severity failure;

    done <= true;
    report "tb_vga_timing passed" severity note;
    stop;
  end process;
end architecture;
