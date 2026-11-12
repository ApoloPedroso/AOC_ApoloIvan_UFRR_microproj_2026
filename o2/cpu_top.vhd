library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity cpu_top is
    generic (
        PROG_FILE     : string  := "tracos/t0.hex";
        MEM_UNIFICADA : boolean := false
    );
    port (
        clk          : in  std_logic;
        rst          : in  std_logic;
        done         : out std_logic;
        hazard_abort : out std_logic;
        hazard_type  : out std_logic_vector(1 downto 0);
        hazard_pc    : out std_logic_vector(31 downto 0);
        hazard_cycle : out unsigned(31 downto 0);
        retired      : out unsigned(1 downto 0);
        stage_valid  : out std_logic_vector(9 downto 0);
        dbg_reg_addr : in  std_logic_vector(4 downto 0);
        dbg_reg_data : out std_logic_vector(31 downto 0)
    );
end entity cpu_top;

architecture rtl of cpu_top is

    -- =========================================================================
    -- Memória de Instruções (imem)
    -- =========================================================================
    type imem_array is array (0 to 255) of std_logic_vector(31 downto 0);

    impure function load_hex(filename : in string) return imem_array is
        file f          : text;
        variable l      : line;
        variable res    : imem_array := (others => (others => '0'));
        variable hex_val: std_logic_vector(31 downto 0);
        variable idx    : integer := 0;
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

    -- =========================================================================
    -- Definição dos Registradores Entre Estágios
    -- =========================================================================

    -- IF/ID: 97 bits (1 + 32 + 32 + 32)
    type reg_if_id_t is record
        valid     : std_logic;
        pc        : std_logic_vector(31 downto 0);
        pc_plus_4 : std_logic_vector(31 downto 0);
        instr     : std_logic_vector(31 downto 0);
    end record;

    constant REG_IF_ID_RESET : reg_if_id_t := (
        valid     => '0',
        pc        => (others => '0'),
        pc_plus_4 => (others => '0'),
        instr     => (others => '0')
    );

    -- ID/EX: 180 bits (1 + 32 + 32 + 3 + 2 + 5 + 32 + 32 + 32 + 5 + 5 + 5)
    type reg_id_ex_t is record
        valid       : std_logic;
        pc          : std_logic_vector(31 downto 0);
        pc_plus_4   : std_logic_vector(31 downto 0);
        -- WB controls
        reg_write   : std_logic;
        mem_to_reg  : std_logic;
        is_break    : std_logic;
        -- MEM controls
        branch      : std_logic;
        mem_write   : std_logic;
        -- EX controls
        reg_dst     : std_logic;
        alu_src     : std_logic;
        alu_control : std_logic_vector(2 downto 0);
        -- Data
        rdata1      : std_logic_vector(31 downto 0);
        rdata2      : std_logic_vector(31 downto 0);
        imm32       : std_logic_vector(31 downto 0);
        rs          : std_logic_vector(4 downto 0);
        rt          : std_logic_vector(4 downto 0);
        rd          : std_logic_vector(4 downto 0);
    end record;

    constant REG_ID_EX_RESET : reg_id_ex_t := (
        valid       => '0',
        pc          => (others => '0'),
        pc_plus_4   => (others => '0'),
        reg_write   => '0',
        mem_to_reg  => '0',
        is_break    => '0',
        branch      => '0',
        mem_write   => '0',
        reg_dst     => '0',
        alu_src     => '0',
        alu_control => (others => '0'),
        rdata1      => (others => '0'),
        rdata2      => (others => '0'),
        imm32       => (others => '0'),
        rs          => (others => '0'),
        rt          => (others => '0'),
        rd          => (others => '0')
    );

    -- EX/MEM: 140 bits (1 + 32 + 3 + 2 + 32 + 1 + 32 + 32 + 5)
    type reg_ex_mem_t is record
        valid         : std_logic;
        pc            : std_logic_vector(31 downto 0);
        -- WB controls
        reg_write     : std_logic;
        mem_to_reg    : std_logic;
        is_break      : std_logic;
        -- MEM controls
        branch        : std_logic;
        mem_write     : std_logic;
        -- Data
        branch_target : std_logic_vector(31 downto 0);
        zero          : std_logic;
        alu_result    : std_logic_vector(31 downto 0);
        wdata_mem     : std_logic_vector(31 downto 0);
        waddr         : std_logic_vector(4 downto 0);
    end record;

    constant REG_EX_MEM_RESET : reg_ex_mem_t := (
        valid         => '0',
        pc            => (others => '0'),
        reg_write     => '0',
        mem_to_reg    => '0',
        is_break      => '0',
        branch        => '0',
        mem_write     => '0',
        branch_target => (others => '0'),
        zero          => '0',
        alu_result    => (others => '0'),
        wdata_mem     => (others => '0'),
        waddr         => (others => '0')
    );

    -- MEM/WB: 105 bits (1 + 32 + 3 + 32 + 32 + 5)
    type reg_mem_wb_t is record
        valid      : std_logic;
        pc         : std_logic_vector(31 downto 0);
        -- WB controls
        reg_write  : std_logic;
        mem_to_reg : std_logic;
        is_break   : std_logic;
        -- Data
        mem_rdata  : std_logic_vector(31 downto 0);
        alu_result : std_logic_vector(31 downto 0);
        waddr      : std_logic_vector(4 downto 0);
    end record;

    constant REG_MEM_WB_RESET : reg_mem_wb_t := (
        valid      => '0',
        pc         => (others => '0'),
        reg_write  => '0',
        mem_to_reg => '0',
        is_break   => '0',
        mem_rdata  => (others => '0'),
        alu_result => (others => '0'),
        waddr      => (others => '0')
    );

    -- Instâncias dos registradores
    signal reg_if_id      : reg_if_id_t  := REG_IF_ID_RESET;
    signal reg_if_id_next : reg_if_id_t;

    signal reg_id_ex      : reg_id_ex_t  := REG_ID_EX_RESET;
    signal reg_id_ex_next : reg_id_ex_t;

    signal reg_ex_mem     : reg_ex_mem_t := REG_EX_MEM_RESET;
    signal reg_ex_mem_next: reg_ex_mem_t;

    signal reg_mem_wb     : reg_mem_wb_t := REG_MEM_WB_RESET;
    signal reg_mem_wb_next: reg_mem_wb_t;

    -- =========================================================================
    -- Sinais por Estágio
    -- =========================================================================

    -- Estágio IF
    signal pc_reg          : std_logic_vector(31 downto 0) := (others => '0');
    signal pc_plus_4_if    : std_logic_vector(31 downto 0);
    signal pc_next_if      : std_logic_vector(31 downto 0);
    signal instr_if        : std_logic_vector(31 downto 0);
    signal if_valid        : std_logic;
    signal is_break_if     : std_logic;
    signal fetching_active : std_logic := '1';

    -- Estágio ID
    signal ctrl_reg_write   : std_logic;
    signal ctrl_reg_dst     : std_logic;
    signal ctrl_alu_src     : std_logic;
    signal ctrl_branch      : std_logic;
    signal ctrl_mem_write   : std_logic;
    signal ctrl_mem_to_reg  : std_logic;
    signal ctrl_alu_control : std_logic_vector(2 downto 0);
    signal ctrl_is_break    : std_logic;
    signal rf_rdata1        : std_logic_vector(31 downto 0);
    signal rf_rdata2        : std_logic_vector(31 downto 0);
    signal sign_imm_id      : std_logic_vector(31 downto 0);

    -- Estágio EX
    signal ex_alu_src_b     : std_logic_vector(31 downto 0);
    signal ex_alu_result    : std_logic_vector(31 downto 0);
    signal ex_alu_zero      : std_logic;
    signal ex_waddr         : std_logic_vector(4 downto 0);
    signal ex_branch_target : std_logic_vector(31 downto 0);

    -- Estágio MEM
    signal mem_rdata        : std_logic_vector(31 downto 0);

    -- Estágio WB
    signal wb_wdata         : std_logic_vector(31 downto 0);

    -- Controle global
    signal done_reg         : std_logic := '0';
    signal done_comb        : std_logic;

begin

    -- =========================================================================
    -- Sinais de topo e detecção de conflitos (para M2 / Issues #7 a #11)
    -- =========================================================================
    hazard_abort <= '0';
    hazard_type  <= "00";
    hazard_pc    <= (others => '0');
    hazard_cycle <= (others => '0');

    done_comb <= '1' when (reg_mem_wb.valid = '1' and reg_mem_wb.is_break = '1') else done_reg;
    done      <= done_comb;

    -- retired: instruções úteis concluídas no ciclo (exclui break)
    retired <= "01" when (reg_mem_wb.valid = '1' and reg_mem_wb.is_break = '0' and done_reg = '0' and rst = '0')
          else "00";

    -- stage_valid(4 downto 0): bits 4..0 = via 0 (WB..IF)
    -- Bit 4 = WB, Bit 3 = MEM, Bit 2 = EX, Bit 1 = ID, Bit 0 = IF
    stage_valid(0) <= if_valid         when (rst = '0' and done_reg = '0') else '0';
    stage_valid(1) <= reg_if_id.valid  when (rst = '0' and done_reg = '0') else '0';
    stage_valid(2) <= reg_id_ex.valid  when (rst = '0' and done_reg = '0') else '0';
    stage_valid(3) <= reg_ex_mem.valid when (rst = '0' and done_reg = '0') else '0';
    stage_valid(4) <= reg_mem_wb.valid when (rst = '0' and done_reg = '0') else '0';
    stage_valid(9 downto 5) <= (others => '0');

    -- =========================================================================
    -- Estágio 1: IF (Busca de Instrução)
    -- =========================================================================
    instr_if     <= imem(to_integer(unsigned(pc_reg(9 downto 2))));
    pc_plus_4_if <= std_logic_vector(unsigned(pc_reg) + 4);
    pc_next_if   <= pc_plus_4_if;

    is_break_if  <= '1' when (instr_if(31 downto 26) = "000000" and instr_if(5 downto 0) = "001101") else '0';
    if_valid     <= '1' when (rst = '0' and done_reg = '0' and fetching_active = '1') else '0';

    reg_if_id_next.valid     <= if_valid;
    reg_if_id_next.pc        <= pc_reg;
    reg_if_id_next.pc_plus_4 <= pc_plus_4_if;
    reg_if_id_next.instr     <= instr_if;

    -- =========================================================================
    -- Estágio 2: ID (Decodificação e Leitura de Registradores)
    -- =========================================================================
    u_control : entity work.control
        port map (
            opcode      => reg_if_id.instr(31 downto 26),
            funct       => reg_if_id.instr(5 downto 0),
            reg_write   => ctrl_reg_write,
            reg_dst     => ctrl_reg_dst,
            alu_src     => ctrl_alu_src,
            branch      => ctrl_branch,
            mem_write   => ctrl_mem_write,
            mem_to_reg  => ctrl_mem_to_reg,
            alu_control => ctrl_alu_control,
            is_break    => ctrl_is_break
        );

    u_regfile : entity work.regfile
        port map (
            clk          => clk,
            rst          => rst,
            we           => reg_mem_wb.reg_write and reg_mem_wb.valid and (not done_reg),
            raddr1       => reg_if_id.instr(25 downto 21),
            raddr2       => reg_if_id.instr(20 downto 16),
            waddr        => reg_mem_wb.waddr,
            wdata        => wb_wdata,
            rdata1       => rf_rdata1,
            rdata2       => rf_rdata2,
            dbg_reg_addr => dbg_reg_addr,
            dbg_reg_data => dbg_reg_data
        );

    sign_imm_id <= std_logic_vector(resize(signed(reg_if_id.instr(15 downto 0)), 32));

    reg_id_ex_next.valid       <= reg_if_id.valid;
    reg_id_ex_next.pc          <= reg_if_id.pc;
    reg_id_ex_next.pc_plus_4   <= reg_if_id.pc_plus_4;
    reg_id_ex_next.reg_write   <= ctrl_reg_write and reg_if_id.valid;
    reg_id_ex_next.mem_to_reg  <= ctrl_mem_to_reg;
    reg_id_ex_next.is_break    <= ctrl_is_break and reg_if_id.valid;
    reg_id_ex_next.branch      <= ctrl_branch and reg_if_id.valid;
    reg_id_ex_next.mem_write   <= ctrl_mem_write and reg_if_id.valid;
    reg_id_ex_next.reg_dst     <= ctrl_reg_dst;
    reg_id_ex_next.alu_src     <= ctrl_alu_src;
    reg_id_ex_next.alu_control <= ctrl_alu_control;
    reg_id_ex_next.rdata1      <= rf_rdata1;
    reg_id_ex_next.rdata2      <= rf_rdata2;
    reg_id_ex_next.imm32       <= sign_imm_id;
    reg_id_ex_next.rs          <= reg_if_id.instr(25 downto 21);
    reg_id_ex_next.rt          <= reg_if_id.instr(20 downto 16);
    reg_id_ex_next.rd          <= reg_if_id.instr(15 downto 11);

    -- =========================================================================
    -- Estágio 3: EX (Execução / ULA)
    -- =========================================================================
    ex_alu_src_b <= reg_id_ex.imm32 when reg_id_ex.alu_src = '1' else reg_id_ex.rdata2;

    u_alu : entity work.alu
        port map (
            src_a       => reg_id_ex.rdata1,
            src_b       => ex_alu_src_b,
            alu_control => reg_id_ex.alu_control,
            alu_result  => ex_alu_result,
            zero        => ex_alu_zero
        );

    ex_waddr <= reg_id_ex.rd when reg_id_ex.reg_dst = '1' else reg_id_ex.rt;

    ex_branch_target <= std_logic_vector(unsigned(reg_id_ex.pc_plus_4) +
                        unsigned(std_logic_vector'(reg_id_ex.imm32(29 downto 0) & "00")));

    reg_ex_mem_next.valid         <= reg_id_ex.valid;
    reg_ex_mem_next.pc            <= reg_id_ex.pc;
    reg_ex_mem_next.reg_write     <= reg_id_ex.reg_write;
    reg_ex_mem_next.mem_to_reg    <= reg_id_ex.mem_to_reg;
    reg_ex_mem_next.is_break      <= reg_id_ex.is_break;
    reg_ex_mem_next.branch        <= reg_id_ex.branch;
    reg_ex_mem_next.mem_write     <= reg_id_ex.mem_write;
    reg_ex_mem_next.branch_target <= ex_branch_target;
    reg_ex_mem_next.zero          <= ex_alu_zero;
    reg_ex_mem_next.alu_result    <= ex_alu_result;
    reg_ex_mem_next.wdata_mem     <= reg_id_ex.rdata2;
    reg_ex_mem_next.waddr         <= ex_waddr;

    -- =========================================================================
    -- Estágio 4: MEM (Acesso à Memória)
    -- =========================================================================
    u_dmem : entity work.dmem
        port map (
            clk   => clk,
            we    => reg_ex_mem.mem_write and reg_ex_mem.valid and (not done_reg),
            addr  => reg_ex_mem.alu_result,
            wdata => reg_ex_mem.wdata_mem,
            rdata => mem_rdata
        );

    reg_mem_wb_next.valid      <= reg_ex_mem.valid;
    reg_mem_wb_next.pc         <= reg_ex_mem.pc;
    reg_mem_wb_next.reg_write  <= reg_ex_mem.reg_write;
    reg_mem_wb_next.mem_to_reg <= reg_ex_mem.mem_to_reg;
    reg_mem_wb_next.is_break   <= reg_ex_mem.is_break;
    reg_mem_wb_next.mem_rdata  <= mem_rdata;
    reg_mem_wb_next.alu_result <= reg_ex_mem.alu_result;
    reg_mem_wb_next.waddr      <= reg_ex_mem.waddr;

    -- =========================================================================
    -- Estágio 5: WB (Escrita no Banco de Registradores)
    -- =========================================================================
    wb_wdata <= reg_mem_wb.mem_rdata when reg_mem_wb.mem_to_reg = '1' else reg_mem_wb.alu_result;

    -- =========================================================================
    -- Processo Síncrono do Pipeline (Avanço dos Registradores e PC)
    -- =========================================================================
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                pc_reg          <= (others => '0');
                fetching_active <= '1';
                done_reg        <= '0';
                reg_if_id       <= REG_IF_ID_RESET;
                reg_id_ex       <= REG_ID_EX_RESET;
                reg_ex_mem      <= REG_EX_MEM_RESET;
                reg_mem_wb      <= REG_MEM_WB_RESET;
            elsif done_reg = '0' then
                if reg_mem_wb.valid = '1' and reg_mem_wb.is_break = '1' then
                    done_reg <= '1';
                else
                    reg_mem_wb <= reg_mem_wb_next;
                    reg_ex_mem <= reg_ex_mem_next;
                    reg_id_ex  <= reg_id_ex_next;
                    reg_if_id  <= reg_if_id_next;

                    if fetching_active = '1' then
                        if is_break_if = '1' then
                            fetching_active <= '0';
                        else
                            pc_reg <= pc_next_if;
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;

end architecture rtl;
