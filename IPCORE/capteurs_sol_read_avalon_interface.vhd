LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY capteurs_sol_read_avalon_interface IS
    PORT (
        -- Clock Avalon / Qsys : 50 MHz
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

        -- Conduit ADC vers les pins physiques
        ADC_CONVST : OUT STD_LOGIC;
        ADC_SCK    : OUT STD_LOGIC;
        ADC_SDI    : OUT STD_LOGIC;
        ADC_SDO    : IN  STD_LOGIC
    );
END capteurs_sol_read_avalon_interface;

ARCHITECTURE rtl OF capteurs_sol_read_avalon_interface IS

    --------------------------------------------------------------------
    -- Clocks PLL
    --------------------------------------------------------------------
    SIGNAL clk_adc_40m : STD_LOGIC;
    SIGNAL clk_slow_2k : STD_LOGIC;

    --------------------------------------------------------------------
    -- Commandes côté Avalon 50 MHz
    --------------------------------------------------------------------
    SIGNAL capture_req_50 : STD_LOGIC := '0';
    SIGNAL niveau_50      : STD_LOGIC_VECTOR(7 DOWNTO 0) := x"80";

    --------------------------------------------------------------------
    -- Synchronisation vers domaine ADC 40 MHz
    --------------------------------------------------------------------
    SIGNAL capture_sync_1 : STD_LOGIC := '0';
    SIGNAL capture_sync_2 : STD_LOGIC := '0';
    SIGNAL capture_sync_3 : STD_LOGIC := '0';
    SIGNAL data_capture_i : STD_LOGIC := '0';

    SIGNAL niveau_sync_1  : STD_LOGIC_VECTOR(7 DOWNTO 0) := x"80";
    SIGNAL niveau_sync_2  : STD_LOGIC_VECTOR(7 DOWNTO 0) := x"80";

    --------------------------------------------------------------------
    -- Données capteurs domaine 40 MHz
    --------------------------------------------------------------------
    SIGNAL data_ready_i   : STD_LOGIC;

    SIGNAL data0_i : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL data1_i : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL data2_i : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL data3_i : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL data4_i : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL data5_i : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL data6_i : STD_LOGIC_VECTOR(7 DOWNTO 0);

    SIGNAL vect_capt_i : STD_LOGIC_VECTOR(6 DOWNTO 0);

    --------------------------------------------------------------------
    -- Registres recopiés côté Avalon 50 MHz pour lecture Nios
    --------------------------------------------------------------------
    SIGNAL data_ready_50 : STD_LOGIC := '0';
    SIGNAL vect_capt_50  : STD_LOGIC_VECTOR(6 DOWNTO 0) := (OTHERS => '0');

    SIGNAL data0_50 : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL data1_50 : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL data2_50 : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL data3_50 : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL data4_50 : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL data5_50 : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL data6_50 : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');

    SIGNAL readdata_i : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');

    --------------------------------------------------------------------
    -- Composants
    --------------------------------------------------------------------
    COMPONENT pll_2freqs IS
        PORT (
            areset : IN  STD_LOGIC := '0';
            inclk0 : IN  STD_LOGIC := '0';
            c0     : OUT STD_LOGIC;
            c1     : OUT STD_LOGIC
        );
    END COMPONENT;

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

    --------------------------------------------------------------------
    -- PLL : 50 MHz vers 40 MHz + 2 kHz
    --------------------------------------------------------------------
    U_PLL : pll_2freqs
        PORT MAP (
            areset => NOT resetn,
            inclk0 => clock,
            c0     => clk_adc_40m,
            c1     => clk_slow_2k
        );

    --------------------------------------------------------------------
    -- Écriture Avalon côté Nios/Qsys 50 MHz
    --------------------------------------------------------------------
    PROCESS(clock)
    BEGIN
        IF rising_edge(clock) THEN
            IF resetn = '0' THEN
                capture_req_50 <= '0';
                niveau_50      <= x"80";
            ELSE
                -- par défaut : pas de demande
                capture_req_50 <= '0';

                IF chipselect = '1' AND write = '1' THEN
                    CASE address IS

                        -- Registre 0 :
                        -- bit 0 = lancer acquisition
                        -- bits 15..8 = seuil
                        WHEN "00" =>
                            IF byteenable(0) = '1' THEN
                                capture_req_50 <= writedata(0);
                            END IF;

                            IF byteenable(1) = '1' THEN
                                niveau_50 <= writedata(15 DOWNTO 8);
                            END IF;

                        WHEN OTHERS =>
                            NULL;
                    END CASE;
                END IF;
            END IF;
        END IF;
    END PROCESS;

    --------------------------------------------------------------------
    -- Passage de commande 50 MHz vers 40 MHz
    --------------------------------------------------------------------
    PROCESS(clk_adc_40m)
    BEGIN
        IF rising_edge(clk_adc_40m) THEN
            IF resetn = '0' THEN
                capture_sync_1 <= '0';
                capture_sync_2 <= '0';
                capture_sync_3 <= '0';
                data_capture_i <= '0';

                niveau_sync_1 <= x"80";
                niveau_sync_2 <= x"80";
            ELSE
                capture_sync_1 <= capture_req_50;
                capture_sync_2 <= capture_sync_1;
                capture_sync_3 <= capture_sync_2;

                -- impulsion 1 cycle à 40 MHz
                data_capture_i <= capture_sync_2 AND NOT capture_sync_3;

                niveau_sync_1 <= niveau_50;
                niveau_sync_2 <= niveau_sync_1;
            END IF;
        END IF;
    END PROCESS;

    --------------------------------------------------------------------
    -- Bloc spécialisé capteurs à 40 MHz
    --------------------------------------------------------------------
    U_CAPTEURS : capteurs_sol_seuil
        PORT MAP (
            clk          => clk_adc_40m,
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

            NIVEAU       => niveau_sync_2,
            vect_capt    => vect_capt_i,

            ADC_CONVSTr  => ADC_CONVST,
            ADC_SCK      => ADC_SCK,
            ADC_SDIr     => ADC_SDI,
            ADC_SDO      => ADC_SDO
        );

    --------------------------------------------------------------------
    -- Recopie des données vers le domaine Avalon 50 MHz
    -- On capture lorsque data_ready est à 1.
    --------------------------------------------------------------------
    PROCESS(clock)
    BEGIN
        IF rising_edge(clock) THEN
            IF resetn = '0' THEN
                data_ready_50 <= '0';
                vect_capt_50  <= (OTHERS => '0');

                data0_50 <= (OTHERS => '0');
                data1_50 <= (OTHERS => '0');
                data2_50 <= (OTHERS => '0');
                data3_50 <= (OTHERS => '0');
                data4_50 <= (OTHERS => '0');
                data5_50 <= (OTHERS => '0');
                data6_50 <= (OTHERS => '0');
            ELSE
                data_ready_50 <= data_ready_i;

                IF data_ready_i = '1' THEN
                    vect_capt_50 <= vect_capt_i;

                    data0_50 <= data0_i;
                    data1_50 <= data1_i;
                    data2_50 <= data2_i;
                    data3_50 <= data3_i;
                    data4_50 <= data4_i;
                    data5_50 <= data5_i;
                    data6_50 <= data6_i;
                END IF;
            END IF;
        END IF;
    END PROCESS;

    --------------------------------------------------------------------
    -- Lecture Avalon
    --------------------------------------------------------------------
    PROCESS(address, data_ready_50, vect_capt_50, niveau_50,
            data0_50, data1_50, data2_50, data3_50,
            data4_50, data5_50, data6_50)
    BEGIN
        CASE address IS

            -- offset 0 : status
            -- bit 0 = data_ready
            -- bits 14..8 = vect_capt
            -- bits 23..16 = seuil
            WHEN "00" =>
                readdata_i <= (OTHERS => '0');
                readdata_i(0)            <= data_ready_50;
                readdata_i(14 DOWNTO 8)  <= vect_capt_50;
                readdata_i(23 DOWNTO 16) <= niveau_50;

            -- offset 1 : data0 à data3
            WHEN "01" =>
                readdata_i <= data3_50 & data2_50 & data1_50 & data0_50;

            -- offset 2 : data4 à data6
            WHEN "10" =>
                readdata_i <= x"00" & data6_50 & data5_50 & data4_50;

            -- offset 3 : debug clock lente
            -- bit 0 = clk_slow_2k visible en lecture
            WHEN OTHERS =>
                readdata_i <= (OTHERS => '0');
                readdata_i(0) <= clk_slow_2k;

        END CASE;
    END PROCESS;

    readdata <= readdata_i;

END rtl;