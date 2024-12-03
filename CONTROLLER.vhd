library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Controller is
    Port (
        clk           : in  STD_LOGIC;
        rst           : in  STD_LOGIC;
        btn_right     : in  STD_LOGIC;
        btn_left      : in  STD_LOGIC;
        btn_up        : in  STD_LOGIC;
        btn_down      : in  STD_LOGIC;
        btn_select    : in  STD_LOGIC;
        bram_addr     : out STD_LOGIC_VECTOR(6 downto 0);
        bram_din      : out STD_LOGIC_VECTOR(7 downto 0);
        bram_we       : out STD_LOGIC_VECTOR(0 downto 0);
        update_display: out STD_LOGIC;
        an        : out STD_LOGIC_VECTOR (3 downto 0); 
        cat      : out STD_LOGIC_VECTOR (6 downto 0) 
        -- Removed cur_position output
    );
end Controller;

architecture Behavioral of Controller is
    -- Corrected Position mapping
    type pos_map_type is array(0 to 8) of integer;
    constant pos_map : pos_map_type := (2, 6, 10, 32, 36, 40, 62, 66, 70);

    signal player_flag     : STD_LOGIC := '0';             -- '0' for O, '1' for X
    signal bram_we_sig     : STD_LOGIC_VECTOR(0 downto 0) := "0";
    signal update_disp_sig : STD_LOGIC := '0';
    signal bram_addr_sig   : STD_LOGIC_VECTOR(6 downto 0) := (others => '0');
    signal bram_din_sig    : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal pos_index_sig   : integer range 0 to 8 := 4;    -- Start at index 4 (center position)
    signal btn_select_prev : STD_LOGIC := '0';             -- For edge detection
    signal btn_right_prev  : STD_LOGIC := '0';
    signal btn_left_prev   : STD_LOGIC := '0';
    signal btn_up_prev     : STD_LOGIC := '0';
    signal btn_down_prev   : STD_LOGIC := '0';
begin
    process(clk, rst)
        variable buttons           : STD_LOGIC_VECTOR(4 downto 0);
        variable pos_index_var     : integer range 0 to 8;
        variable cur_position_var  : integer range 0 to 74;
    begin
        if rst = '1' then
            -- Initialization on reset
            pos_index_sig <= 4;
            player_flag <= '0';
            bram_we_sig <= "0";
            update_disp_sig <= '1';  -- Trigger display update at reset
            btn_select_prev <= '0';
            btn_right_prev <= '0';
            btn_left_prev <= '0';
            btn_up_prev <= '0';
            btn_down_prev <= '0';
        elsif rising_edge(clk) then
            bram_we_sig <= "0";       -- Default to no write
            update_disp_sig <= '0';   -- Default to no update

            -- Edge detection for buttons
            btn_select_prev <= btn_select;
            btn_right_prev  <= btn_right;
            btn_left_prev   <= btn_left;
            btn_up_prev     <= btn_up;
            btn_down_prev   <= btn_down;

            -- Initialize variables with current signal values
            pos_index_var := pos_index_sig;

            -- Combine button inputs into a single std_logic_vector
            buttons := (btn_right and not btn_right_prev) &
                       (btn_left and not btn_left_prev) &
                       (btn_up and not btn_up_prev) &
                       (btn_down and not btn_down_prev) &
                       (btn_select and not btn_select_prev);

            -- Use a case statement for button logic
            case buttons is
                when "10000" =>  -- btn_right pressed
                    if (pos_index_var mod 3) < 2 then
                        pos_index_var := pos_index_var + 1;
                    end if;
                when "01000" =>  -- btn_left pressed
                    if (pos_index_var mod 3) > 0 then
                        pos_index_var := pos_index_var - 1;
                    end if;
                when "00100" =>  -- btn_up pressed
                    if pos_index_var >= 3 then
                        pos_index_var := pos_index_var - 3;
                    end if;
                when "00010" =>  -- btn_down pressed
                    if pos_index_var <= 5 then
                        pos_index_var := pos_index_var + 3;
                    end if;
                when "00001" =>  -- btn_select pressed
                    -- Compute current position
                    cur_position_var := pos_map(pos_index_var);
                    -- Write player's symbol to BRAM at cur_position_var
                    bram_we_sig <= "1";
                    bram_addr_sig <= std_logic_vector(to_unsigned(cur_position_var, 7));
                    if player_flag = '0' then
                        bram_din_sig <= x"4F"; -- ASCII 'O'
                        cat <= "1001000";
                        an <= "0000";
                    else
                        bram_din_sig <= x"58"; -- ASCII 'X'
                        cat <= "0000001";
                        an <=  "0000";
                    end if;

                    -- Toggle player
                    player_flag <= not player_flag;

                    -- Reset position
                    pos_index_var := 4;  -- Reset to center position

                    -- Trigger display update
                    update_disp_sig <= '1';
                when others =>
                    -- No button pressed or multiple buttons pressed
                    null;
            end case;

            -- Update signals with variables
            pos_index_sig <= pos_index_var;
        end if;
    end process;

    -- Output assignments
    bram_we        <= bram_we_sig;
    update_display <= update_disp_sig;
    bram_addr      <= bram_addr_sig;
    bram_din       <= bram_din_sig;
end Behavioral;
