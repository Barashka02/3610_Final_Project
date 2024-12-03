library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity SimpleBoardDisplay is
    Port (
        clk          : in  STD_LOGIC;
        reset        : in  STD_LOGIC;
        bram_dout    : in  STD_LOGIC_VECTOR(7 downto 0);
        bram_addr    : out STD_LOGIC_VECTOR(6 downto 0);
        uart_data    : out STD_LOGIC_VECTOR(7 downto 0);
        uart_load    : out STD_LOGIC;
        busy         : in  STD_LOGIC;
        update       : in  STD_LOGIC
        -- Removed cur_position input
    );
end SimpleBoardDisplay;

architecture Behavioral of SimpleBoardDisplay is
    type STATE_TYPE is (IDLE, READ_MEMORY, SEND_UART, WAIT_UART);
    signal cur_state, next_state : STATE_TYPE := IDLE;
    signal mem_addr      : integer range 0 to 74 := 0;
    signal uart_load_sig : STD_LOGIC := '0';
    signal update_reg    : STD_LOGIC := '0';
    signal update_prev   : STD_LOGIC := '0';  -- For edge detection
begin
    -- Output assignments
    bram_addr <= std_logic_vector(to_unsigned(mem_addr, 7));
    uart_load <= uart_load_sig;
    uart_data <= bram_dout;  -- Directly output BRAM data

    -- FSM Process
    process(clk, reset)
    begin
        if reset = '1' then
            cur_state <= IDLE;
            mem_addr <= 0;
            uart_load_sig <= '0';
            update_reg <= '1';  -- Start with update_reg = '1' at reset
            update_prev <= '0';
        elsif rising_edge(clk) then
            update_prev <= update_reg;
            update_reg <= update;

            cur_state <= next_state;

            -- State actions
            case cur_state is
                when IDLE =>
                    mem_addr <= 0;
                    uart_load_sig <= '0';
                when READ_MEMORY =>
                    null; -- bram_dout is automatically read
                when SEND_UART =>
                    if busy = '0' then
                        uart_load_sig <= '1'; -- Trigger UART to send data
                    else
                        uart_load_sig <= '0';
                    end if;
                when WAIT_UART =>
                    uart_load_sig <= '0';
                    if busy = '0' then
                        if mem_addr < 74 then
                            mem_addr <= mem_addr + 1;
                        else
                            mem_addr <= 0;
                        end if;
                    end if;
                when others =>
                    null;
            end case;
        end if;
    end process;

    -- State Transition Process
    process(cur_state, mem_addr, busy, update_reg, update_prev)
    begin
        next_state <= cur_state;

        case cur_state is
            when IDLE =>
                -- Start when update signal goes from '0' to '1' (rising edge)
                if update_reg = '1' and update_prev = '0' then
                    next_state <= READ_MEMORY;
                else
                    next_state <= IDLE;
                end if;

            when READ_MEMORY =>
                next_state <= SEND_UART;

            when SEND_UART =>
                if busy = '0' then
                    next_state <= WAIT_UART;
                end if;

            when WAIT_UART =>
                if busy = '0' then
                    if mem_addr < 74 then
                        next_state <= READ_MEMORY;
                    else
                        next_state <= IDLE;  -- Return to IDLE after sending all data
                    end if;
                end if;

            when others =>
                next_state <= IDLE;
        end case;
    end process;
end Behavioral;