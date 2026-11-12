library ieee;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.all;

entity dmem is
	port ( 
		clk : in std_logic; 
		we : in std_logic; 
		addr : in std_logic_vector(31 downto 0); 
		wdata : in std_logic_vector(31 downto 0); 
		rdata : out std_logic_vector(31 downto 0) 
	); 
end entity dmem;
architecture rtl of dmem is 
	type ram_type is array (0 to 255) of std_logic_vector(31 downto 0); 
	signal ram : ram_type := (others => (others => '0')); 

	function to_addr(a : std_logic_vector(31 downto 0)) return integer is
	begin
		if is_X(a(9 downto 2)) then
			return 0;
		else
			return to_integer(unsigned(a(9 downto 2)));
		end if;
	end function;
begin 
	process(clk) 
	begin 
		if rising_edge(clk) then 
			if we = '1' and not is_X(addr(9 downto 2)) then 
				ram(to_addr(addr)) <= wdata; 
			end if; 
		end if; 
	end process;
	rdata <= ram(to_addr(addr)); 
end architecture rtl;