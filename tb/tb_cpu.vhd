-- tb_cpu.vhd : testbench único para O1 e O2 (VHDL-2008)
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity tb_cpu is
    generic (
        PROG_FILE          : string   := "tracos/t0.hex";          -- programa (.hex)
        ESPERADO_FILE      : string   := "tracos/t0_esperado.txt"; -- linhas "reg valor_hex"
        ORG_NOME           : string   := "O2";                     -- rótulo usado na saída
        NUM_SLOTS          : positive := 5;                        -- O1 = 1, O2 = 5
        MEM_UNIFICADA      : boolean  := false;                    -- true só no traço TE de O2
        ESPERA_ABORTO      : boolean  := false;                    -- true nos traços TD, TE e TC
        TIPO_ESPERADO      : natural  := 0;                        -- 1 dados, 2 estrutural, 3 controle
        HAZARD_PC_ESPERADO : std_logic_vector(31 downto 0) := (others => '0'); -- PC esperado no aborto
        T_CLK              : time     := 10 ns;                    -- período de SIMULAÇÃO, não o real
        MAX_CICLOS         : natural  := 10_000                    -- proteção contra laço infinito
    );
end entity tb_cpu;

architecture sim of tb_cpu is
    signal clk          : std_logic := '0';
    signal rst          : std_logic := '1';
    signal fim_sim      : boolean   := false;
    signal done         : std_logic;
    signal hazard_abort : std_logic;
    signal hazard_type  : std_logic_vector(1 downto 0);
    signal hazard_pc    : std_logic_vector(31 downto 0);
    signal hazard_cycle : unsigned(31 downto 0);
    signal retired      : unsigned(1 downto 0);
    signal stage_valid  : std_logic_vector(9 downto 0);
    signal dbg_reg_addr : std_logic_vector(4 downto 0) := (others => '0');
    signal dbg_reg_data : std_logic_vector(31 downto 0);
begin

    -- 1. Geração de clock: para quando fim_sim = true
    clk <= not clk after T_CLK / 2 when not fim_sim else '0';

    -- 2. Processador sob teste
    dut : entity work.cpu_top
        generic map (
            PROG_FILE     => PROG_FILE,
            MEM_UNIFICADA => MEM_UNIFICADA
        )
        port map (
            clk          => clk,
            rst          => rst,
            done         => done,
            hazard_abort => hazard_abort,
            hazard_type  => hazard_type,
            hazard_pc    => hazard_pc,
            hazard_cycle => hazard_cycle,
            retired      => retired,
            stage_valid  => stage_valid,
            dbg_reg_addr => dbg_reg_addr,
            dbg_reg_data => dbg_reg_data
        );

    -- 3. Processo principal
    principal : process
        file f_esp        : text;
        file f_csv        : text;
        variable l        : line;
        variable st       : file_open_status;
        variable ciclos   : natural := 0;
        variable instrs   : natural := 0;
        variable ocupados : natural := 0;
        variable erros    : natural := 0;
        variable reg_num  : integer;
        variable valor    : std_logic_vector(31 downto 0);
        variable cpi, ipc, ocup : real := 0.0;
    begin
        -- 3.1 Reset síncrono durante 2 ciclos
        rst <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        rst <= '0';

        -- 3.2 Execução: amostra na borda de DESCIDA, no meio do ciclo,
        -- quando as saídas do processador já estão estáveis
        loop
            wait until falling_edge(clk);
            ciclos := ciclos + 1;
            instrs := instrs + to_integer(retired);
            for i in 0 to NUM_SLOTS - 1 loop
                if stage_valid(i) = '1' then
                    ocupados := ocupados + 1;
                end if;
            end loop;
            exit when done = '1' or hazard_abort = '1' or ciclos = MAX_CICLOS;
        end loop;

        -- 3.3 Desfecho: aborto, fim normal ou tempo esgotado
        if hazard_abort = '1' then
            report ORG_NOME & ": ABORTO tipo=" & to_string(hazard_type) &
                   " pc=0x" & to_hstring(hazard_pc) &
                   " ciclo=" & integer'image(to_integer(hazard_cycle));
            assert ESPERA_ABORTO
                report "Aborto inesperado: o traço deveria ser livre de conflitos"
                severity error;
            assert to_integer(unsigned(hazard_type)) = TIPO_ESPERADO
                report "Tipo de conflito diferente do esperado" severity error;
            assert to_integer(hazard_cycle) = ciclos
                report "hazard_cycle difere da contagem do testbench" severity warning;
            if HAZARD_PC_ESPERADO /= X"00000000" then
                assert hazard_pc = HAZARD_PC_ESPERADO
                    report "hazard_pc difere do esperado: obtido 0x" & to_hstring(hazard_pc) &
                           " esperado 0x" & to_hstring(HAZARD_PC_ESPERADO)
                    severity error;
            end if;

        elsif done = '1' then
            assert not ESPERA_ABORTO
                report "Conflito esperado não foi detectado" severity error;

            -- 3.4 Verificação automática: compara registradores com o esperado
            file_open(st, f_esp, ESPERADO_FILE, read_mode);
            assert st = open_ok
                report "Não foi possível abrir " & ESPERADO_FILE severity failure;
            while not endfile(f_esp) loop
                readline(f_esp, l);
                next when l'length = 0;
                next when l(1) = '#';
                read(l, reg_num);
                hread(l, valor);
                dbg_reg_addr <= std_logic_vector(to_unsigned(reg_num, 5));
                wait for 1 ns;
                if dbg_reg_data /= valor then
                    erros := erros + 1;
                    report "Reg " & integer'image(reg_num) & ": esperado 0x" &
                           to_hstring(valor) & ", obtido 0x" & to_hstring(dbg_reg_data)
                        severity error;
                end if;
            end loop;
            file_close(f_esp);

        else
            report ORG_NOME & ": tempo esgotado em " & integer'image(MAX_CICLOS) &
                   " ciclos" severity failure;
        end if;

        -- 3.5 Métricas: uma linha por execução em metricas.csv
        -- org;programa;ciclos;instrucoes;CPI;IPC;ocupacao;erros
        if instrs > 0 then
            cpi := real(ciclos) / real(instrs);
            ipc := real(instrs) / real(ciclos);
        end if;
        ocup := real(ocupados) / real(ciclos * NUM_SLOTS);
        file_open(st, f_csv, "metricas.csv", append_mode);
        write(l, ORG_NOME & ";" & PROG_FILE & ";" & integer'image(ciclos) & ";" &
                 integer'image(instrs) & ";" & real'image(cpi) & ";" &
                 real'image(ipc) & ";" & real'image(ocup) & ";" &
                 integer'image(erros));
        writeline(f_csv, l);
        file_close(f_csv);

        -- 3.6 Encerramento
        report ORG_NOME & ": fim da simulação, " & integer'image(ciclos) &
               " ciclos, " & integer'image(erros) & " erro(s)";
        fim_sim <= true;
        std.env.stop;
        wait;
    end process;

end architecture sim;
