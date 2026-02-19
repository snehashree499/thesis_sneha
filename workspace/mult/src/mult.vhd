library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mult is
	generic (
		M     : integer := 18;
		N     : integer := 6
	);
	port (
		clk : in  std_logic;
		rst : in  std_logic;
		a   : in  signed(M-1 downto 0);
		b   : in  signed(N-1 downto 0);
		p   : out signed(M+N-1 downto 0)
	);
end entity;

architecture rtl of mult is

	signal a_i : signed(M-1 downto 0);
	signal b_i : signed(N-1 downto 0);
	signal p_i : signed(M+N-1 downto 0);

begin
	process(clk, rst)
	begin
		if rst = '0' then
			a_i <= (others => '0');
			b_i <= (others => '0');
			p_i <= (others => '0');
		elsif rising_edge(clk) then
			a_i <= a;
			b_i <= b;
			p_i <= a_i * b_i;
		end if;
	end process;
	
	p <= p_i;

end architecture;
