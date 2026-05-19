LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY capteurs_sol_read_avalon_interface IS
    PORT (
        clock      : IN  STD_LOGIC;
        resetn     : IN  STD_LOGIC;

        -- Avalon-MM Slave
        address    : IN  STD_LOGIC_VECTOR(1 DOWNTO 0);
        read       : IN  STD_LOGIC;
        write      : IN  STD_LOGIC;
        chipselect : IN  STD_LOGIC;
        byteenable : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);
        writedata  : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
        readdata   : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);

        -- Conduit vers ADC LTC2308
        ADC_CONVST : OUT STD_LOGIC;
        ADC_SCK    : OUT STD_LOGIC;
        ADC_SDI    : OUT STD_LOGIC;
        ADC_SDO    : IN  STD_LOGIC
    );
END capteurs_sol_read_avalon_interface;

ARCHITECTURE rtl OF capteurs_sol_read_avalon_interface IS

    SIGNAL data_capture_i : STD_LOGIC := '0';
    SIGNAL data_ready_i   : STD_LOGIC;

    SIGNAL data0_i : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL data1_i : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL data2_i : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL data3_i : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL data4_i : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL data5_i : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL data6_i : STD_LOGIC_VECTOR(7 DOWNTO 0);

    SIGNAL vect_capt_i : STD_LOGIC_VECTOR(6 DOWNTO 0);
    SIGNAL niveau_i    : STD_LOGIC_VECTOR(7 DOWNTO 0) := x"80";

    SIGNAL readdata_i  : STD_LOGIC_VECTOR(31 DOWNTO 0);

    COMPONENT capteurs_sol_seuil IS
        PORT (
            clk          : IN  STD_LOGIC;
            reset_n      : IN  STD_LOGIC;
            data_capture : IN  STD_LOGIC;
            data_readyr  : OUT STD_LOGIC;

            data0r       : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
            data1r       : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
            data2r       : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
            data3r       : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
            data4r       : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
            data5r       : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
            data6r       : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);

            NIVEAU       : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
            vect_capt    : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);

            ADC_CONVSTr  : OUT STD_LOGIC;
            ADC_SCK      : OUT STD_LOGIC;
            ADC_SDIr     : OUT STD_LOGIC;
            ADC_SDO      : IN  STD_LOGIC
        );
    END COMPONENT;

BEGIN

    capteurs_inst : capteurs_sol_seuil
        PORT MAP (
            clk          => clock,
            reset_n      => resetn,
            data_capture => data_capture_i,
            data_readyr  => data_ready_i,

            data0r       => data0_i,
            data1r       => data1_i,
            data2r       => data2_i,
            data3r       => data3_i,
            data4r       => data4_i,
            data5r       => data5_i,
            data6r       => data6_i,

            NIVEAU       => niveau_i,
            vect_capt    => vect_capt_i,

            ADC_CONVSTr  => ADC_CONVST,
            ADC_SCK      => ADC_SCK,
            ADC_SDIr     => ADC_SDI,
            ADC_SDO      => ADC_SDO
        );

    PROCESS(clock)
    BEGIN
        IF rising_edge(clock) THEN
            IF resetn = '0' THEN
                data_capture_i <= '0';
                niveau_i       <= x"80";
            ELSE
                -- impulsion de capture par défaut à 0
                data_capture_i <= '0';

                IF chipselect = '1' AND write = '1' THEN
                    CASE address IS

                        -- Registre 0 : contrôle
                        -- bit 0 = lancer une acquisition
                        -- bits 15 downto 8 = seuil NIVEAU
                        WHEN "00" =>
                            IF byteenable(0) = '1' THEN
                                data_capture_i <= writedata(0);
                            END IF;

                            IF byteenable(1) = '1' THEN
                                niveau_i <= writedata(15 DOWNTO 8);
                            END IF;

                        WHEN OTHERS =>
                            NULL;

                    END CASE;
                END IF;
            END IF;
        END IF;
    END PROCESS;

    PROCESS(address, data_ready_i, vect_capt_i, niveau_i,
            data0_i, data1_i, data2_i, data3_i, data4_i, data5_i, data6_i)
    BEGIN
        CASE address IS

            -- Adresse base + 0x00
            -- Lecture état capteurs
            -- bit 0 = data_ready
            -- bits 14 downto 8 = vect_capt
            -- bits 23 downto 16 = seuil
            WHEN "00" =>
                readdata_i <= (OTHERS => '0');
                readdata_i(0)            <= data_ready_i;
                readdata_i(14 DOWNTO 8)  <= vect_capt_i;
                readdata_i(23 DOWNTO 16) <= niveau_i;

            -- Adresse base + 0x04
            -- valeurs analogiques capteurs 0 à 3
            WHEN "01" =>
                readdata_i <= data3_i & data2_i & data1_i & data0_i;

            -- Adresse base + 0x08
            -- valeurs analogiques capteurs 4 à 6
            WHEN "10" =>
                readdata_i <= x"00" & data6_i & data5_i & data4_i;

            -- Adresse base + 0x0C
            -- réservé/debug
            WHEN OTHERS =>
                readdata_i <= (OTHERS => '0');

        END CASE;
    END PROCESS;

    readdata <= readdata_i;

END rtl;