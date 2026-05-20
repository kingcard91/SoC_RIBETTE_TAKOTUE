LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

ENTITY lights IS
    PORT (
        CLOCK_50 : IN STD_LOGIC;
        KEY      : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        SW       : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        LED      : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);

        -- SDRAM
        DRAM_CLK   : OUT   STD_LOGIC;
        DRAM_CKE   : OUT   STD_LOGIC;
        DRAM_ADDR  : OUT   STD_LOGIC_VECTOR(12 DOWNTO 0);
        DRAM_BA    : OUT   STD_LOGIC_VECTOR(1 DOWNTO 0);
        DRAM_CS_N  : OUT   STD_LOGIC;
        DRAM_CAS_N : OUT   STD_LOGIC;
        DRAM_RAS_N : OUT   STD_LOGIC;
        DRAM_WE_N  : OUT   STD_LOGIC;
        DRAM_DQ    : INOUT STD_LOGIC_VECTOR(15 DOWNTO 0);
        DRAM_DQM   : OUT   STD_LOGIC_VECTOR(1 DOWNTO 0);

        -- Moteurs CuteCar
        MTRR_P : OUT STD_LOGIC;
        MTRR_N : OUT STD_LOGIC;
        MTRL_P : OUT STD_LOGIC;
        MTRL_N : OUT STD_LOGIC;

        MTR_Sleep_n : OUT STD_LOGIC;
        MTR_Fault_n : IN  STD_LOGIC;

        -- ADC / capteurs sol
        ADC_CLK    : OUT STD_LOGIC;
        ADC_SDO    : IN  STD_LOGIC;
        ADC_CONVST : OUT STD_LOGIC;
        ADC_SDI    : OUT STD_LOGIC
    );
END lights;

ARCHITECTURE rtl OF lights IS

    COMPONENT nios_system IS
        PORT (
            reset_reset_n       : IN    STD_LOGIC;
            switches_export     : IN    STD_LOGIC_VECTOR(7 DOWNTO 0);
            leds_export         : OUT   STD_LOGIC_VECTOR(7 DOWNTO 0);
            clk_clk             : IN    STD_LOGIC;

            sdram_wire_addr     : OUT   STD_LOGIC_VECTOR(12 DOWNTO 0);
            sdram_wire_ba       : OUT   STD_LOGIC_VECTOR(1 DOWNTO 0);
            sdram_wire_cas_n    : OUT   STD_LOGIC;
            sdram_wire_cke      : OUT   STD_LOGIC;
            sdram_wire_cs_n     : OUT   STD_LOGIC;
            sdram_wire_dq       : INOUT STD_LOGIC_VECTOR(15 DOWNTO 0);
            sdram_wire_dqm      : OUT   STD_LOGIC_VECTOR(1 DOWNTO 0);
            sdram_wire_ras_n    : OUT   STD_LOGIC;
            sdram_wire_we_n     : OUT   STD_LOGIC;

            dc_motor_p_r_export : OUT   STD_LOGIC;
            dc_motor_n_r_export : OUT   STD_LOGIC;
            dc_motor_p_l_export : OUT   STD_LOGIC;
            dc_motor_n_l_export : OUT   STD_LOGIC;

            adc_clk_export      : OUT   STD_LOGIC;
            adc_sdo_export      : IN    STD_LOGIC;
            adc_convst_export   : OUT   STD_LOGIC;
            adc_sdi_export      : OUT   STD_LOGIC
        );
    END COMPONENT;

BEGIN

    u0 : nios_system
        PORT MAP (
            reset_reset_n       => KEY(0),
            switches_export     => SW,
            leds_export         => LED,
            clk_clk             => CLOCK_50,

            sdram_wire_addr     => DRAM_ADDR,
            sdram_wire_ba       => DRAM_BA,
            sdram_wire_cas_n    => DRAM_CAS_N,
            sdram_wire_cke      => DRAM_CKE,
            sdram_wire_cs_n     => DRAM_CS_N,
            sdram_wire_dq       => DRAM_DQ,
            sdram_wire_dqm      => DRAM_DQM,
            sdram_wire_ras_n    => DRAM_RAS_N,
            sdram_wire_we_n     => DRAM_WE_N,

            dc_motor_p_r_export => MTRR_P,
            dc_motor_n_r_export => MTRR_N,
            dc_motor_p_l_export => MTRL_P,
            dc_motor_n_l_export => MTRL_N,

            adc_clk_export      => ADC_CLK,
            adc_sdo_export      => ADC_SDO,
            adc_convst_export   => ADC_CONVST,
            adc_sdi_export      => ADC_SDI
        );

    -- SDRAM clock simple
    DRAM_CLK <= CLOCK_50;

    -- Activation driver moteur
    MTR_Sleep_n <= '1';

END rtl;