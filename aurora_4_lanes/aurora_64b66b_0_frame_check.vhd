----------------------------------------------------------------------------------
--
-- Project:  Aurora 64B/66B 
-- Company:  Xilinx
--
--
--
-- (c) Copyright 2008 - 2009 Xilinx, Inc. All rights reserved.
--
-- This file contains confidential and proprietary information
-- of Xilinx, Inc. and is protected under U.S. and
-- international copyright and other intellectual property
-- laws.
--
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- Xilinx, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) Xilinx shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or Xilinx had been advised of the
-- possibility of the same.
--
-- CRITICAL APPLICATIONS
-- Xilinx products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of Xilinx products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES.
 
--
--
----------------------------------------------------------------------------------
--
--  FRAME CHECK
--
--
--
--  Description: This module is a  pattern checker to test the Aurora
--               designs in hardware. The frames generated by FRAME_GEN
--               pass through the Aurora channel and arrive at the frame checker 
--               through the RX User interface. Every time an error is found in
--               the data recieved, the error count is incremented until it 
--               reaches its max value.
----------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE IEEE.STD_LOGIC_MISC.ALL;

ENTITY aurora_64b66b_0_FRAME_CHECK IS
  GENERIC (
    DATA_WIDTH      : integer := 4*64; --  64   DATA bus width
    STRB_WIDTH      : integer := 4*8;  --  8   STROBE bus width
    AURORA_LANES    : integer := 4;    --  1
    LANE_DATA_WIDTH : integer := 4*64; --  AURORA_LANES * 64
    REM_BUS         : integer := 5;    --  3
    REM_BITS_MAX    : integer := 32    --  LANE_DATA_WIDTH/8
  );
  PORT ( 
    -- System Interface
    USER_CLK       : in  STD_LOGIC;
    RESET          : in  STD_LOGIC;
    CHANNEL_UP     : in  STD_LOGIC;
    DATA_ERR_COUNT : out STD_LOGIC_VECTOR(7 downto 0);
    DATA_OK_COUNT  : out STD_LOGIC_VECTOR(7 downto 0);
    -- User Interface
    RX_D_R_debug  : out  STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
    pdu_cmp_data_r1_debug  : out  STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
    AXI4_S_IP_TX_TDATA  : in  STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
    AXI4_S_IP_TX_TVALID : in  STD_LOGIC;
    AXI4_S_IP_TX_TLAST  : in  STD_LOGIC;
    AXI4_S_IP_TX_TKEEP  : in  STD_LOGIC_VECTOR(STRB_WIDTH-1 downto 0);
    AXI4_S_IP_TX_TREADY : out STD_LOGIC
  );
END aurora_64b66b_0_FRAME_CHECK;


ARCHITECTURE bh OF aurora_64b66b_0_FRAME_CHECK IS
  signal pdu_lfsr_r     : STD_LOGIC_VECTOR(15 downto 0);
  signal pdu_cmp_data_r : STD_LOGIC_VECTOR(LANE_DATA_WIDTH-1 downto 0);
  signal RX_D_R         : STD_LOGIC_VECTOR(LANE_DATA_WIDTH-1 downto 0);
  signal KEEP_CMP       : STD_LOGIC_VECTOR(LANE_DATA_WIDTH-1 downto 0);
  signal pdu_data_valid_r : STD_LOGIC;
  signal pdu_in_frame_r   : STD_LOGIC;
  signal pdu_err_detected_c : STD_LOGIC_VECTOR(AURORA_LANES-1 downto 0);
  signal pdu_cmp_data_r1    : STD_LOGIC_VECTOR(LANE_DATA_WIDTH-1 downto 0);
  signal data_err_c         : STD_LOGIC_VECTOR(AURORA_LANES-1 downto 0);

  signal RX_D_R2            : STD_LOGIC_VECTOR(LANE_DATA_WIDTH-1 downto 0);
  signal RX_REM_R2          : STD_LOGIC_VECTOR(STRB_WIDTH-1 downto 0);
  signal RX_REM_R3          : STD_LOGIC_VECTOR(STRB_WIDTH-1 downto 0);
  signal RX_EOF_N_R2        : STD_LOGIC;
  signal RX_SRC_RDY_N_R2    : STD_LOGIC;
 
  signal pdu_in_frame_c    : STD_LOGIC;
  signal pdu_lfsr_concat_w : STD_LOGIC_VECTOR(LANE_DATA_WIDTH-1 downto 0);
  signal pdu_data_valid_c  : STD_LOGIC;
 
  signal reset_i  : STD_LOGIC; 
  signal RESET_ii : STD_LOGIC; 

  signal AXI4_S_IP_TX_TDATA_i : STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
  signal AXI4_S_IP_TX_TKEEP_i : STD_LOGIC_VECTOR(STRB_WIDTH-1 downto 0);
  signal s_DATA_ERR_COUNT     : unsigned(7 downto 0);
  signal s_DATA_OK_COUNT      : unsigned(7 downto 0);
  
BEGIN
  AXI4_S_IP_TX_TDATA_i <= AXI4_S_IP_TX_TDATA;
  AXI4_S_IP_TX_TKEEP_i <= AXI4_S_IP_TX_TKEEP;

  reset_i <= RESET OR (NOT CHANNEL_UP);
  -- resetUFC <= reset_i; 
  RESET_ii <= RESET ; 

--****************************PDU Data Genetration & Checking**********************
-- Generate the PDU data using LFSR for data comparision
  p_lsfr: PROCESS(USER_CLK)
  BEGIN 
    IF rising_edge(USER_CLK) THEN
      IF (reset_i = '1') THEN
        pdu_lfsr_r <= x"D5E6";  -- random seed value
      ELSIF (pdu_data_valid_c = '1') THEN
        --pdu_lfsr_r <= (NOT (pdu_lfsr_r(3) XOR pdu_lfsr_r(12) XOR pdu_lfsr_r(14) XOR pdu_lfsr_r(15)) & pdu_lfsr_r(14 downto 0));
        pdu_lfsr_r <= (NOT (pdu_lfsr_r(12) XOR pdu_lfsr_r(3) XOR pdu_lfsr_r(1) XOR pdu_lfsr_r(0)) & pdu_lfsr_r(15 downto 1));
      END IF;
    END IF;
  END PROCESS;
  
  -- @todo: make this paremetrizable
  -- pdu_lfsr_r[16] ==> concat_w [ 64 * LANES ]
  --  pdu_lfsr_concat_w <= {AURORA_LANES*4{pdu_lfsr_r}};

  -- 1 lane:
  -- pdu_lfsr_concat_w <= (pdu_lfsr_r & pdu_lfsr_r & pdu_lfsr_r & pdu_lfsr_r);
  -- 4 lane:
  pdu_lfsr_concat_w <= (pdu_lfsr_r & pdu_lfsr_r & pdu_lfsr_r & pdu_lfsr_r) & 
                       (pdu_lfsr_r & pdu_lfsr_r & pdu_lfsr_r & pdu_lfsr_r) & 
                       (pdu_lfsr_r & pdu_lfsr_r & pdu_lfsr_r & pdu_lfsr_r) & 
                       (pdu_lfsr_r & pdu_lfsr_r & pdu_lfsr_r & pdu_lfsr_r);


  p_axi_in: PROCESS(USER_CLK)
  BEGIN 
    IF rising_edge(USER_CLK) THEN
      RX_D_R2         <= AXI4_S_IP_TX_TDATA_i;
      -- RX_D_R2         <= AXI4_S_IP_TX_TDATA_i & AXI4_S_IP_TX_TDATA_i & AXI4_S_IP_TX_TDATA_i & AXI4_S_IP_TX_TDATA_i;
      RX_REM_R2       <= AXI4_S_IP_TX_TKEEP_i; 
      RX_REM_R3       <= AXI4_S_IP_TX_TKEEP_i;
      RX_EOF_N_R2     <= NOT AXI4_S_IP_TX_TLAST; 
      RX_SRC_RDY_N_R2 <= NOT AXI4_S_IP_TX_TVALID; 
    END IF;
  END PROCESS;
  --______________________________ Capture incoming data ___________________________    
  --PDU data is valid when RX_SRC_RDY_N_R2 is asserted
  -- pdu_data_valid_c <= (pdu_in_frame_c = '1) AND (RX_SRC_RDY_N_R2 = '0');
  pdu_data_valid_c <= (pdu_in_frame_c) AND (NOT RX_SRC_RDY_N_R2);
 
  -- PDU data is in a frame if it is a single cycle frame or a multi_cycle frame has started
  -- pdu_in_frame_c <= (pdu_in_frame_r = '1') OR (RX_SRC_RDY_N_R2 = '0');
  pdu_in_frame_c <= (pdu_in_frame_r) OR (NOT RX_SRC_RDY_N_R2);
 
  -- Start a multicycle PDU frame when a frame starts without ending on the same cycle. End 
  -- the frame when an RX_EOF_N_R2 is detected
  p_pdu_frame: PROCESS(USER_CLK)
  BEGIN 
    IF rising_edge(USER_CLK) THEN
      IF (RESET_ii = '1') THEN
        pdu_in_frame_r <= '0';
      ELSIF ( ((NOT pdu_in_frame_r) AND (NOT RX_SRC_RDY_N_R2) AND (RX_EOF_N_R2)) = '1' ) THEN
        pdu_in_frame_r <= '1';
      ELSIF ( ((pdu_in_frame_r) AND (NOT RX_SRC_RDY_N_R2) AND (NOT RX_EOF_N_R2)) = '1' ) THEN
        pdu_in_frame_r <= '0';
      END IF;
    END IF;
  END PROCESS;

  -- KEEP_CMP  ( 63 downto 0 )
  -- RX_REM_R2 (  1 downto 0 )
  -- 1 lane
  -- KEEP_CMP(63 downto 56) <= (others => RX_REM_R2( 0) );
  -- KEEP_CMP(55 downto 48) <= (others => RX_REM_R2( 1) );
  -- KEEP_CMP(47 downto 40) <= (others => RX_REM_R2( 2) );
  -- KEEP_CMP(39 downto 32) <= (others => RX_REM_R2( 3) );
  -- KEEP_CMP(31 downto 24) <= (others => RX_REM_R2( 4) );
  -- KEEP_CMP(23 downto 16) <= (others => RX_REM_R2( 5) );
  -- KEEP_CMP(15 downto  8) <= (others => RX_REM_R2( 6) );
  -- KEEP_CMP( 7 downto  0) <= (others => RX_REM_R2( 7) );
  -- 4 lanes
  KEEP_CMP(255 downto 248) <= (others => RX_REM_R2( 0) );
  KEEP_CMP(247 downto 240) <= (others => RX_REM_R2( 1) );
  KEEP_CMP(239 downto 232) <= (others => RX_REM_R2( 2) );
  KEEP_CMP(231 downto 224) <= (others => RX_REM_R2( 3) );
  KEEP_CMP(223 downto 216) <= (others => RX_REM_R2( 4) );
  KEEP_CMP(215 downto 208) <= (others => RX_REM_R2( 5) );
  KEEP_CMP(207 downto 200) <= (others => RX_REM_R2( 6) );
  KEEP_CMP(199 downto 192) <= (others => RX_REM_R2( 7) );
  
  KEEP_CMP(191 downto 184) <= (others => RX_REM_R2( 8) );
  KEEP_CMP(183 downto 176) <= (others => RX_REM_R2( 9) );
  KEEP_CMP(175 downto 168) <= (others => RX_REM_R2(10) );
  KEEP_CMP(167 downto 160) <= (others => RX_REM_R2(11) );
  KEEP_CMP(159 downto 152) <= (others => RX_REM_R2(12) );
  KEEP_CMP(151 downto 144) <= (others => RX_REM_R2(13) );
  KEEP_CMP(143 downto 136) <= (others => RX_REM_R2(14) );
  KEEP_CMP(135 downto 128) <= (others => RX_REM_R2(15) );
  
  KEEP_CMP(127 downto 120) <= (others => RX_REM_R2(16) );
  KEEP_CMP(119 downto 112) <= (others => RX_REM_R2(17) );
  KEEP_CMP(111 downto 104) <= (others => RX_REM_R2(18) );
  KEEP_CMP(103 downto  96) <= (others => RX_REM_R2(19) );
  KEEP_CMP( 95 downto  88) <= (others => RX_REM_R2(20) );
  KEEP_CMP( 87 downto  80) <= (others => RX_REM_R2(21) );
  KEEP_CMP( 79 downto  72) <= (others => RX_REM_R2(22) );
  KEEP_CMP( 71 downto  64) <= (others => RX_REM_R2(23) );
  
  KEEP_CMP( 63 downto  56) <= (others => RX_REM_R2(24) );
  KEEP_CMP( 55 downto  48) <= (others => RX_REM_R2(25) );
  KEEP_CMP( 47 downto  40) <= (others => RX_REM_R2(26) );
  KEEP_CMP( 39 downto  32) <= (others => RX_REM_R2(27) );
  KEEP_CMP( 31 downto  24) <= (others => RX_REM_R2(28) );
  KEEP_CMP( 23 downto  16) <= (others => RX_REM_R2(29) );
  KEEP_CMP( 15 downto   8) <= (others => RX_REM_R2(30) );
  KEEP_CMP(  7 downto   0) <= (others => RX_REM_R2(31) );
-- Register and decode the RX_D_R2 data with RX_REM_R2 bus
  p_rxd: PROCESS(USER_CLK)
  BEGIN 
    IF rising_edge(USER_CLK) THEN
      IF ((RX_EOF_N_R2 = '0') AND (RX_SRC_RDY_N_R2 = '0')) THEN
        RX_D_R <=  RX_D_R2 AND KEEP_CMP;
      ELSIF (RX_SRC_RDY_N_R2 = '0') THEN
        RX_D_R <= RX_D_R2;
      END IF;
    END IF;
  END PROCESS;
  
  -- Calculate the expected PDU data 
  p_expected: PROCESS(USER_CLK)
  BEGIN 
    IF rising_edge(USER_CLK) THEN
      IF (reset_i = '1') THEN
        --pdu_cmp_data_r <= (x"D5E6") & (x"D5E6") & (x"D5E6") & (x"D5E6");
        pdu_cmp_data_r <= (x"D5E6") & (x"D5E6") & (x"D5E6") & (x"D5E6") &  -- {AURORA_LANES*4{16'hD5E6}};
                          (x"D5E6") & (x"D5E6") & (x"D5E6") & (x"D5E6") & 
                          (x"D5E6") & (x"D5E6") & (x"D5E6") & (x"D5E6") & 
                          (x"D5E6") & (x"D5E6") & (x"D5E6") & (x"D5E6");
      ELSIF (pdu_data_valid_c = '1') THEN
        pdu_cmp_data_r <= pdu_lfsr_concat_w AND KEEP_CMP;
      END IF;
    END IF;
  END PROCESS;
  
  -- PDU Data in the pdu_cmp_data_r register is valid only if it was valid when captured and had no error
  p_validate: PROCESS(USER_CLK)
  BEGIN 
    IF rising_edge(USER_CLK) THEN
      IF (reset_i = '1') THEN
        pdu_data_valid_r <= '0';
      ELSE
        -- pdu_data_valid_r    <=  `DLY    pdu_data_valid_c && !pdu_err_detected_c;
        pdu_data_valid_r <= (pdu_data_valid_c) AND (NOT and_reduce(pdu_err_detected_c));
      END IF;
    END IF;
  END PROCESS;
  
  pdu_cmp_data_r1 <= pdu_cmp_data_r;
    
  data_err_c(0) <= '1' WHEN ( (pdu_data_valid_r = '1') AND ( unsigned(RX_D_R( 63 downto   0)) /= unsigned(pdu_cmp_data_r1( 63 downto   0))) ) ELSE '0';
  data_err_c(1) <= '1' WHEN ( (pdu_data_valid_r = '1') AND ( unsigned(RX_D_R(127 downto  64)) /= unsigned(pdu_cmp_data_r1(127 downto  64))) ) ELSE '0';
  data_err_c(2) <= '1' WHEN ( (pdu_data_valid_r = '1') AND ( unsigned(RX_D_R(191 downto 128)) /= unsigned(pdu_cmp_data_r1(191 downto 128))) ) ELSE '0';
  data_err_c(3) <= '1' WHEN ( (pdu_data_valid_r = '1') AND ( unsigned(RX_D_R(255 downto 192)) /= unsigned(pdu_cmp_data_r1(255 downto 192))) ) ELSE '0';

RX_D_R_debug <= RX_D_R;
pdu_cmp_data_r1_debug <= pdu_cmp_data_r1;

  -- An error is detected when LFSR generated PDU data from the pdu_cmp_data_r register, 
  -- does not match valid data from the RX_D port
  p_err_detect_reg: PROCESS(USER_CLK)
  BEGIN 
    IF rising_edge(USER_CLK) THEN
      pdu_err_detected_c <= data_err_c;
    END IF;
  END PROCESS;
  
  -- Compare the incoming PDU data with calculated expected PDU data.
  -- Increment the PDU ERR COUNTER if mismatch occurs
  -- Stop the PDU ERR COUNTER once it reaches its max value
  p_error_count: PROCESS(USER_CLK)
  BEGIN 
    IF rising_edge(USER_CLK) THEN
      IF (RESET_ii = '1') THEN
        s_DATA_ERR_COUNT <= (others => '0');
        s_DATA_OK_COUNT  <= (others => '0');
      ELSIF ( CHANNEL_UP = '0' ) THEN
        s_DATA_ERR_COUNT <= (others => '0');
        s_DATA_OK_COUNT  <= (others => '0');
      -- ELSIF ( and_reduce(std_logic_vector(s_DATA_ERR_COUNT)) = '1') THEN
      --  s_DATA_ERR_COUNT <= s_DATA_ERR_COUNT;
      ELSIF ( or_reduce(pdu_err_detected_c) = '1' ) THEN
        s_DATA_ERR_COUNT <= unsigned(s_DATA_ERR_COUNT) + 1;
      ELSE
        s_DATA_OK_COUNT <= unsigned(s_DATA_OK_COUNT) + 1;
      END IF;
    END IF;
  END PROCESS;
  DATA_ERR_COUNT <= std_logic_vector(s_DATA_ERR_COUNT);
  DATA_OK_COUNT  <= std_logic_vector(s_DATA_OK_COUNT);

END bh;

