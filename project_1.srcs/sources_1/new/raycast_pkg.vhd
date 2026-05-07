library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package raycast_pkg is
  constant FP_SHIFT : integer := 8;
  constant FP_ONE   : integer := 2 ** FP_SHIFT;
  constant TILE_SHIFT : integer := 8;
  constant TILE_SIZE_FP : integer := 2 ** TILE_SHIFT;
  constant MAP_W : integer := 16;
  constant MAP_H : integer := 16;

  subtype heading_t is integer range 0 to 15;

  function wrap_heading(v : integer) return heading_t;
  function dir_x(idx : heading_t) return integer;
  function dir_y(idx : heading_t) return integer;
  function map_is_wall(tile_x : integer; tile_y : integer) return boolean;
  function cast_ray_distance_fp(
    player_x_fp : integer;
    player_y_fp : integer;
    heading_idx : heading_t;
    column_idx  : integer;
    screen_w    : integer) return integer;
end package;

package body raycast_pkg is
  type int_arr16_t is array (0 to 15) of integer;
  constant DIR_X_LUT : int_arr16_t := (
    256, 237, 181, 98, 0, -98, -181, -237,
    -256, -237, -181, -98, 0, 98, 181, 237
  );
  constant DIR_Y_LUT : int_arr16_t := (
    0, 98, 181, 237, 256, 237, 181, 98,
    0, -98, -181, -237, -256, -237, -181, -98
  );

  function wrap_heading(v : integer) return heading_t is
    variable r : integer;
  begin
    r := v mod 16;
    if r < 0 then
      r := r + 16;
    end if;
    return heading_t(r);
  end function;

  function dir_x(idx : heading_t) return integer is
  begin
    return DIR_X_LUT(idx);
  end function;

  function dir_y(idx : heading_t) return integer is
  begin
    return DIR_Y_LUT(idx);
  end function;

  function map_is_wall(tile_x : integer; tile_y : integer) return boolean is
  begin
    if (tile_x < 0) or (tile_y < 0) or (tile_x >= MAP_W) or (tile_y >= MAP_H) then
      return true;
    end if;

    if (tile_x = 0) or (tile_y = 0) or (tile_x = MAP_W - 1) or (tile_y = MAP_H - 1) then
      return true;
    end if;

    if (tile_x = 8) and (tile_y > 2) and (tile_y < 13) then
      return true;
    elsif (tile_y = 8) and (tile_x > 2) and (tile_x < 13) then
      return true;
    elsif (tile_x = 4) and (tile_y >= 4) and (tile_y <= 11) then
      return true;
    elsif (tile_y = 11) and (tile_x >= 4) and (tile_x <= 11) then
      return true;
    else
      return false;
    end if;
  end function;

  function cast_ray_distance_fp(
    player_x_fp : integer;
    player_y_fp : integer;
    heading_idx : heading_t;
    column_idx  : integer;
    screen_w    : integer) return integer is
    variable ray_heading : heading_t;
    variable heading_ofs : integer;
    variable step_x_fp : integer;
    variable step_y_fp : integer;
    variable dist_fp : integer;
    variable sample_x_fp : integer;
    variable sample_y_fp : integer;
    variable tile_x : integer;
    variable tile_y : integer;
  begin
    if (column_idx * 8) < (screen_w * 1) then
      heading_ofs := -3;
    elsif (column_idx * 8) < (screen_w * 2) then
      heading_ofs := -2;
    elsif (column_idx * 8) < (screen_w * 3) then
      heading_ofs := -1;
    elsif (column_idx * 8) < (screen_w * 5) then
      heading_ofs := 0;
    elsif (column_idx * 8) < (screen_w * 6) then
      heading_ofs := 1;
    elsif (column_idx * 8) < (screen_w * 7) then
      heading_ofs := 2;
    else
      heading_ofs := 3;
    end if;

    ray_heading := wrap_heading(heading_idx + heading_ofs);

    step_x_fp := (dir_x(ray_heading) * 48) / 256;
    step_y_fp := (dir_y(ray_heading) * 48) / 256;

    if (step_x_fp = 0) and (step_y_fp = 0) then
      step_x_fp := 1;
    end if;

    sample_x_fp := player_x_fp;
    sample_y_fp := player_y_fp;
    dist_fp := 0;

    for step in 1 to 48 loop
      sample_x_fp := sample_x_fp + step_x_fp;
      sample_y_fp := sample_y_fp + step_y_fp;
      dist_fp := dist_fp + 48;

      tile_x := sample_x_fp / TILE_SIZE_FP;
      tile_y := sample_y_fp / TILE_SIZE_FP;

      if map_is_wall(tile_x, tile_y) then
        return dist_fp;
      end if;
    end loop;

    return 48 * 48;
  end function;
end package body;
