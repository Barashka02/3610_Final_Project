library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Entity declaration for UART_TX
entity UART_TX is
    Port (
        clk_s : in STD_LOGIC; -- Clock input
        pdata_s : in STD_LOGIC_VECTOR(7 downto 0); -- Parallel data input (8 bits)
        
        load_s : in STD_LOGIC; -- Load signal (active high)
        busy_s : out STD_LOGIC; -- Busy signal (active while transmitting)
        done_s : out STD_LOGIC; -- Done signal (active after transmission)
        sdata_s : out STD_LOGIC -- Serial data output
    );
end UART_TX;

-- Behavioral architecture for the UART_TX
architecture Behavioral of UART_TX is
    -- Enumeration for the transmitter's FSM states
    type STATE_TYPE is (IDLE, WAIT_BAUD, SEND);
    signal cur_state : STATE_TYPE := IDLE; -- Current state of the FSM
    signal count : integer range 0 to 10417 := 0; -- Baud rate counter
    signal bit_count : integer range 0 to 9 := 0; -- Counter for transmitted bits
    signal data_ready : std_logic := '0'; -- Signal to track when data is loaded

    -- Constant for one full baud period at 9600 baud, assuming 100 MHz clock
    constant FULL_BAUD : integer := 10417;
begin
    -- Main process for handling the transmission
    process (clk_s)
    begin
        if rising_edge(clk_s) then -- Check for rising clock edge
            case cur_state is
                -- IDLE state: Wait for a load signal and then start transmission
                when IDLE =>
                    busy_s <= '0'; -- Clear busy signal when idle
                    done_s <= '0'; -- Clear done signal
                    sdata_s <= '1'; -- Output idle state (stop bit level)
                    count <= 0; -- Reset baud counter
                    -- Check if load signal is high and data is not already loaded
                    if load_s = '1' and data_ready = '0' then
                        busy_s <= '1'; -- Set busy signal
                        sdata_s <= '0'; -- Send start bit (low)
                        bit_count <= 0; -- Reset bit counter
                        data_ready <= '1'; -- Mark data as loaded
                        cur_state <= WAIT_BAUD; -- Move to WAIT_BAUD state
                    end if;

                -- WAIT_BAUD state: Wait for one full baud period before moving to SEND state
                when WAIT_BAUD =>
                    if count = FULL_BAUD and bit_count < 9 then
                        cur_state <= SEND; -- Move to SEND state after one baud period
                        count <= 0; -- Reset baud counter
                    elsif count = FULL_BAUD and bit_count = 9 then
                        bit_count <= 0; -- Reset bit counter after transmission is complete
                        data_ready <= '0'; -- Clear data_ready signal (ready for new data)
                        cur_state <= IDLE; -- Go back to IDLE state
                        count <= 0; -- Reset baud counter
                    else
                        count <= count + 1; -- Increment baud counter
                    end if;

                -- SEND state: Transmit 8 bits of data and stop bit
                when SEND =>
                    if bit_count < 8 then
                        sdata_s <= pdata_s(bit_count); -- Transmit one data bit
                        bit_count <= bit_count + 1; -- Increment bit counter
                        cur_state <= WAIT_BAUD; -- Return to WAIT_BAUD to wait for next bit
                    elsif bit_count = 8 then
                        sdata_s <= '1'; -- Transmit stop bit (high)
                        bit_count <= bit_count + 1; -- Move to next bit
                        done_s <= '1'; -- Set done signal to indicate end of transmission
                        cur_state <= WAIT_BAUD; -- Return to WAIT_BAUD
                    end if;
            end case; -- End of FSM case statement
        end if; -- End of rising_edge(clk_s) condition
    end process; -- End of main process
end Behavioral;
