----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 25.02.2026 12:48:22
-- Design Name: 
-- Module Name: lab05 - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_unsigned.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity lab05 is
  Port (
    clk: in std_logic;
    hsync, vsync: out std_logic;
    red, green, blue : out std_logic_vector(3 downto 0);
    BTNU, BTND, BTNL, BTNR: in std_logic
  );
end lab05;

architecture Behavioral of lab05 is
    signal clk50MHz : std_logic;
    signal clk10Hz : std_logic;
    signal hcount, vcount : integer := 0;
    
    constant H_TOTAL : integer := 1344 - 1;
    constant H_SYNC : integer := 48 - 1;
    constant H_BACK : integer := 240 - 1;
    constant H_START : integer := 48 + 240 - 1;
    constant H_ACTIVE : integer := 1024 - 1;
    constant H_END : integer := 1344 - 32 - 1;
    constant H_FRONT : integer := 32 - 1;
    
    constant V_TOTAL : integer := 625 - 1;
    constant V_SYNC : integer := 3 - 1;
    constant V_BACK : integer := 12 - 1;
    constant V_START : integer := 3 + 12 - 1;
    constant V_ACTIVE : integer := 600 - 1;
    constant V_END : integer := 625 - 10 - 1;
    constant V_FRONT : integer := 10 - 1;
    
    constant LENGTH : integer := 100;
    signal H_TOP_LEFT:integer:=(H_START+H_END)/2-LENGTH/2;
    signal V_TOP_LEFT:integer:=(V_START+V_END)/2-LENGTH/2;
    
    component clock_divider is
        generic (N : integer);
        port (
            clk : in std_logic;
            clk_out : out std_logic
        );
    end component;
begin
    comp_clk50MHz : clock_divider generic map(N => 1) port map(clk, clk50MHz);
    
    hcount_proc : process (clk50MHz)
    begin
        if (rising_edge(clk50MHz)) then
            if (hcount = H_TOTAL) then
                hcount <= 0;
            else
                hcount <= hcount + 1;
            end if;
         end if;
    end process hcount_proc;
    
    vcount_proc : process (clk50MHz)
    begin
        if (rising_edge(clk50MHz)) then
            if (hcount = H_TOTAL) then
                if (vcount = V_TOTAL) then
                    vcount <= 0;
                else
                    vcount <= vcount + 1;
                end if;
            end if;
        end if;
    end process vcount_proc;
      
    hsync_gen_proc : process (hcount)
    begin
        if (hcount < H_SYNC) then
            hsync <= '0';
        else
            hsync <= '1';
        end if;
    end process hsync_gen_proc;

    vsync_gen_proc : process (vcount)
    begin
        if (vcount < V_SYNC) then
            vsync <= '0';
        else
            vsync <= '1';
        end if;
    end process vsync_gen_proc;
    
    comp_clk10Hz : clock_divider generic map(N => 5000000) port map(clk, clk10Hz);
    moving_square: process(clk10Hz)
    begin
        if rising_edge(clk10Hz) then
            if (BTNU = '1') and (V_TOP_LEFT - 10) > V_START then
                V_TOP_LEFT <= V_TOP_LEFT-10;
            end if;
            if(BTND = '1') and (V_TOP_LEFT + LENGTH ) < V_END then
                V_TOP_LEFT <= V_TOP_LEFT + 10;
            end if;
            if(BTNL = '1') and (H_TOP_LEFT - 10) > H_START then
                H_TOP_LEFT <= H_TOP_LEFT-10;
            end if;
            if(BTNR = '1') and (H_TOP_LEFT + LENGTH + 10) < H_END then
                H_TOP_LEFT <= H_TOP_LEFT +10;
            end if;
        end if;
    end process moving_square;

    data_output_proc : process (hcount, vcount)
    begin
        if ((hcount >= H_START and
            hcount < H_END) and
            (vcount >= V_START and
            vcount < V_END))
        then
        -- Display Area
            if ((hcount >= H_TOP_LEFT and
            hcount < H_TOP_LEFT + LENGTH) and
            (vcount >= V_TOP_LEFT and
            vcount < V_TOP_LEFT + LENGTH))
            then
                red <= "1111";
                green <= "0000";
                blue <= "1111";
            else
                red <= "1111";
                green <= "1111";
                blue <= "1111";
            end if;
        else
        -- Blanking Area
            red <= "0000";
            green <= "0000";
            blue <= "0000";
        end if;
    end process data_output_proc;

end Behavioral;
