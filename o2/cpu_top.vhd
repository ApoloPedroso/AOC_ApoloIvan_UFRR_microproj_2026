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
    -- MemÃ³ria de InstruÃ§Ãµes (imem)
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
    -- DefiniÃ§Ã£o dos Registradores Entre EstÃ¡gios
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

    -- ID/EX: 186 bits (1 + 32 + 32 + 7 + 3 + 96 + 15)
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

    -- InstÃ¢ncias dos registradores
    signal reg_if_id      : reg_if_id_t  := REG_IF_ID_RESET;
    signal reg_if_id_next : reg_if_id_t;

    signal reg_id_ex      : reg_id_ex_t  := REG_ID_EX_RESET;
    signal reg_id_ex_next : reg_id_ex_t;

    signal reg_ex_mem     : reg_ex_mem_t := REG_EX_MEM_RESET;
    signal reg_ex_mem_next: reg_ex_mem_t;

    signal reg_mem_wb     : reg_mem_wb_t := REG_MEM_WB_RESET;
    signal reg_mem_wb_next: reg_mem_wb_t;

    -- =========================================================================
    -- Sinais por EstÃ¡gio
    -- =========================================================================

    -- EstÃ¡gio IF
    signal pc_reg          : std_logic_vector(31 downto 0) := (others => '0');
    signal pc_plus_4_if    : std_logic_vector(31 downto 0);
    signal pc_next_if      : std_logic_vector(31 downto 0);
    signal instr_if        : std_logic_vector(31 downto 0);
    signal if_valid        : std_logic;
    signal is_break_if     : std_logic;
    signal fetching_active : std_logic := '1';

    -- EstÃ¡gio ID
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

    -- EstÃ¡gio EX
    signal ex_alu_src_b     : std_logic_vector(31 downto 0);
    signal ex_alu_result    : std_logic_vector(31 downto 0);
    signal ex_alu_zero      : std_logic;
    signal ex_waddr         : std_logic_vector(4 downto 0);
    signal ex_branch_target : std_logic_vector(31 downto 0);

    -- EstÃ¡gio MEM
    signal mem_rdata        : std_logic_vector(31 downto 0);

    -- EstÃ¡gio WB
    signal wb_wdata         : std_logic_vector(31 downto 0);

    -- Controle global
    signal done_reg         : std_logic := '0';
    signal done_comb        : std_logic;

    -- Controle de hazards
    signal hazard_detect    : std_logic;
    signal hazard_control : std_logic;
    signal hazard_structural : std_logic;
    signal hazard_abort_reg : std_logic := '0';
    signal hazard_type_reg  : std_logic_vector(1 downto 0) := "00";
    signal hazard_pc_reg    : std_logic_vector(31 downto 0) := (others => '0');
    signal hazard_cycle_reg : unsigned(31 downto 0) := (others => '0');

    signal hazard_data      : std_logic;

    -- Identifica quais operandos a instruÃ§Ã£o em ID realmente utiliza.
    signal id_uses_rs       : std_logic;
    signal id_uses_rt       : std_logic;

    -- Campos fonte da instruÃ§Ã£o em ID.
    signal id_rs            : std_logic_vector(4 downto 0);
    signal id_rt            : std_logic_vector(4 downto 0);

    -- Contador de ciclos de execuÃ§Ã£o
    signal cycle_count      : unsigned(31 downto 0) := (others => '0');

    begin

    -- ================================================================
    -- IdentificaÃ§Ã£o dos operandos utilizados pela instruÃ§Ã£o em ID
    -- ================================================================

    -- Registradores fonte da instruÃ§Ã£o em ID.
    id_rs <= reg_if_id.instr(25 downto 21);
    id_rt <= reg_if_id.instr(20 downto 16);

    -- Identifica quais operandos sÃ£o efetivamente utilizados.
    process(all)

    begin
        id_uses_rs <= '0';
        id_uses_rt <= '0';

        case reg_if_id.instr(31 downto 26) is

            -- InstruÃ§Ãµes tipo R: add, sub, and, or e slt.
            when "000000" =>
                case reg_if_id.instr(5 downto 0) is
                    when "100000" | "100010" |
                         "100100" | "100101" |
                         "101010" =>
                        id_uses_rs <= '1';
                        id_uses_rt <= '1';

                    when others =>
                        null;
                end case;

            -- addi e lw utilizam somente rs como fonte.
            when "001000" | "100011" =>
                id_uses_rs <= '1';

            -- sw e beq utilizam rs e rt como fontes.
            when "101011" | "000100" =>
                id_uses_rs <= '1';
                id_uses_rt <= '1';

            when others =>
                null;

        end case;
    end process;

        -- ================================================================
    -- DetecÃ§Ã£o de hazard de dados RAW
    -- ================================================================

    hazard_data <= '1' when (
        reg_if_id.valid = '1' and
        hazard_abort_reg = '0' and
        done_comb = '0' and
        (
            (
                id_uses_rs = '1' and
                id_rs /= "00000" and
                (
                    (
                        reg_id_ex.valid = '1' and
                        reg_id_ex.reg_write = '1' and
                        ex_waddr /= "00000" and
                        ex_waddr = id_rs
                    )
                    or
                    (
                        reg_ex_mem.valid = '1' and
                        reg_ex_mem.reg_write = '1' and
                        reg_ex_mem.waddr /= "00000" and
                        reg_ex_mem.waddr = id_rs
                    )
                    or
                    (
                        reg_mem_wb.valid = '1' and
                        reg_mem_wb.reg_write = '1' and
                        reg_mem_wb.waddr /= "00000" and
                        reg_mem_wb.waddr = id_rs
                    )
                )
            )
            or
            (
                id_uses_rt = '1' and
                id_rt /= "00000" and
                (
                    (
                        reg_id_ex.valid = '1' and
                        reg_id_ex.reg_write = '1' and
                        ex_waddr /= "00000" and
                        ex_waddr = id_rt
                    )
                    or
                    (
                        reg_ex_mem.valid = '1' and
                        reg_ex_mem.reg_write = '1' and
                        reg_ex_mem.waddr /= "00000" and
                        reg_ex_mem.waddr = id_rt
                    )
                    or
                    (
                        reg_mem_wb.valid = '1' and
                        reg_mem_wb.reg_write = '1' and
                        reg_mem_wb.waddr /= "00000" and
                        reg_mem_wb.waddr = id_rt
                    )
                )
            )
        )
    ) else '0';

    -- =========================================================================
    -- Sinais de topo e detecÃ§Ã£o de conflitos (para M2 / Issues #7 a #11)
    -- =========================================================================

        -- SaÃ­das do detector de hazards
    hazard_abort <= hazard_abort_reg;
    hazard_type  <= hazard_type_reg;
    hazard_pc    <= hazard_pc_reg;
    hazard_cycle <= hazard_cycle_reg;

    -- Detecta hazard estrutural quando a memÃ³ria unificada Ã© acessada por uma instruÃ§Ã£o lw/sw em MEM e outra instruÃ§Ã£o estÃ¡ em IF.
    hazard_structural <= '1' when (
    MEM_UNIFICADA and
    hazard_abort_reg = '0' and
    done_comb = '0' and
    reg_ex_mem.valid = '1' and
    (reg_ex_mem.mem_to_reg = '1' or reg_ex_mem.mem_write = '1') and
    if_valid = '1'
    ) else '0';

    -- Detecta hazard de controle quando um beq tomado possui instruÃ§Ãµes mais novas nos estÃ¡gios anteriores.
    hazard_control <= '1' when (
        hazard_abort_reg = '0' and
        done_comb = '0' and
        reg_id_ex.valid = '1' and
        reg_id_ex.branch = '1' and
        ex_alu_zero = '1' and
        (reg_if_id.valid = '1' or if_valid = '1')
    ) else '0';

    -- ReÃºne os hazards de dados, controle e estrutural.
    hazard_detect <= hazard_data or hazard_control or hazard_structural;

    done_comb <= '1' when (reg_mem_wb.valid = '1' and reg_mem_wb.is_break = '1') else done_reg;
    done      <= done_comb;

    -- retired: instruÃ§Ãµes Ãºteis concluÃ­das no ciclo (exclui break)
        retired <= "01" when (
        reg_mem_wb.valid = '1' and
        reg_mem_wb.is_break = '0' and
        done_reg = '0' and
        rst = '0' and
        hazard_abort_reg = '0' and
        hazard_detect = '0'
    ) else "00";

    -- stage_valid(4 downto 0): bits 4..0 = via 0 (WB..IF)
    -- Bit 4 = WB, Bit 3 = MEM, Bit 2 = EX, Bit 1 = ID, Bit 0 = IF
    stage_valid(0) <= if_valid         when (rst = '0' and done_reg = '0') else '0';
    stage_valid(1) <= reg_if_id.valid  when (rst = '0' and done_reg = '0') else '0';
    stage_valid(2) <= reg_id_ex.valid  when (rst = '0' and done_reg = '0') else '0';
    stage_valid(3) <= reg_ex_mem.valid when (rst = '0' and done_reg = '0') else '0';
    stage_valid(4) <= reg_mem_wb.valid when (rst = '0' and done_reg = '0') else '0';
    stage_valid(9 downto 5) <= (others => '0');

    -- =========================================================================
    -- EstÃ¡gio 1: IF (Busca de InstruÃ§Ã£o)
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
    -- EstÃ¡gio 2: ID (DecodificaÃ§Ã£o e Leitura de Registradores)
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
            we           => reg_mem_wb.reg_write and reg_mem_wb.valid and
                        (not done_reg) and (not hazard_abort_reg) and
                        (not hazard_detect),
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
    -- EstÃ¡gio 3: EX (ExecuÃ§Ã£o / ULA)
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
    -- EstÃ¡gio 4: MEM (Acesso Ã  MemÃ³ria)
    -- =========================================================================
    u_dmem : entity work.dmem
        port map (
            clk   => clk,
            we    => reg_ex_mem.mem_write and reg_ex_mem.valid and
            (not done_reg) and (not hazard_abort_reg) and
            (not hazard_detect),
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
    -- EstÃ¡gio 5: WB (Escrita no Banco de Registradores)
    -- =========================================================================
    wb_wdata <= reg_mem_wb.mem_rdata when reg_mem_wb.mem_to_reg = '1' else reg_mem_wb.alu_result;

    -- =========================================================================
    -- Processo SÃ­ncrono do Pipeline (AvanÃ§o dos Registradores e PC)
    -- =========================================================================
    process(clk)
    begin
        if rising_edge(clk) then

            -- Reset sÃ­ncrono: limpa o processador e o detector
            if rst = '1' then
                pc_reg          <= (others => '0');
                fetching_active <= '1';
                done_reg        <= '0';

                reg_if_id       <= REG_IF_ID_RESET;
                reg_id_ex       <= REG_ID_EX_RESET;
                reg_ex_mem      <= REG_EX_MEM_RESET;
                reg_mem_wb      <= REG_MEM_WB_RESET;

                hazard_abort_reg <= '0';
                hazard_type_reg  <= "00";
                hazard_pc_reg    <= (others => '0');
                hazard_cycle_reg <= (others => '0');


            -- MantÃ©m o processador congelado apÃ³s o aborto
            elsif hazard_abort_reg = '1' then
                null;

            -- Detecta e registra o primeiro hazard
            elsif hazard_detect = '1' then
                hazard_abort_reg <= '1';

            if hazard_data = '1' then
                -- RAW: aponta para a instruÃ§Ã£o consumidora em ID.
                hazard_type_reg <= "01";
                hazard_pc_reg   <= reg_if_id.pc;

            elsif hazard_structural = '1' then
                -- Estrutural: conflito entre IF e MEM.
                hazard_type_reg <= "10";
                hazard_pc_reg   <= pc_reg;

            else
                -- Controle: desvio tomado com instruÃ§Ãµes mais novas.
                hazard_type_reg <= "11";
                hazard_pc_reg   <= reg_id_ex.pc;
            end if;

                hazard_cycle_reg <= cycle_count + 1;

            -- ExecuÃ§Ã£o normal
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

    -- =========================================================================
    -- Contador de ciclos na borda de descida
    -- =========================================================================
    process(clk)
    begin
        if falling_edge(clk) then
            if rst = '1' then
                cycle_count <= (others => '0');

            elsif hazard_abort_reg = '0' and done_reg = '0' then
                cycle_count <= cycle_count + 1;
            end if;
        end if;
    end process;

end architecture rtl;
