library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity MusicPlayer is
    Port (
        clk                  : in  STD_LOGIC;
        rst                  : in  STD_LOGIC;
        play_move_music      : in  STD_LOGIC; -- Pulse to play move music (Beep)
        play_game_over_melody: in  STD_LOGIC; -- Pulse to play game over melody (C C C G C G)
        freq                 : out STD_LOGIC;
        gain                 : out STD_LOGIC;
        shutdown             : out STD_LOGIC
    );
end MusicPlayer;

architecture Behavioral of MusicPlayer is
    -- Frequency divider constants for 100MHz clock
    constant C4_DIV : integer := 191109; -- ~262 Hz
    constant F4_DIV : integer := 143172; -- ~349 Hz
    constant G4_DIV : integer := 127551; -- ~392 Hz

    -- Melody step duration (0.2 sec at 100MHz)
    constant MELODY_STEP_MAX : integer := 20000000; -- 0.2 sec at 100MHz

    -- Move music duration (0.5 sec at 100MHz)
    constant MOVE_MUSIC_MAX : integer := 50000000; -- 0.5 sec at 100MHz

    -- Define state types
    type state_type is (IDLE, PLAY_MOVE, PLAY_MOVE_WAIT, PLAY_GAME_OVER_PLAYING, PLAY_GAME_OVER_WAIT);
    signal current_state, next_state : state_type := IDLE;

    -- Melody sequence
    type melody_type is array (0 to 5) of integer;
    constant game_over_melody : melody_type := (
        C4_DIV, -- C
        C4_DIV, -- C
        C4_DIV, -- C
        G4_DIV, -- G
        C4_DIV, -- C
        G4_DIV  -- G
    );
    signal melody_step : integer range 0 to 5 := 0;
    signal melody_counter : integer := 0;

    -- Move music counter
    signal move_music_counter : integer := 0;

    -- Frequency generation
    signal freq_counter : integer := 0;
    signal freq_reg     : STD_LOGIC := '0';
    signal current_div  : integer := 0; -- Current frequency divider

    -- Toggle flag to alternate between C4 and F4
    signal toggle_flag : STD_LOGIC := '0';
begin
    -- State Transition Process
    process(clk, rst)
    begin
        if rst = '1' then
            current_state <= IDLE;
        elsif rising_edge(clk) then
            current_state <= next_state;
        end if;
    end process;

    -- Next State Logic
    process(current_state, play_move_music, play_game_over_melody, melody_step, melody_counter, move_music_counter)
    begin
        next_state <= current_state; -- Default to hold state
        case current_state is
            when IDLE =>
                if play_game_over_melody = '1' then
                    next_state <= PLAY_GAME_OVER_PLAYING;
                elsif play_move_music = '1' then
                    next_state <= PLAY_MOVE;
                else
                    next_state <= IDLE;
                end if;

            when PLAY_MOVE =>
                -- Initialize move beep and toggle frequency
                next_state <= PLAY_MOVE_WAIT;

            when PLAY_MOVE_WAIT =>
                if move_music_counter < MOVE_MUSIC_MAX then
                    next_state <= PLAY_MOVE_WAIT;
                else
                    next_state <= IDLE;
                end if;

            when PLAY_GAME_OVER_PLAYING =>
                if melody_step < 6 then
                    next_state <= PLAY_GAME_OVER_WAIT;
                else
                    next_state <= IDLE;
                end if;

            when PLAY_GAME_OVER_WAIT =>
                if melody_counter < MELODY_STEP_MAX then
                    next_state <= PLAY_GAME_OVER_WAIT;
                else
                    if melody_step < 5 then
                        next_state <= PLAY_GAME_OVER_PLAYING;
                    else
                        next_state <= IDLE;
                    end if;
                end if;

            when others =>
                next_state <= IDLE;
        end case;
    end process;

    -- Output and Music Control Logic
    process(clk, rst)
    begin
        if rst = '1' then
            freq_reg <= '0';
            freq_counter <= 0;
            current_div <= 0;
            melody_step <= 0;
            melody_counter <= 0;
            move_music_counter <= 0;
            toggle_flag <= '0';
        elsif rising_edge(clk) then
            case current_state is
                when IDLE =>
                    if play_move_music = '1' then
                        -- Toggle between F4 and C4 for move beep
                        if toggle_flag = '0' then
                            current_div <= F4_DIV;
                        else
                            current_div <= C4_DIV;
                        end if;
                        toggle_flag <= not toggle_flag;
                        freq_reg <= '0';
                        move_music_counter <= 0;
                    elsif play_game_over_melody = '1' then
                        -- Initialize game over melody
                        melody_step <= 0;
                        current_div <= game_over_melody(melody_step);
                        melody_counter <= 0;
                    end if;

                when PLAY_MOVE =>
                    -- No additional actions needed; handled in PLAY_MOVE_WAIT

                when PLAY_MOVE_WAIT =>
                    -- Play beep by toggling freq_reg at current_div frequency
                    if current_div /= 0 then
                        if freq_counter < current_div then
                            freq_counter <= freq_counter + 1;
                        else
                            freq_reg <= not freq_reg;
                            freq_counter <= 0;
                        end if;
                    else
                        freq_reg <= '0';
                    end if;

                    -- Increment move music counter
                    if move_music_counter < MOVE_MUSIC_MAX then
                        move_music_counter <= move_music_counter + 1;
                    end if;

                when PLAY_GAME_OVER_PLAYING =>
                    -- Start playing the current melody step
                    if melody_step < 6 then
                        current_div <= game_over_melody(melody_step);
                        melody_counter <= 0;
                    end if;

                when PLAY_GAME_OVER_WAIT =>
                    -- Play the current melody step
                    if melody_counter < MELODY_STEP_MAX then
                        melody_counter <= melody_counter + 1;
                        -- Frequency generation
                        if current_div /= 0 then
                            if freq_counter < current_div then
                                freq_counter <= freq_counter + 1;
                            else
                                freq_reg <= not freq_reg;
                                freq_counter <= 0;
                            end if;
                        else
                            freq_reg <= '0';
                        end if;
                    else
                        melody_counter <= 0;
                        melody_step <= melody_step + 1;
                    end if;

                when others =>
                    freq_reg <= '0';
            end case;
        end if;
    end process;

    -- Assign outputs
    freq     <= freq_reg;
    gain     <= '1';       -- Set gain to maximum
    shutdown <= '1';       -- Enable the audio output
end Behavioral;
