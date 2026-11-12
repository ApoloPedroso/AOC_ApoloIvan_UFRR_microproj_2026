library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity regfile is
    port (
        clk          : in  std_logic;
        rst          : in  std_logic;
        we           : in  std_logic;
        raddr1       : in  std_logic_vector(4 downto 0);
        raddr2       : in  std_logic_vector(4 downto 0);
        waddr        : in  std_logic_vector(4 downto 0);
        wdata        : in  std_logic_vector(31 downto 0);
        rdata1       : out std_logic_vector(31 downto 0);
        rdata2       : out std_logic_vector(31 downto 0);
        dbg_reg_addr : in  std_logic_vector(4 downto 0);
        dbg_reg_data : out std_logic_vector(31 downto 0)
    );
end entity regfile;

architecture rtl of regfile is
    type reg_array is array (0 to 31) of std_logic_vector(31 downto 0);
    signal registers : reg_array := (others => (others => '0'));
begin

    -- Escrita na primeira metade do ciclo (borda de descida do clock)
    process(clk)
    begin
        if falling_edge(clk) then
            if rst = '1' then
                registers <= (others => (others => '0'));
            elsif we = '1' and to_integer(unsigned(waddr)) /= 0 then
                registers(to_integer(unsigned(waddr))) <= wdata;
            end if;
        end if;
    end process;

    -- Leitura na segunda metade do ciclo (combinacional, com bypass interno se escrito no mesmo ciclo)
    rdata1 <= (others => '0') when to_integer(unsigned(raddr1)) = 0
         else wdata           when (we = '1' and waddr = raddr1 and to_integer(unsigned(waddr)) /= 0)
         else registers(to_integer(unsigned(raddr1)));

    rdata2 <= (others => '0') when to_integer(unsigned(raddr2)) = 0
         else wdata           when (we = '1' and waddr = raddr2 and to_integer(unsigned(waddr)) /= 0)
         else registers(to_integer(unsigned(raddr2)));

    -- Porta de depuração assíncrona / combinacional
    dbg_reg_data <= (others => '0') when to_integer(unsigned(dbg_reg_addr)) = 0
               else registers(to_integer(unsigned(dbg_reg_addr)));

end architecture rtl;
