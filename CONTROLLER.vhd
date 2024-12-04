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
    signal last_player     : STD_LOGIC_VECTOR(1 downto 0) := "01";-- '01' for 'O', '10' for 'X'
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
    -- Removed 'reseTting' and 'resetting' signals
    -- Debounce Parameters
    constant DEBOUNCE_THRESHOLD : integer := 100000; -- Adjust based on clock frequency and desired debounce time

    -- Debounce Counters
    signal btn_right_cnt  : integer := 0;
    signal btn_left_cnt   : integer := 0;
    signal btn_up_cnt     : integer := 0;
    signal btn_down_cnt   : integer := 0;
    signal btn_select_cnt : integer := 0;

    -- Debounced Button Signals
    signal btn_right_debounced  : STD_LOGIC := '0';
    signal btn_left_debounced   : STD_LOGIC := '0';
    signal btn_up_debounced     : STD_LOGIC := '0';
    signal btn_down_debounced   : STD_LOGIC := '0';
    signal btn_select_debounced : STD_LOGIC := '0';

    -- Seven-segment display signals
    constant SEG_OFF : STD_LOGIC_VECTOR(6 downto 0) := "1111111"; -- All segments off
    constant SEG_O   : STD_LOGIC_VECTOR(6 downto 0) := "0000001"; -- Segments to display 'O'
    constant SEG_X   : STD_LOGIC_VECTOR(6 downto 0) := "1001000"; -- Segments to display 'X'
    signal display_seg : STD_LOGIC_VECTOR(6 downto 0);
    signal display_an  : STD_LOGIC_VECTOR(3 downto 0);

    -- FSM States
    type state_type is (GAME, END_GAME);
    signal current_state, next_state : state_type := GAME;

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
    -- FSM State Transition
    process(clk, rst)
    begin
        if rst = '1' then
            current_state <= GAME;
        elsif rising_edge(clk) then
            current_state <= next_state;
        end if;
    end process;

    -- Main Process Handling All States
    process(clk, rst)
        variable buttons           : STD_LOGIC_VECTOR(4 downto 0);
        variable pos_index_var     : integer range 0 to 8;
        variable cur_position_var  : integer range 0 to 74;
        variable game_board_var    : game_board_type;
        variable winner_flag_var   : STD_LOGIC;
        variable game_over_var     : STD_LOGIC;
    begin
        if rst = '1' then
            -- Initialize game variables
            pos_index_sig <= 4;
            current_player <= "01";  -- Start with player 'O'
            display_seg    <= SEG_O;
            display_an     <= "1110"; -- Activate first digit (active low)
            update_disp_sig <= '1';   -- Trigger display update at reset
            -- Reset game state signals
            game_board <= (others => "00");
            winner_flag <= '0';
            move_count <= 0;
            game_over <= '0';
            -- Reset debounce counters and debounced signals
            btn_right_cnt  <= 0;
            btn_left_cnt   <= 0;
            btn_up_cnt     <= 0;
            btn_down_cnt   <= 0;
            btn_select_cnt <= 0;
            btn_right_debounced  <= '0';
            btn_left_debounced   <= '0';
            btn_up_debounced     <= '0';
            btn_down_debounced   <= '0';
            btn_select_debounced <= '0';
        elsif rising_edge(clk) then
            case current_state is
                when GAME =>
                    bram_we_sig         <= "0";       -- Default to no write
                    update_disp_sig <= '0';       -- Default to no update

                    -- Debounce Logic for btn_right
                    if btn_right_debounced = btn_right then
                        if btn_right_cnt < DEBOUNCE_THRESHOLD then
                            btn_right_cnt <= btn_right_cnt + 1;
                        end if;
                    else
                        btn_right_cnt <= 0;
                    end if;

                    if btn_right_cnt = DEBOUNCE_THRESHOLD then
                        btn_right_debounced <= btn_right;
                    end if;

                    -- Debounce Logic for btn_left
                    if btn_left_debounced = btn_left then
                        if btn_left_cnt < DEBOUNCE_THRESHOLD then
                            btn_left_cnt <= btn_left_cnt + 1;
                        end if;
                    else
                        btn_left_cnt <= 0;
                    end if;

                    if btn_left_cnt = DEBOUNCE_THRESHOLD then
                        btn_left_debounced <= btn_left;
                    end if;

                    -- Debounce Logic for btn_up
                    if btn_up_debounced = btn_up then
                        if btn_up_cnt < DEBOUNCE_THRESHOLD then
                            btn_up_cnt <= btn_up_cnt + 1;
                        end if;
                    else
                        btn_up_cnt <= 0;
                    end if;

                    if btn_up_cnt = DEBOUNCE_THRESHOLD then
                        btn_up_debounced <= btn_up;
                    end if;

                    -- Debounce Logic for btn_down
                    if btn_down_debounced = btn_down then
                        if btn_down_cnt < DEBOUNCE_THRESHOLD then
                            btn_down_cnt <= btn_down_cnt + 1;
                        end if;
                    else
                        btn_down_cnt <= 0;
                    end if;

                    if btn_down_cnt = DEBOUNCE_THRESHOLD then
                        btn_down_debounced <= btn_down;
                    end if;

                    -- Debounce Logic for btn_select
                    if btn_select_debounced = btn_select then
                        if btn_select_cnt < DEBOUNCE_THRESHOLD then
                            btn_select_cnt <= btn_select_cnt + 1;
                        end if;
                    else
                        btn_select_cnt <= 0;
                    end if;

                    if btn_select_cnt = DEBOUNCE_THRESHOLD then
                        btn_select_debounced <= btn_select;
                    end if;

                    -- Edge detection for debounced buttons
                    buttons := (btn_right_debounced and not btn_right_prev) &
                               (btn_left_debounced  and not btn_left_prev)  &
                               (btn_up_debounced    and not btn_up_prev)    &
                               (btn_down_debounced  and not btn_down_prev)  &
                               (btn_select_debounced and not btn_select_prev);

                    -- Update previous button states
                    btn_select_prev <= btn_select_debounced;
                    btn_right_prev  <= btn_right_debounced;
                    btn_left_prev   <= btn_left_debounced;
                    btn_up_prev     <= btn_up_debounced;
                    btn_down_prev   <= btn_down_debounced;

                    -- Initialize variables with current signal values
                    pos_index_var := pos_index_sig;
                    game_board_var := game_board; -- Copy signal to variable
                    winner_flag_var := winner_flag;
                    game_over_var := game_over;

                    -- Handle Button Presses
                    if buttons = "00001" then -- btn_select pressed
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
                            --if move_count > 4 then  -- Minimum moves needed for a win is 5
                             winner_flag_var := check_winner(game_board_var);
                            --end if;

                            if winner_flag_var = '1' then
                                game_over_var := '1';
                                -- Update SSD to display winning player across all digits
                                if current_player = "01" then
                                    display_seg <= SEG_O; -- Display 'O' won
                                else
                                    display_seg <= SEG_X; -- Display 'X' won
                                end if;
                                display_an <= "0000"; -- Activate all digits (active low)
                                update_disp_sig <= '1'; -- Trigger display update
                                next_state <= END_GAME;
                            elsif move_count = 8 then
                                game_over_var := '1';
                                -- Display 'Draw' on SSD
                                display_seg <= SEG_OFF; -- All segments off (you can define a specific pattern for 'Draw' if desired)
                                display_an <= "1111";    -- All digits off
                                update_disp_sig <= '1'; -- Trigger display update
                                next_state <= END_GAME;
                            else
                                -- Toggle player
                                if current_player = "01" then
                                    current_player <= "10"; -- Switch to 'X'
                                    display_seg <= SEG_X;
                                else
                                    current_player <= "01"; -- Switch to 'O'
                                    display_seg <= SEG_O;
                                end if;
                                update_disp_sig <= '1'; -- Trigger display update
                            end if;

                            -- Reset position to center after move
                            pos_index_var := 4;  -- Reset to center position
                            pos_index_sig <= pos_index_var;
                            game_board   <= game_board_var;     -- Update game board
                            winner_flag  <= winner_flag_var;
                            game_over    <= game_over_var;
                        end if;
                    elsif buttons /= "00000" then
                        -- Handle Movement Buttons
                        case buttons is
                            when "10000" =>  -- btn_right pressed
                                if (pos_index_var mod 3) < 2 then
                                    pos_index_var := pos_index_var + 1;
                                    pos_index_sig <= pos_index_var;
                                end if;
                            when "01000" =>  -- btn_left pressed
                                if (pos_index_var mod 3) > 0 then
                                    pos_index_var := pos_index_var - 1;
                                    pos_index_sig <= pos_index_var;
                                end if;
                            when "00100" =>  -- btn_up pressed
                                if pos_index_var >= 3 then
                                    pos_index_var := pos_index_var - 3;
                                    pos_index_sig <= pos_index_var;
                                end if;
                            when "00010" =>  -- btn_down pressed
                                if pos_index_var <= 5 then
                                    pos_index_var := pos_index_var + 3;
                                    pos_index_sig <= pos_index_var;
                                end if;
                            when others =>
                                -- No valid single button pressed
                                null;
                        end case;
                    end if;

                    -- Update game state signals
                    game_board   <= game_board_var;     -- Update game board
                    winner_flag  <= winner_flag_var;
                    game_over    <= game_over_var;

                when END_GAME =>
                    -- In END_GAME state, maintain the winning display until reset
                    -- No further actions; waiting for external reset
                    null;

                when others =>
                    null;
               end case;
           end if;
        end process;


        -- Output Assignments
        bram_we        <= bram_we_sig;
        update_display <= update_disp_sig;
        bram_addr      <= bram_addr_sig;
        bram_din       <= bram_din_sig;

        -- Seven-Segment Display Outputs
        cat_s <= display_seg;
        an_s  <= display_an;

end Behavioral;
