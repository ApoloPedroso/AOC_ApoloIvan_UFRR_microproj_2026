library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alu is
    port (
        src_a       : in  std_logic_vector(31 downto 0);
        src_b       : in  std_logic_vector(31 downto 0);
        alu_control : in  std_logic_vector(2 downto 0);
        alu_result  : out std_logic_vector(31 downto 0);
        zero        : out std_logic
    );
end entity alu;

architecture rtl of alu is
    signal result_internal : std_logic_vector(31 downto 0);
begin
    process(src_a, src_b, alu_control)
    begin
        case alu_control is
            when "010" => -- ADD
                result_internal <= std_logic_vector(signed(src_a) + signed(src_b));
            when "110" => -- SUB
                result_internal <= std_logic_vector(signed(src_a) - signed(src_b));
            when "000" => -- AND
                result_internal <= src_a and src_b;
            when "001" => -- OR
                result_internal <= src_a or src_b;
            when "111" => -- SLT
                if signed(src_a) < signed(src_b) then
                    result_internal <= X"00000001";
                else
                    result_internal <= X"00000000";
                end if;
            when others =>
                result_internal <= (others => '0');
        end case;
    end process;

    alu_result <= result_internal;
    zero <= '1' when result_internal = X"00000000" else '0';
end architecture rtl;
