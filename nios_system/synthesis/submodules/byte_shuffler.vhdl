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
        address   : in  std_logic_vector(1 downto 0)  -- 0=data_in, 1=mode, 2=data_out
    );
end entity;

architecture rtl of byte_shuffler is
    signal reg_data  : std_logic_vector(31 downto 0);
    signal reg_mode  : std_logic := '0';
    signal reg_out   : std_logic_vector(31 downto 0);
begin

    -- Ecriture des registres depuis Nios II
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            reg_data <= (others => '0');
            reg_mode <= '0';
        elsif rising_edge(clk) then
            if chipselect = '1' and write = '1' then
                case address is
                    when "00" =>
                        reg_data <= writedata;  -- écrire le mot à inverser
                    when "01" =>
                        reg_mode <= writedata(0); -- mode SWAP1/SWAP2
                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process;

    -- Calcul combinatoire selon le mode
    with reg_mode select
        reg_out <= reg_data(7 downto 0)  & reg_data(15 downto 8) & reg_data(23 downto 16) & reg_data(31 downto 24) when '0',  -- SWAP1
                   reg_data(15 downto 8) & reg_data(7 downto 0)  & reg_data(31 downto 24) & reg_data(23 downto 16) when '1';  -- SWAP2

    -- Lecture depuis Nios II
    process(chipselect, read, address, reg_out, reg_data, reg_mode)
    begin
        if chipselect = '1' and read = '1' then
            case address is
                when "00" => readdata <= reg_data;
                when "01" => readdata <= (31 downto 1 => '0') & reg_mode;
                when "10" => readdata <= reg_out;
                when others => readdata <= (others => '0');
            end case;
        else
            readdata <= (others => '0');
        end if;
    end process;

end architecture;