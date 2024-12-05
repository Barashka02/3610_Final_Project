library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity TOP is
    Port (
        clk         : in  STD_LOGIC;
        rst         : in  STD_LOGIC;
        btn_right   : in  STD_LOGIC;
        btn_left    : in  STD_LOGIC;
        btn_up      : in  STD_LOGIC;
        btn_down    : in  STD_LOGIC;
        btn_select  : in  STD_LOGIC;
        sdata_out   : out STD_LOGIC;
        an          : out STD_LOGIC_VECTOR (3 downto 0);
        cat         : out STD_LOGIC_VECTOR (6 downto 0);
        freq        : out STD_LOGIC;
        gain        : out STD_LOGIC;
        shutdown    : out STD_LOGIC
    );
end TOP;

architecture Behavioral of TOP is
    -- Component Declarations
    component Controller is
        Port (
            clk                   : in  STD_LOGIC;
            rst                   : in  STD_LOGIC;
            btn_right             : in  STD_LOGIC;
            btn_left              : in  STD_LOGIC;
            btn_up                : in  STD_LOGIC;
            btn_down              : in  STD_LOGIC;
            btn_select            : in  STD_LOGIC;
            bram_addr             : out STD_LOGIC_VECTOR(6 downto 0);
            bram_din              : out STD_LOGIC_VECTOR(7 downto 0);
            bram_we               : out STD_LOGIC_VECTOR(0 downto 0);
            update_display        : out STD_LOGIC;
            an_s                  : out STD_LOGIC_VECTOR (3 downto 0); 
            cat_s                 : out STD_LOGIC_VECTOR (6 downto 0);
            play_move_music       : out STD_LOGIC; -- Trigger to play move music
            play_game_over_melody : out STD_LOGIC  -- Trigger to play game over melody
        );
    end component;

    component SimpleBoardDisplay is
        Port (
            clk          : in  STD_LOGIC;
            reset        : in  STD_LOGIC;
            bram_dout    : in  STD_LOGIC_VECTOR(7 downto 0);
            bram_addr    : out STD_LOGIC_VECTOR(6 downto 0);
            uart_data    : out STD_LOGIC_VECTOR(7 downto 0);
            uart_load    : out STD_LOGIC;
            busy         : in  STD_LOGIC;
            update       : in  STD_LOGIC
        );
    end component;

    component UART_TX is
        Port (
            clk_s   : in  STD_LOGIC;
            pdata_s : in  STD_LOGIC_VECTOR(7 downto 0);
            load_s  : in  STD_LOGIC;
            busy_s  : out STD_LOGIC;
            done_s  : out STD_LOGIC;
            sdata_s : out STD_LOGIC
        );
    end component;

    component blk_mem_gen_1 is
        Port (
            clka  : in  STD_LOGIC;
            ena   : in  STD_LOGIC;
            wea   : in  STD_LOGIC_VECTOR(0 downto 0);
            addra : in  STD_LOGIC_VECTOR(6 downto 0);
            dina  : in  STD_LOGIC_VECTOR(7 downto 0);
            douta : out STD_LOGIC_VECTOR(7 downto 0)
        );
    end component;

    component MusicPlayer is
        Port (
            clk                  : in  STD_LOGIC;
            rst                  : in  STD_LOGIC;
            play_move_music      : in  STD_LOGIC;
            play_game_over_melody : in  STD_LOGIC;
            freq                 : out STD_LOGIC;
            gain                 : out STD_LOGIC;
            shutdown             : out STD_LOGIC
        );
    end component;

    -- Signals for interconnections
    signal uart_data       : STD_LOGIC_VECTOR(7 downto 0);
    signal uart_load       : STD_LOGIC;
    signal uart_busy       : STD_LOGIC;
    signal bram_dout       : STD_LOGIC_VECTOR(7 downto 0);
    signal bram_addr_ctrl  : STD_LOGIC_VECTOR(6 downto 0);
    signal bram_addr_disp  : STD_LOGIC_VECTOR(6 downto 0);
    signal bram_addr_mux   : STD_LOGIC_VECTOR(6 downto 0);
    signal bram_din        : STD_LOGIC_VECTOR(7 downto 0);
    signal bram_we         : STD_LOGIC_VECTOR(0 downto 0);
    signal update_display  : STD_LOGIC;
    signal play_move_music_sig       : STD_LOGIC;
    signal play_game_over_melody_sig : STD_LOGIC;

begin
    -- Instantiate the Controller
Controller_inst: Controller
    Port Map (
        clk                   => clk,
        rst                   => rst,
        btn_right             => btn_right,
        btn_left              => btn_left,
        btn_up                => btn_up,
        btn_down              => btn_down,
        btn_select            => btn_select,
        bram_addr             => bram_addr_ctrl,
        bram_din              => bram_din,
        bram_we               => bram_we,
        update_display        => update_display,
        an_s                  => an,
        cat_s                 => cat,
        play_move_music       => play_move_music_sig,        -- Ensure this is connected
        play_game_over_melody => play_game_over_melody_sig   -- Ensure this is connected
    );

    -- Instantiate the SimpleBoardDisplay
    DisplayFSM: SimpleBoardDisplay
        Port Map (
            clk          => clk,
            reset        => rst,
            bram_dout    => bram_dout,
            bram_addr    => bram_addr_disp,
            uart_data    => uart_data,
            uart_load    => uart_load,
            busy         => uart_busy,
            update       => update_display
        );

    -- Instantiate the UART Transmitter
    UART_Transmitter: UART_TX
        Port Map (
            clk_s   => clk,
            pdata_s => uart_data,
            load_s  => uart_load,
            busy_s  => uart_busy,
            done_s  => open, -- Not used
            sdata_s => sdata_out
        );

    -- Instantiate the BRAM
    BRAM: blk_mem_gen_1
        Port Map (
            clka  => clk,
            ena   => '1',
            wea   => bram_we,
            addra => bram_addr_mux,
            dina  => bram_din,
            douta => bram_dout
        );

    -- Instantiate the MusicPlayer
    MusicPlayer_inst: MusicPlayer
        Port Map (
            clk                  => clk,
            rst                  => rst,
            play_move_music      => play_move_music_sig,
            play_game_over_melody => play_game_over_melody_sig,
            freq                 => freq,
            gain                 => gain,
            shutdown             => shutdown
        );

    -- BRAM address multiplexing
    bram_addr_mux <= bram_addr_ctrl when bram_we = "1" else bram_addr_disp;

end Behavioral;
