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
        an_s          : out STD_LOGIC_VECTOR (3 downto 0); 
        cat_s         : out STD_LOGIC_VECTOR (6 downto 0) 
    );
end Controller;

architecture Behavioral of Controller is
    -- Corrected Position mapping
    type pos_map_type is array(0 to 8) of integer;
    constant pos_map : pos_map_type := (2, 6, 10, 32, 36, 40, 62, 66, 70);

    -- Game state tracking
    type game_board_type is array(0 to 8) of STD_LOGIC_VECTOR(1 downto 0);
    signal game_board      : game_board_type := (others => "00"); -- '00' for empty, '01' for 'O', '10' for 'X'
    signal winner_flag     : STD_LOGIC := '0';                    -- '0' for no winner, '1' for winner
    signal current_player  : STD_LOGIC_VECTOR(1 downto 0) := "01";-- '01' for 'O', '10' for 'X'
    signal move_count      : INTEGER range 0 to 9 := 0;           -- Counts the number of moves made
    signal game_over       : STD_LOGIC := '0';                    -- '1' when game is over

    signal bram_we_sig     : STD_LOGIC_VECTOR(0 downto 0) := "0";
    signal update_disp_sig : STD_LOGIC := '0';
    signal bram_addr_sig   : STD_LOGIC_VECTOR(6 downto 0) := (others => '0');
    signal bram_din_sig    : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal pos_index_sig   : integer range 0 to 8 := 4;           -- Start at index 4 (center position)
    signal btn_select_prev : STD_LOGIC := '0';                    -- For edge detection
    signal btn_right_prev  : STD_LOGIC := '0';
    signal btn_left_prev   : STD_LOGIC := '0';
    signal btn_up_prev     : STD_LOGIC := '0';
    signal btn_down_prev   : STD_LOGIC := '0';

    -- Seven-segment display signals
    constant SEG_OFF : STD_LOGIC_VECTOR(6 downto 0) := "1111111"; -- All segments off
    constant SEG_O   : STD_LOGIC_VECTOR(6 downto 0) := "0000001"; -- Segments to display 'O'
    constant SEG_X   : STD_LOGIC_VECTOR(6 downto 0) := "1001000"; -- Segments to display 'X'
    signal display_seg : STD_LOGIC_VECTOR(6 downto 0);
    signal display_an  : STD_LOGIC_VECTOR(3 downto 0);

    -- Declare integer_array and combo_type types
    type integer_array is array (0 to 2) of integer;
    type combo_type is array (0 to 7) of integer_array;

    -- Function to check for a winner
    function check_winner(board : game_board_type) return STD_LOGIC is
        constant winning_combos : combo_type := (
            (0, 1, 2), -- Row 1
            (3, 4, 5), -- Row 2
            (6, 7, 8), -- Row 3
            (0, 3, 6), -- Column 1
            (1, 4, 7), -- Column 2
            (2, 5, 8), -- Column 3
            (0, 4, 8), -- Diagonal 1
            (2, 4, 6)  -- Diagonal 2
        );
        variable win : STD_LOGIC := '0';
    begin
        for i in 0 to 7 loop
            if board(winning_combos(i)(0)) = board(winning_combos(i)(1)) and
               board(winning_combos(i)(1)) = board(winning_combos(i)(2)) and
               board(winning_combos(i)(0)) /= "00" then
                win := '1';
            end if;
        end loop;
        return win;
    end function;

begin
    process(clk, rst)
        variable buttons           : STD_LOGIC_VECTOR(4 downto 0);
        variable pos_index_var     : integer range 0 to 8;
        variable cur_position_var  : integer range 0 to 74;
        variable game_board_var    : game_board_type;
        variable winner_flag_var   : STD_LOGIC;
        variable game_over_var     : STD_LOGIC;
    begin
        if rst = '1' then
            -- Initialization on reset
            pos_index_sig <= 4;
            current_player <= "01";  -- Start with player 'O'
            bram_we_sig <= "0";
            update_disp_sig <= '1';  -- Trigger display update at reset
            btn_select_prev <= '0';
            btn_right_prev <= '0';
            btn_left_prev <= '0';
            btn_up_prev <= '0';
            btn_down_prev <= '0';
            game_board <= (others => "00");
            winner_flag <= '0';
            move_count <= 0;
            game_over <= '0';
            winner_flag_var := '0';
            game_over_var := '0';
            -- Initialize SSD display to player 'O'
            display_seg <= SEG_O;
            display_an  <= "1110"; -- Activate first digit (active low)
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
            game_board_var := game_board; -- Copy signal to variable
            winner_flag_var := winner_flag;
            game_over_var := game_over;

            -- Combine button inputs into a single std_logic_vector
            buttons := (btn_right and not btn_right_prev) &
                       (btn_left and not btn_left_prev) &
                       (btn_up and not btn_up_prev) &
                       (btn_down and not btn_down_prev) &
                       (btn_select and not btn_select_prev);

            if game_over_var = '0' then
                -- Game is ongoing
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
                        -- Check if the cell is empty
                        if game_board_var(pos_index_var) = "00" then
                            -- Write player's symbol to BRAM at cur_position_var
                            bram_we_sig <= "1";
                            bram_addr_sig <= std_logic_vector(to_unsigned(cur_position_var, 7));
                            if current_player = "01" then
                                bram_din_sig <= x"4F"; -- ASCII 'O'
                                game_board_var(pos_index_var) := "01";
                            else
                                bram_din_sig <= x"58"; -- ASCII 'X'
                                game_board_var(pos_index_var) := "10";
                            end if;

                            -- Increment move count
                            move_count <= move_count + 1;

                            -- Check for winner
                            if move_count >= 5 then  -- Minimum moves needed for a win is 5
                                winner_flag_var := check_winner(game_board_var);
                            end if;

                            if winner_flag_var = '1' then
                                game_over_var := '1';
                                -- Update SSD to display winner
                                if current_player = "01" then
                                    display_seg <= SEG_O; -- Display 'O' won
                                else
                                    display_seg <= SEG_X; -- Display 'X' won
                                end if;
                                display_an <= "1110"; -- Activate first digit
                            elsif move_count = 9 then
                                game_over_var := '1';
                                -- Display 'Draw' on SSD (if possible), otherwise turn off segments
                                display_seg <= SEG_OFF; -- All segments off
                                display_an <= "1111";    -- All digits off
                            else
                                -- Toggle player
                                if current_player = "01" then
                                    current_player <= "10"; -- Switch to 'X'
                                    display_seg <= SEG_X;
                                else
                                    current_player <= "01"; -- Switch to 'O'
                                    display_seg <= SEG_O;
                                end if;
                            end if;

                            -- Reset position
                            pos_index_var := 4;  -- Reset to center position

                            -- Trigger display update
                            update_disp_sig <= '1';
                        end if;
                    when others =>
                        -- No button pressed or multiple buttons pressed
                        null;
                end case;
            else
                -- Game is over
                -- Optionally, you can add logic to reset the game if a button is pressed
                null;
            end if;

            -- Update signals with variables
            pos_index_sig <= pos_index_var;
            game_board <= game_board_var;       -- Update signal
            winner_flag <= winner_flag_var;
            game_over <= game_over_var;

        end if;
    end process;

    -- Output assignments
    bram_we        <= bram_we_sig;
    update_display <= update_disp_sig;
    bram_addr      <= bram_addr_sig;
    bram_din       <= bram_din_sig;

    -- SSD Outputs
    cat_s <= display_seg;
    an_s  <= display_an;

end Behavioral;
