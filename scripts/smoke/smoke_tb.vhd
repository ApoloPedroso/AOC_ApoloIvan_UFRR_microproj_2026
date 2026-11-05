-- smoke_tb.vhd : teste de fumaça do ambiente (VHDL-2008 + GHDL).
-- Não tem relação com o processador. Serve apenas para provar que o GHDL
-- analisa, elabora e simula código VHDL-2008 em uma workdir própria.
-- Recursos exclusivos do VHDL-2008 usados: to_string, to_hstring e std.env.stop.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity smoke_tb is
end entity;

architecture sim of smoke_tb is
begin
  process
    variable v : unsigned(7 downto 0) := x"2A";
  begin
    wait for 1 ns;
    assert to_integer(v) = 42
      report "smoke_tb: aritmética inesperada" severity failure;
    report "smoke_tb OK: VHDL-2008 ativo (to_string=" & to_string(to_integer(v))
         & ", to_hstring=" & to_hstring(v) & ")";
    std.env.stop;
    wait;
  end process;
end architecture;
