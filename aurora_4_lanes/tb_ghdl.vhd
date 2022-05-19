----------------------------------------------------------------------------------
-- Company: Linköping University LiU - ISY institute
-- Engineer: simbu448@student.liu.se
-- 
-- Create Date: 04/29/2022 02:31:03 PM
-- Design Name: 
-- Module Name: tb_ghdl - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: example design for aurora_64b66b with 4 lanes in VHDL
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------
library IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY tb_ghdl IS
  GENERIC (
    DATA_WIDTH      : integer := 4*64; --  AURORA_LANES * 64
    STRB_WIDTH      : integer := 4*8;  --  AURORA_LANES * 8
    AURORA_LANES    : integer := 4;    --  number of lanes
    LANE_DATA_WIDTH : integer := 4*64; --  AURORA_LANES * 64
    REM_BUS         : integer := 5;    --  2 + AURORA_LANES
    REM_BITS_MAX    : integer := 32    --  LANE_DATA_WIDTH / 8
  );
  END tb_ghdl;

  ARCHITECTURE Behavioral OF tb_ghdl IS

  CONSTANT clock_period : time := 5 ns;
  
  COMPONENT aurora_64b66b_0_FRAME_GEN IS
    PORT (
      -- System interface
      USER_CLK   : IN  STD_LOGIC;
      RESET      : IN  STD_LOGIC;
      CHANNEL_UP : IN  STD_LOGIC;
      -- PDU interface
      AXI4_S_IP_TREADY : IN  STD_LOGIC;
      AXI4_S_OP_TDATA  : OUT STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
      AXI4_S_OP_TVALID : OUT STD_LOGIC;
      AXI4_S_OP_TKEEP  : OUT STD_LOGIC_VECTOR(STRB_WIDTH-1 downto 0);
      AXI4_S_OP_TLAST  : OUT STD_LOGIC 
    );
  END COMPONENT;

  COMPONENT aurora_64b66b_0_FRAME_CHECK IS
    PORT ( 
      -- System Interface
      USER_CLK       : IN  STD_LOGIC;
      RESET          : IN  STD_LOGIC;
      CHANNEL_UP     : IN  STD_LOGIC;
      DATA_ERR_COUNT : OUT STD_LOGIC_VECTOR(7 downto 0);
      DATA_OK_COUNT  : OUT STD_LOGIC_VECTOR(7 downto 0);
      -- User Interface
      AXI4_S_IP_TX_TDATA  : IN  STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
      AXI4_S_IP_TX_TVALID : IN  STD_LOGIC;
      AXI4_S_IP_TX_TLAST  : IN  STD_LOGIC;
      AXI4_S_IP_TX_TKEEP  : IN  STD_LOGIC_VECTOR(STRB_WIDTH-1 downto 0);
      AXI4_S_IP_TX_TREADY : OUT STD_LOGIC
    );
  END COMPONENT;

  SIGNAL user_clk : std_logic;
  SIGNAL reset : std_logic;
  SIGNAL s_CHANNEL_UP : std_logic;
  SIGNAL s_axi_ip_tready : std_logic;

  SIGNAL s_axi_data_VHDL : STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
  SIGNAL s_axi_data_Veri : STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
  SIGNAL s_axi_keep_VHDL : STD_LOGIC_VECTOR(STRB_WIDTH-1 downto 0);
  SIGNAL s_axi_keep_Veri : STD_LOGIC_VECTOR(STRB_WIDTH-1 downto 0);
  SIGNAL s_axi_keep_VHDL_w : STD_LOGIC_VECTOR(STRB_WIDTH-1 downto 0);
  SIGNAL s_axi_keep_Veri_w : STD_LOGIC_VECTOR(STRB_WIDTH-1 downto 0);
  SIGNAL s_axi_last_VHDL : std_logic;
  SIGNAL s_axi_last_Veri : std_logic;
  SIGNAL s_axi_valid_VHDL : std_logic;
  SIGNAL s_axi_valid_Veri : std_logic;
  SIGNAL s_axi_txready_VHDL : std_logic;
  SIGNAL s_axi_txready_Veri : std_logic;
  SIGNAL s_error_VHDL : STD_LOGIC_VECTOR(7 downto 0);
  SIGNAL s_error_Veri : STD_LOGIC_VECTOR(7 downto 0);
  SIGNAL s_OK_VHDL : STD_LOGIC_VECTOR(7 downto 0);
  SIGNAL s_OK_Veri : STD_LOGIC_VECTOR(7 downto 0);

BEGIN

  clock_process : PROCESS
  BEGIN
    user_clk <= '0';
    WAIT FOR clock_period/2;
    user_clk <= '1';
    WAIT FOR clock_period/2;
  END PROCESS;

  reset_process : PROCESS
  BEGIN
    reset <= '1';
    s_axi_keep_VHDL_w <= (others => '0');
    s_axi_keep_Veri_w <= (others => '0');
    WAIT FOR 5*clock_period;
    reset <= '0';
    wait;
  END PROCESS;

  channel_up_process : PROCESS
  BEGIN
    s_CHANNEL_UP <= '0';
    s_axi_ip_tready <= '0';
    WAIT FOR 12*clock_period;
    s_axi_ip_tready <='1';
    WAIT FOR 8*clock_period;
    s_CHANNEL_UP <= '1';
    WAIT FOR 312*clock_period;
    s_CHANNEL_UP <= '0';
    WAIT FOR 113*clock_period;
    s_CHANNEL_UP <= '1';
    WAIT FOR 55*clock_period;
    s_axi_ip_tready <= '0';
    WAIT FOR 77*clock_period;
    s_axi_ip_tready <= '1';
    WAIT;
  END PROCESS;

  vhdl_gen : aurora_64b66b_0_FRAME_GEN PORT MAP (
    -- System interface
    USER_CLK   => user_clk,
    RESET      => reset,
    CHANNEL_UP => s_CHANNEL_UP,
    -- PDU interface
    AXI4_S_IP_TREADY => s_axi_ip_tready,
    AXI4_S_OP_TDATA  => s_axi_data_VHDL,
    AXI4_S_OP_TVALID => s_axi_valid_VHDL,
    AXI4_S_OP_TKEEP  => s_axi_keep_VHDL,
    AXI4_S_OP_TLAST  => s_axi_last_VHDL
  );
  
  verilog_gen : aurora_64b66b_0_FRAME_GEN PORT MAP (
    -- System interface
    USER_CLK   => user_clk,
    RESET      => reset,
    CHANNEL_UP => s_CHANNEL_UP,
    -- PDU interface
    AXI4_S_IP_TREADY => s_axi_ip_tready,
    AXI4_S_OP_TDATA  => s_axi_data_Veri,
    AXI4_S_OP_TVALID => s_axi_valid_Veri,
    AXI4_S_OP_TKEEP  => s_axi_keep_Veri,
    AXI4_S_OP_TLAST  => s_axi_last_Veri
  );
  
  vhdl_check : aurora_64b66b_0_FRAME_CHECK PORT MAP (
    -- System Interface
    USER_CLK       => user_clk,
    RESET          => reset,
    CHANNEL_UP     => s_CHANNEL_UP,
    DATA_ERR_COUNT => s_error_VHDL,
    DATA_OK_COUNT  => s_OK_VHDL,
    -- User Interface
    AXI4_S_IP_TX_TDATA  => s_axi_data_VHDL,
    AXI4_S_IP_TX_TVALID => s_axi_valid_VHDL,
    AXI4_S_IP_TX_TLAST  => s_axi_last_VHDL,
    AXI4_S_IP_TX_TKEEP  => s_axi_keep_VHDL, --_w
    AXI4_S_IP_TX_TREADY => s_axi_txready_VHDL
  );
  
  verilog_check : aurora_64b66b_0_FRAME_CHECK PORT MAP (
    -- System Interface
    USER_CLK       => user_clk,
    RESET          => reset,
    CHANNEL_UP     => s_CHANNEL_UP,
    DATA_ERR_COUNT => s_error_Veri,
    DATA_OK_COUNT  => s_OK_Veri,
    -- User Interface
    AXI4_S_IP_TX_TDATA  => s_axi_data_Veri,
    AXI4_S_IP_TX_TVALID => s_axi_valid_Veri,
    AXI4_S_IP_TX_TLAST  => s_axi_last_Veri,
    AXI4_S_IP_TX_TKEEP  => s_axi_keep_Veri,
    AXI4_S_IP_TX_TREADY => s_axi_txready_Veri
  );

  -- self checking testbench
  assert_process : PROCESS(user_clk)
  BEGIN
    -- use falling edge, because the Verilog files use delayed 'DLY assertions so the signals are later than rising_edge
    if falling_edge(user_clk) then
        assert s_axi_data_VHDL = s_axi_data_Veri report "Signal mismatch in <s_axi_data_*> @ " & time'image(now) severity error;
        assert s_axi_keep_VHDL = s_axi_keep_Veri report "Signal mismatch in <s_axi_keep_*> @ " & time'image(now) severity error;
        assert s_axi_last_VHDL = s_axi_last_Veri report "Signal mismatch in <s_axi_last_*> @ " & time'image(now) severity error;
        assert s_axi_valid_VHDL = s_axi_valid_Veri report "Signal mismatch in <s_axi_valid_*> @ " & time'image(now) severity error;
        assert s_error_VHDL = s_error_Veri report "Signal mismatch in <s_error_*> @ " & time'image(now) severity error;
        assert s_OK_VHDL = s_OK_Veri report "Signal mismatch in <s_OK_*> @ " & time'image(now) severity error;
    END if;
  END PROCESS;

end Behavioral; 
