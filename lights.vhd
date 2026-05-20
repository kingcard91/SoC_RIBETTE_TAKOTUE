LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY lights IS
    PORT (
        CLOCK_50 : IN STD_LOGIC;
        KEY      : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        SW       : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        LED      : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);

        -- SDRAM
        DRAM_CLK   : OUT STD_LOGIC;
        DRAM_CKE   : OUT STD_LOGIC;
        DRAM_ADDR  : OUT STD_LOGIC_VECTOR(12 DOWNTO 0);
        DRAM_BA    : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        DRAM_CS_N  : OUT STD_LOGIC;
        DRAM_CAS_N : OUT STD_LOGIC;
        DRAM_RAS_N : OUT STD_LOGIC;
        DRAM_WE_N  : OUT STD_LOGIC;
        DRAM_DQ    : INOUT STD_LOGIC_VECTOR(15 DOWNTO 0);
        DRAM_DQM   : OUT STD_LOGIC_VECTOR(1 DOWNTO 0)
    );
END lights;

ARCHITECTURE rtl OF lights IS

    -- Signaux internes
    SIGNAL reset_n_i           : STD_LOGIC;

    -- Signal pour sélectionner le mode de swap
    SIGNAL byte_shuffler_mode  : STD_LOGIC;

    -- Déclaration du composant Nios II
    COMPONENT nios_system IS
        PORT (
            reset_reset_n    : IN  STD_LOGIC;
            switches_export  : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
            leds_export      : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
            clk_clk          : IN  STD_LOGIC;

            sdram_wire_addr  : OUT STD_LOGIC_VECTOR(12 DOWNTO 0);
            sdram_wire_ba    : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
            sdram_wire_cas_n : OUT STD_LOGIC;
            sdram_wire_cke   : OUT STD_LOGIC;
            sdram_wire_cs_n  : OUT STD_LOGIC;
            sdram_wire_dq    : INOUT STD_LOGIC_VECTOR(15 DOWNTO 0);
            sdram_wire_dqm   : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
            sdram_wire_ras_n : OUT STD_LOGIC;
            sdram_wire_we_n  : OUT STD_LOGIC
        );
    END COMPONENT;

    -- Déclaration du composant Byte Shuffler (32 bits)
    COMPONENT byte_shuffler IS
        PORT (
            clk        : IN  STD_LOGIC;
            reset_n    : IN  STD_LOGIC;
            chipselect : IN  STD_LOGIC;
            write      : IN  STD_LOGIC;
            writedata  : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
            read       : IN  STD_LOGIC;
            readdata   : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
            address    : IN  STD_LOGIC_VECTOR(1 DOWNTO 0)
        );
    END COMPONENT;

BEGIN

    -- Reset simple sur KEY(0)
    PROCESS(CLOCK_50)
    BEGIN
        IF rising_edge(CLOCK_50) THEN
            reset_n_i <= KEY(0);
        END IF;
    END PROCESS;

    -- Mode sélectionnable via SW0
    byte_shuffler_mode <= SW(0);

    -- Instance Nios II
    u0 : nios_system
        PORT MAP (
            reset_reset_n    => reset_n_i,
            switches_export  => SW,
            leds_export      => LED,
            clk_clk          => CLOCK_50,
            sdram_wire_addr  => DRAM_ADDR,
            sdram_wire_ba    => DRAM_BA,
            sdram_wire_cas_n => DRAM_CAS_N,
            sdram_wire_cke   => DRAM_CKE,
            sdram_wire_cs_n  => DRAM_CS_N,
            sdram_wire_dq    => DRAM_DQ,
            sdram_wire_dqm   => DRAM_DQM,
            sdram_wire_ras_n => DRAM_RAS_N,
            sdram_wire_we_n  => DRAM_WE_N
        );

    -- Instance Byte Shuffler
    byte_shuffle_inst : byte_shuffler
        PORT MAP (
            clk        => CLOCK_50,
            reset_n    => reset_n_i,
            chipselect => '1',               -- Toujours actif pour test
            write      => '0',               -- Piloté depuis Nios II
            read       => '0',               -- Piloté depuis Nios II
            writedata  => (others => '0'),   -- Remplir depuis Nios II
            readdata   => open,              -- Connecter si tu veux voir le résultat direct
            address    => (0 => byte_shuffler_mode, 1 => '0') -- Sélection mode
        );

    -- SDRAM cadencé sur l’horloge principale
    DRAM_CLK <= CLOCK_50;

END rtl;