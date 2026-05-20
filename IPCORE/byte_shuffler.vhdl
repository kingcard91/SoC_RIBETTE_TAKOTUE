library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity byte_shuffler is
    port(
        clk       : in  std_logic;
        reset_n   : in  std_logic;
        chipselect: in  std_logic;
        write     : in  std_logic;
        writedata : in  std_logic_vector(31 downto 0);
        read      : in  std_logic;
        readdata  : out std_logic_vector(31 downto 0);
        address   : in  std_logic_vector(1 downto 0)  -- 0=write_data, 1=mode, 2=read_data
    );
end entity;

architecture rtl of byte_shuffler is
    signal reg_in   : std_logic_vector(31 downto 0);
    signal reg_out  : std_logic_vector(31 downto 0);
    signal mode_reg : std_logic := '0'; -- 0=mode0, 1=mode1
begin

    -- Ecriture des registres
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            reg_in <= (others => '0');
            mode_reg <= '0';
        elsif rising_edge(clk) then
            if chipselect = '1' and write = '1' then
                case address is
                    when "00" =>
                        reg_in <= writedata;
                    when "01" =>
                        mode_reg <= writedata(0); -- seul le LSB définit le mode
                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process;

    -- Inversion combinatoire des octets selon le mode
    with mode_reg select
        reg_out <= reg_in(7 downto 0)  & reg_in(15 downto 8) & reg_in(23 downto 16) & reg_in(31 downto 24) when '0',  -- mode0
                   reg_in(15 downto 8) & reg_in(7 downto 0) & reg_in(31 downto 24) & reg_in(23 downto 16) when '1'; -- mode1

    -- Lecture
    process(chipselect, read, address, reg_out, mode_reg)
    begin
        if chipselect = '1' and read = '1' then
            case address is
                when "00" => readdata <= reg_in;
                when "01" => readdata <= (31 downto 1 => '0') & mode_reg;
                when "10" => readdata <= reg_out;
                when others => readdata <= (others => '0');
            end case;
        else
            readdata <= (others => '0');
        end if;
    end process;

end architecture;