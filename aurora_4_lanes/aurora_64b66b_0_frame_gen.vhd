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
--  FRAME GEN
--
--
--  Description: This module is a pattern generator to test the Aurora
--               designs in hardware. It generates data and passes it 
--               through the Aurora channel. 
----------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY aurora_64b66b_0_FRAME_GEN IS
  GENERIC (
    DATA_WIDTH      : integer := 4*64; --  64   DATA bus width
    STRB_WIDTH      : integer := 4*8;  --  8   STROBE bus width
    AURORA_LANES    : integer := 4;    --  1
    LANE_DATA_WIDTH : integer := 4*64; --  AURORA_LANES * 64
    REM_BUS         : integer := 5;    --  3
    REM_BITS_MAX    : integer := 32    --  LANE_DATA_WIDTH/8
  );
  PORT (
    -- System interface
    USER_CLK   : in  STD_LOGIC;
    RESET      : in  STD_LOGIC;
    CHANNEL_UP : in  STD_LOGIC;
    -- PDU interface
    AXI4_S_IP_TREADY : in  STD_LOGIC;
    AXI4_S_OP_TDATA  : out STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
    AXI4_S_OP_TVALID : out STD_LOGIC;
    AXI4_S_OP_TKEEP  : out STD_LOGIC_VECTOR(STRB_WIDTH-1 downto 0);
    AXI4_S_OP_TLAST  : out STD_LOGIC 
  );
END aurora_64b66b_0_FRAME_GEN;

ARCHITECTURE bh OF aurora_64b66b_0_FRAME_GEN IS
-- External Register Declarations
  signal s_AXI4_S_OP_TDATA : STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0); 
  --signal s_AXI4_S_OP_TVALID : STD_LOGIC; 
  --signal s_AXI4_S_OP_TLAST : STD_LOGIC; 
  --signal s_AXI4_S_OP_TKEEP : STD_LOGIC_VECTOR(STRB_WIDTH-1 downto 0);
-- Wire declarations
  signal ifg_done_c : STD_LOGIC; 
  signal ifg_done_c_next : STD_LOGIC; 
  -- Next state signals for one-hot state machine
  signal next_idle_c : STD_LOGIC; 
  signal next_single_cycle_frame_c : STD_LOGIC; 
  signal next_sof_c : STD_LOGIC; 
  signal next_data_cycle_c : STD_LOGIC; 
  signal next_eof_c : STD_LOGIC; 

  signal ufc_tx_src_rdy_int : STD_LOGIC;

  signal reset_i : STD_LOGIC;
  signal RESET_ii : STD_LOGIC;

-- Internal Register Declarations
  signal pdu_lfsr_r  : STD_LOGIC_VECTOR(15 downto 0); 
  signal ifg_size_r  : UNSIGNED(7 downto 0); 
  signal first_tx_dst_rdy_n : STD_LOGIC;
  signal frame_size_r : UNSIGNED(3 downto 0); 
  signal bytes_sent_r : UNSIGNED(3 downto 0); 
  signal rem_r  : UNSIGNED(STRB_WIDTH-1 downto 0);
  signal rem_r2 : UNSIGNED(STRB_WIDTH-1 downto 0);

-- State registers for one-hot state machine
  signal idle_r : STD_LOGIC; 
  signal single_cycle_frame_r : STD_LOGIC; 
  signal sof_r : STD_LOGIC; 
  signal data_cycle_r : STD_LOGIC; 
  signal eof_r : STD_LOGIC; 

BEGIN
  RESET_ii <= RESET;
  -- resetUFC <= reset_i; 

  reset_i <= RESET OR (NOT CHANNEL_UP); 

  -- Generate random data using XNOR feedback LFSR
  p_lsfr: PROCESS(USER_CLK)
  BEGIN 
    IF rising_edge(USER_CLK) THEN
      IF (reset_i = '1') THEN
        pdu_lfsr_r <= x"abcd";  -- random seed value
      ELSE 
        IF ( ((AXI4_S_IP_TREADY) AND (NOT idle_r)) = '1') THEN
          --pdu_lfsr_r <= (NOT (pdu_lfsr_r(3) XOR pdu_lfsr_r(12) XOR pdu_lfsr_r(14) XOR pdu_lfsr_r(15)) & pdu_lfsr_r(14 downto 0));
          pdu_lfsr_r <= (NOT (pdu_lfsr_r(12) XOR pdu_lfsr_r(3) XOR pdu_lfsr_r(1) XOR pdu_lfsr_r(0)) & pdu_lfsr_r(15 downto 1));
        END IF;
      END IF;
    END IF;
  END PROCESS;
  
  -- Connect TX_D to the pdu_lfsr_r register
  -- @todo: make parametrizable 
  -- pdu_lfsr_r[16] ==> TDATA [ 64 * LANES ]
  --  AXI4_S_OP_TDATA <= {AURORA_LANES*4{pdu_lfsr_r}};
  
  -- 1 lane:
  -- s_AXI4_S_OP_TDATA <= (pdu_lfsr_r & pdu_lfsr_r & pdu_lfsr_r & pdu_lfsr_r);
  -- 4 lane:
  s_AXI4_S_OP_TDATA <= (pdu_lfsr_r & pdu_lfsr_r & pdu_lfsr_r & pdu_lfsr_r) & 
                       (pdu_lfsr_r & pdu_lfsr_r & pdu_lfsr_r & pdu_lfsr_r) & 
                       (pdu_lfsr_r & pdu_lfsr_r & pdu_lfsr_r & pdu_lfsr_r) & 
                       (pdu_lfsr_r & pdu_lfsr_r & pdu_lfsr_r & pdu_lfsr_r);

  AXI4_S_OP_TDATA <= s_AXI4_S_OP_TDATA;
  --out_reg : PROCESS(USER_CLK)
  --BEGIN
  --  IF rising_edge(USER_CLK) THEN
  --    AXI4_S_OP_TDATA <= s_AXI4_S_OP_TDATA;
  --  END IF;
  --END PROCESS;

  --Use a freerunning counter to determine the IFG
  p_ifg_cnt : PROCESS(USER_CLK)
  BEGIN
    IF rising_edge(USER_CLK) THEN
      IF (RESET_ii = '1') THEN
        ifg_size_r <= x"00";
      ELSE
        ifg_size_r <= ifg_size_r + 1;
      END IF;
    END IF;
  END PROCESS;

  -- IFG is done when ifg_size register is 0
  ifg_done_c_next <= '0' WHEN (ifg_size_r(2) AND ifg_size_r(1) AND ifg_size_r(0)) = '0' ELSE '1';
  p_ifg_done : PROCESS(USER_CLK)
  BEGIN
    IF rising_edge(USER_CLK) THEN
      IF (RESET_ii = '1') THEN
        ifg_done_c <= '1';
      ELSE
        ifg_done_c <= ifg_done_c_next;
      END IF;
    END IF;
  END PROCESS;

  p_rem : PROCESS(USER_CLK)
  BEGIN
    IF rising_edge(USER_CLK) THEN
      IF (RESET_ii = '1') THEN
        rem_r  <= (others => '1');
        rem_r2 <= (others => '1');
      ELSE
        IF (rem_r2 = 0) THEN
          rem_r2 <= (others => '1');
        ELSIF (next_eof_c = '1') OR (next_single_cycle_frame_c = '1') THEN
          rem_r  <= rem_r2;
          rem_r2 <= rem_r2(STRB_WIDTH-2 downto 0) & '0';
        ELSE
          rem_r <= (others => '1');
        END IF;
      END IF;
    END IF;
  END PROCESS;

  p_tkeep : PROCESS(USER_CLK)
  BEGIN
    IF rising_edge(USER_CLK) THEN
      AXI4_S_OP_TKEEP <= std_logic_vector(rem_r);
    END IF;
  END PROCESS;

  -- Use a counter to determine the size of the next frame to send
  p_frame_cnt : PROCESS(USER_CLK)
  BEGIN
    IF rising_edge(USER_CLK) THEN
      IF (RESET_ii = '1') THEN
        frame_size_r <= to_unsigned(0, 4);
      ELSIF ((single_cycle_frame_r) OR (eof_r)) = '1' THEN
        frame_size_r <= frame_size_r + 1;
      END IF;
    END IF;
  END PROCESS;
  -- Use a second counter to determine how many bytes of the frame have already been sent
  p_byte_cnt : PROCESS(USER_CLK)
  BEGIN
    IF rising_edge(USER_CLK) THEN
      IF (RESET_ii = '1') THEN
        bytes_sent_r <= to_unsigned(0, 4);
      ELSIF (sof_r = '1') THEN
        bytes_sent_r <= to_unsigned(1, 4);
      ELSIF (((AXI4_S_IP_TREADY) AND (NOT idle_r)) = '1') THEN
        bytes_sent_r <= bytes_sent_r + 1;
      END IF;
    END IF;
  END PROCESS;

  --_____________________________ Framing State machine______________________________ 
  --Use a state machine to determine whether to start a frame, end a frame, send
  --data or send nothing
   
  --State registers for 1-hot state machine
  proc_5 : PROCESS(USER_CLK)
  BEGIN
    IF rising_edge(USER_CLK) THEN
      IF(reset_i = '1') THEN
        idle_r               <= '1';
        single_cycle_frame_r <= '0';
        sof_r                <= '0';
        data_cycle_r         <= '0';
        eof_r                <= '0';
      ELSIF(AXI4_S_IP_TREADY = '1') THEN
        idle_r               <= next_idle_c;
        single_cycle_frame_r <= next_single_cycle_frame_c;
        sof_r                <= next_sof_c;
        data_cycle_r         <= next_data_cycle_c;
        eof_r                <= next_eof_c;
      END IF;
    END IF;
  END PROCESS;

  -- Nextstate logic for 1-hot state machine
  next_idle_c <= (NOT ifg_done_c) AND 
                    (single_cycle_frame_r OR eof_r OR idle_r);
  next_single_cycle_frame_c <= '1' WHEN ((ifg_done_c='1') AND (frame_size_r=0)) AND 
                    ((idle_r='1') OR (single_cycle_frame_r='1') OR (eof_r='1')) ELSE '0';
  next_sof_c <= '1' WHEN ((ifg_done_c='1') AND (frame_size_r /= 0)) AND
                    ((idle_r='1') OR (single_cycle_frame_r='1') OR (eof_r='1')) ELSE '0';
  next_data_cycle_c <= '1' WHEN (frame_size_r /= unsigned(bytes_sent_r)) AND
                    ((sof_r='1') OR (data_cycle_r='1')) ELSE '0';
  next_eof_c <= '1' WHEN (frame_size_r = unsigned(bytes_sent_r)) AND
                    ((sof_r='1') OR (data_cycle_r='1')) ELSE '0';

  -- Output logic for 1-hot state machine
  p_state_out : PROCESS(USER_CLK)
  BEGIN
    IF rising_edge(USER_CLK) THEN
      IF(reset_i = '1') THEN
        AXI4_S_OP_TLAST  <= '0';
        AXI4_S_OP_TVALID <= '0';
      ELSIF(AXI4_S_IP_TREADY = '1') THEN
        AXI4_S_OP_TLAST  <= (eof_r OR single_cycle_frame_r);
        AXI4_S_OP_TVALID <= (sof_r OR single_cycle_frame_r OR (NOT idle_r));
      END IF;
    END IF;
  END PROCESS;

  p_first_tx : PROCESS(USER_CLK)
  BEGIN
    IF rising_edge(USER_CLK) THEN
      IF((reset_i = '1') OR (CHANNEL_UP = '0')) THEN
        first_tx_dst_rdy_n <= '0'; 
      ELSIF(((AXI4_S_IP_TREADY) AND (CHANNEL_UP)) = '1') THEN
        first_tx_dst_rdy_n <= '1'; 
      END IF;
    END IF;
  END PROCESS;

END bh;
