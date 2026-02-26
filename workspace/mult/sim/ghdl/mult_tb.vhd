library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb is
end entity tb;

architecture Behavioral of tb is

        -- Constants for the width of the inputs and output
    constant WIDTH_A : integer := 18;
    constant WIDTH_B : integer := 6;

    -- Signal declarations
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal ass : std_logic := '0';
    signal a   : signed(WIDTH_A-1 downto 0);
    signal b   : signed(WIDTH_B-1 downto 0);
    signal p   : signed(WIDTH_A + WIDTH_B - 1 downto 0);

begin

    -- Clock generation
    clk_process : process
    begin
        while true loop
            clk <= not clk;
            wait for 10 ns;
        end loop;
    end process clk_process;

    -- Instantiate the DUT
    DUT: entity work.mult
        generic map (
            M => WIDTH_A,
            N => WIDTH_B
        )
        port map (
            clk => clk,
            rst => rst,
            a   => a,
            b   => b,
            p   => p
        );

    -- Test process
    process
    begin
        -- Hold reset active for a few clock cycles
        rst <= '0';
        wait for 40 ns;
        rst <= '1';
        ass <= '0';

        -- Test case 1: a = 3, b = 2
        a <= to_signed(3, WIDTH_A);
        b <= to_signed(2, WIDTH_B);
        wait for 30 ns;
        assert (p = to_signed(6, WIDTH_A + WIDTH_B)) report "Test Case 1 Failed" severity error;
        wait for 10 ns;

        -- Test case 2: a = -4, b = 5
        a <= to_signed(-4, WIDTH_A);
        b <= to_signed(5, WIDTH_B);
        wait for 30 ns;
        assert (p = to_signed(-20, WIDTH_A + WIDTH_B)) report "Test Case 2 Failed" severity error;
        wait for 10 ns;

        -- Test case 3: a = -7, b = -3
        a <= to_signed(-7, WIDTH_A);
        b <= to_signed(-3, WIDTH_B);
        wait for 30 ns;
        assert (p = to_signed(21, WIDTH_A + WIDTH_B)) report "Test Case 3 Failed" severity error;
        wait for 10 ns;

        -- Test case 4: a = 0, b = -10
        a <= to_signed(0, WIDTH_A);
        b <= to_signed(-10, WIDTH_B);
        wait for 30 ns;
        assert (p = to_signed(0, WIDTH_A + WIDTH_B)) report "Test Case 4 Failed" severity error;
        wait for 10 ns;

        -- Test case 5: a = 127, b = 1 (maximum positive value for 8-bit signed)
        a <= to_signed(127, WIDTH_A);
        b <= to_signed(1, WIDTH_B);
        wait for 30 ns;
        assert (p = to_signed(127, WIDTH_A + WIDTH_B)) report "Test Case 5 Failed" severity error;
        wait for 10 ns;

        -- Test case 6: a = -128, b = 1 (maximum negative value for 8-bit signed)
        a <= to_signed(-128, WIDTH_A);
        b <= to_signed(1, WIDTH_B);
        wait for 30 ns;
        assert (p = to_signed(-128, WIDTH_A + WIDTH_B)) report "Test Case 6 Failed" severity error;

        -- Wait for some time after the last test case to ensure the output is stable
        wait for 10 ns;

        -- End the simulation
        report "End of Simulation" severity note;
        wait;
    end process;

end architecture Behavioral;
