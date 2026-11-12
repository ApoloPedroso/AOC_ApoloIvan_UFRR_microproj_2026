library ieee; 
use ieee.std_logic_1164.all; 
use ieee.numeric_std.all; 
use std.textio.all;

entity cpu_top is 
	generic ( 
		PROG_FILE : string := "tracos/t0.hex"; 
		MEM_UNIFICADA : boolean := false 
	);
	port ( 
		clk : in std_logic; 
		rst : in std_logic; 
		done : out std_logic; 
		hazard_abort : out std_logic; 
		hazard_type : out std_logic_vector(1 downto 0); 
		hazard_pc : out std_logic_vector(31 downto 0); 
		hazard_cycle : out unsigned(31 downto 0); 
		retired : out unsigned(1 downto 0); 
		stage_valid : out std_logic_vector(9 downto 0); 
		dbg_reg_addr : in std_logic_vector(4 downto 0); 
		dbg_reg_data : out std_logic_vector(31 downto 0) 
	);
end entity cpu_top;
architecture rtl of cpu_top is 
	type imem_array is array (0 to 255) of std_logic_vector(31 downto 0); 
	impure function load_hex(filename : in string) return imem_array is
		file f : text; 
		variable l : line; 
		variable res : imem_array := (others => (others => '0')); 
		variable hex_val : std_logic_vector(31 downto 0); 
		variable idx : integer := 0; 
		variable status : file_open_status;
	begin 
		file_open(status, f, filename, read_mode); 
		if status = open_ok then 
			while not endfile(f) and idx < 256 loop 
				readline(f, l); 
				hread(l, hex_val); 
				res(idx) := hex_val; 
				idx := idx + 1; 
			end loop; 
			file_close(f); 
		end if; 
		return res; 
    end function; 
	signal imem : imem_array := load_hex(PROG_FILE);
	
		signal pc : std_logic_vector(31 downto 0) := (others => '0');
		signal pc_next : std_logic_vector(31 downto 0); 
		signal pc_plus_4 : std_logic_vector(31 downto 0); 
		signal pc_branch : std_logic_vector(31 downto 0); 
		signal instr : std_logic_vector(31 downto 0); 
		signal sign_imm : std_logic_vector(31 downto 0);
		
		signal waddr : std_logic_vector(4 downto 0); 
		signal rdata1 : std_logic_vector(31 downto 0); 
		signal rdata2 : std_logic_vector(31 downto 0); 
		signal wdata : std_logic_vector(31 downto 0);
		
		signal src_b : std_logic_vector(31 downto 0); 
		signal alu_res : std_logic_vector(31 downto 0); 
		signal alu_zero : std_logic; 
		signal mem_rdata : std_logic_vector(31 downto 0);
		
		signal reg_write : std_logic; 
		signal reg_dst : std_logic; 
		signal alu_src : std_logic; 
		signal branch : std_logic; 
		signal mem_write : std_logic; 
		signal mem_to_reg : std_logic; 
		signal alu_control : std_logic_vector(2 downto 0); 
		signal is_break : std_logic;
		
		signal done_reg : std_logic := '0';
		
    begin 
	hazard_abort <= '0'; 
	hazard_type <= "00"; 
	hazard_pc <= (others => '0'); 
	hazard_cycle <= (others => '0'); 
	done <= done_reg;
	
	retired <= "01" when (done_reg = '0' and rst = '0' and is_break = '0') else "00"; 
	stage_valid <= "000000000" &  (not done_reg and not rst);
	
	instr <= imem(to_integer(unsigned(pc(9 downto 2))));
	
	pc_plus_4 <= std_logic_vector(unsigned(pc) + 4); 
	pc_branch <= std_logic_vector(unsigned(pc_plus_4) + unsigned(std_logic_vector'(sign_imm(29 downto 0) & "00")));
	
	pc_next <= pc_branch when (branch = '1' and alu_zero = '1') else pc_plus_4;
	
	process(clk) 
	begin 
		if rising_edge(clk) then 
			if rst = '1' then 
				pc <= (others => '0'); 
				done_reg <= '0'; 
			elsif done_reg = '0' then 
				if is_break = '1' then 
					done_reg <= '1'; 
				else 
					pc <= pc_next; 
				end if; 
			end if; 
		end if; 
	end process;
	
	sign_imm <= std_logic_vector(resize(signed(instr(15 downto 0)), 32));
	
	u_control : entity work.control 
		port map ( 
			opcode => instr(31 downto 26), 
			funct => instr(5 downto 0), 
			reg_write => reg_write, 
			reg_dst => reg_dst, 
			alu_src => alu_src, 
			branch => branch, 
			mem_write => mem_write, 
			mem_to_reg => mem_to_reg, 
			alu_control => alu_control, 
			is_break => is_break 
		);
	waddr <= instr(15 downto 11) when reg_dst = '1' else instr(20 downto 16);
	
	u_regfile : entity work.regfile 
		port map ( 
			clk => clk, 
			rst => rst, 
			we => reg_write and not done_reg, 
			raddr1 => instr(25 downto 21), 
			raddr2 => instr(20 downto 16), 
			waddr => waddr, 
			wdata => wdata, 
			rdata1 => rdata1, 
			rdata2 => rdata2, 
			dbg_reg_addr => dbg_reg_addr, 
			dbg_reg_data => dbg_reg_data 
		);
	src_b <= sign_imm when alu_src = '1' else rdata2;

	u_alu : entity work.alu 
		port map ( 
			src_a => rdata1, 
			src_b => src_b, 
			alu_control => alu_control, 
			alu_result => alu_res, 
			zero => alu_zero 
		);	
	
	u_dmem : entity work.dmem 
		port map ( 
			clk => clk, 
			we => mem_write and not done_reg, 
			addr => alu_res, 
			wdata => rdata2, 
			rdata => mem_rdata 
		);

	wdata <= mem_rdata when mem_to_reg = '1' else alu_res;
	
end architecture rtl;