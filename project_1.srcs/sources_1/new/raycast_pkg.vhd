library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package raycast_pkg is
  constant FP_SHIFT : integer := 8;
  constant FP_ONE   : integer := 2 ** FP_SHIFT;
  constant TILE_SHIFT : integer := 8;
  constant TILE_SIZE_FP : integer := 2 ** TILE_SHIFT;
  constant MAP_W : integer := 24;
  constant MAP_H : integer := 24;

  subtype heading_t is integer range 0 to 15;

  function wrap_heading(v : integer) return heading_t;
  function dir_x(idx : heading_t) return integer;
  function dir_y(idx : heading_t) return integer;
  function map_is_wall(tile_x : integer; tile_y : integer) return boolean;
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
    if v < 0 then
      r := v + 16;
    elsif v > 15 then
      r := v - 16;
    else
      r := v;
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

    -- De_cache-inspired flat layout (stylized for low-resource FPGA logic)
    -- Mid warehouse block with four doorway cuts.
    if (tile_x >= 9) and (tile_x <= 14) and (tile_y >= 9) and (tile_y <= 14) and
       not (((tile_x = 11) or (tile_x = 12)) and (tile_y = 9)) and
       not (((tile_x = 11) or (tile_x = 12)) and (tile_y = 14)) and
       not (((tile_y = 11) or (tile_y = 12)) and (tile_x = 9)) and
       not (((tile_y = 11) or (tile_y = 12)) and (tile_x = 14)) then
      return true;

    -- A site (upper-right): heavy cover and lane split.
    elsif (tile_x >= 18) and (tile_x <= 22) and (tile_y >= 2) and (tile_y <= 4) then
      return true;
    elsif (tile_x >= 19) and (tile_x <= 21) and (tile_y = 7) then
      return true;
    elsif (tile_x = 17) and (tile_y >= 3) and (tile_y <= 9) and not (tile_y = 6) then
      return true;

    -- B site (lower-right): back wall with checker cover.
    elsif (tile_x >= 18) and (tile_x <= 22) and (tile_y >= 18) and (tile_y <= 21) then
      return true;
    elsif (tile_x >= 16) and (tile_x <= 20) and (tile_y = 16) and not ((tile_x = 18) or (tile_x = 19)) then
      return true;

    -- Mid connectors and choke walls.
    elsif (tile_x = 7) and (tile_y >= 4) and (tile_y <= 18) and
          not ((tile_y >= 10) and (tile_y <= 12)) then
      return true;
    elsif (tile_y = 6) and (tile_x >= 4) and (tile_x <= 16) and
          not ((tile_x >= 10) and (tile_x <= 12)) then
      return true;
    elsif (tile_y = 17) and (tile_x >= 5) and (tile_x <= 16) and
          not ((tile_x >= 8) and (tile_x <= 10)) then
      return true;

    -- T-side obstacles (lower-left) to prove map structure on minimap.
    elsif (tile_x >= 2) and (tile_x <= 4) and (tile_y >= 19) and (tile_y <= 21) then
      return true;
    elsif (tile_x = 5) and (tile_y >= 15) and (tile_y <= 18) then
      return true;
    elsif (tile_x >= 2) and (tile_x <= 6) and (tile_y = 14) and not (tile_x = 4) then
      return true;
    else
      return false;
    end if;
  end function;
end package body;
