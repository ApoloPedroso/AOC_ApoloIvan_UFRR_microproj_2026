library ieee;
use ieee.std_logic_1164.all;

entity control is
    port (
        opcode      : in  std_logic_vector(5 downto 0);
        funct       : in  std_logic_vector(5 downto 0);
        reg_write   : out std_logic;
        reg_dst     : out std_logic;
        alu_src     : out std_logic;
        branch      : out std_logic;
        mem_write   : out std_logic;
        mem_to_reg  : out std_logic;
        alu_control : out std_logic_vector(2 downto 0);
        is_break    : out std_logic
    );
end entity control;

architecture rtl of control is
begin
    process(opcode, funct)
    begin
        reg_write   <= '0';
        reg_dst     <= '0';
        alu_src     <= '0';
        branch      <= '0';
        mem_write   <= '0';
        mem_to_reg  <= '0';
        alu_control <= "000";
        is_break    <= '0';

        case opcode is
            when "000000" => -- Tipo R
                case funct is
                    when "100000" => -- add
                        reg_write   <= '1';
                        reg_dst     <= '1';
                        alu_src     <= '0';
                        alu_control <= "010";
                    when "100010" => -- sub
                        reg_write   <= '1';
                        reg_dst     <= '1';
                        alu_src     <= '0';
                        alu_control <= "110";
                    when "100100" => -- and
                        reg_write   <= '1';
                        reg_dst     <= '1';
                        alu_src     <= '0';
                        alu_control <= "000";
                    when "100101" => -- or
                        reg_write   <= '1';
                        reg_dst     <= '1';
                        alu_src     <= '0';
                        alu_control <= "001";
                    when "101010" => -- slt
                        reg_write   <= '1';
                        reg_dst     <= '1';
                        alu_src     <= '0';
                        alu_control <= "111";
                    when "001101" => -- break
                        is_break    <= '1';
                    when others =>
                        null;
                end case;

            when "001000" => -- addi
                reg_write   <= '1';
                reg_dst     <= '0'; -- rt
                alu_src     <= '1'; -- imm
                alu_control <= "010";

            when "100011" => -- lw
                reg_write   <= '1';
                reg_dst     <= '0'; -- rt
                alu_src     <= '1'; -- imm
                mem_to_reg  <= '1';
                alu_control <= "010";

            when "101011" => -- sw
                reg_dst     <= '0';
                alu_src     <= '1'; -- imm
                mem_write   <= '1';
                alu_control <= "010";

            when "000100" => -- beq
                branch      <= '1';
                alu_control <= "110";

            when others =>
                null;
        end case;
    end process;
end architecture rtl;
