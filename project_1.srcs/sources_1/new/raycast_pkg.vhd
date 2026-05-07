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
    variable internal_a : integer;
    variable internal_b : integer;
  begin
    if (tile_x < 0) or (tile_y < 0) or (tile_x >= MAP_W) or (tile_y >= MAP_H) then
      return true;
    end if;

    if (tile_x = 0) or (tile_y = 0) or (tile_x = MAP_W - 1) or (tile_y = MAP_H - 1) then
      return true;
    end if;

    internal_a := (tile_x * 7 + tile_y * 3 + 5) mod 11;
    internal_b := (tile_x * 5 - tile_y * 2 + 31) mod 13;

    if (tile_x = 8) and (tile_y > 2) and (tile_y < 13) then
      return true;
    elsif (tile_y = 5) and (tile_x > 3) and (tile_x < 12) then
      return true;
    elsif (internal_a = 0) and ((tile_y mod 2) = 0) then
      return true;
    elsif (internal_b = 0) and ((tile_x mod 3) = 1) then
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
    variable base_dx : integer;
    variable base_dy : integer;
    variable ray_dx  : integer;
    variable ray_dy  : integer;
    variable cam_x   : integer;
    variable dist_fp : integer;
    variable sample_x_fp : integer;
    variable sample_y_fp : integer;
    variable tile_x : integer;
    variable tile_y : integer;
  begin
    base_dx := dir_x(heading_idx);
    base_dy := dir_y(heading_idx);

    cam_x := ((column_idx * 2 - (screen_w - 1)) * 96) / screen_w;

    ray_dx := base_dx + ((-base_dy * cam_x) / 128);
    ray_dy := base_dy + (( base_dx * cam_x) / 128);

    if (ray_dx = 0) and (ray_dy = 0) then
      ray_dx := 1;
    end if;

    for step in 1 to 128 loop
      dist_fp := step * 24;
      sample_x_fp := player_x_fp + ((ray_dx * dist_fp) / 256);
      sample_y_fp := player_y_fp + ((ray_dy * dist_fp) / 256);

      tile_x := sample_x_fp / TILE_SIZE_FP;
      tile_y := sample_y_fp / TILE_SIZE_FP;

      if map_is_wall(tile_x, tile_y) then
        return dist_fp;
      end if;
    end loop;

    return 128 * 24;
  end function;
end package body;
