----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/29/2022 02:31:03 PM
-- Design Name: 
-- Module Name: tb_gen_check - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity tb_gen_check is
  GENERIC (
    DATA_WIDTH      : integer := 64;   --  64   DATA bus width
    STRB_WIDTH      : integer := 8;    --  8   STROBE bus width
    AURORA_LANES    : integer := 1;    --  1
    LANE_DATA_WIDTH : integer := 1*64; --  AURORA_LANES * 64
    REM_BUS         : integer := 3;    --  3
    REM_BITS_MAX    : integer := 8     --  LANE_DATA_WIDTH/8
  );
end tb_gen_check;

architecture Behavioral of tb_gen_check is
  
component aurora_64b66b_0_FRAME_GEN IS
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
END component;

component aurora_64b66b_1_FRAME_GEN IS
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
END component;

component aurora_64b66b_0_FRAME_CHECK IS
  PORT ( 
    -- System Interface
    USER_CLK       : in  STD_LOGIC;
    RESET          : in  STD_LOGIC;
    CHANNEL_UP     : in  STD_LOGIC;
    DATA_ERR_COUNT : out STD_LOGIC_VECTOR(7 downto 0);
    DATA_OK_COUNT  : out STD_LOGIC_VECTOR(7 downto 0);
    -- User Interface
    AXI4_S_IP_TX_TDATA  : in  STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
    AXI4_S_IP_TX_TVALID : in  STD_LOGIC;
    AXI4_S_IP_TX_TLAST  : in  STD_LOGIC;
    AXI4_S_IP_TX_TKEEP  : in  STD_LOGIC_VECTOR(STRB_WIDTH-1 downto 0);
    AXI4_S_IP_TX_TREADY : out STD_LOGIC
  );
END component;

component aurora_64b66b_1_FRAME_CHECK IS
  PORT ( 
    -- System Interface
    USER_CLK       : in  STD_LOGIC;
    RESET          : in  STD_LOGIC;
    CHANNEL_UP     : in  STD_LOGIC;
    DATA_ERR_COUNT : out STD_LOGIC_VECTOR(7 downto 0);
    DATA_OK_COUNT  : out STD_LOGIC_VECTOR(7 downto 0);
    -- User Interface
    AXI4_S_IP_TX_TDATA  : in  STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
    AXI4_S_IP_TX_TVALID : in  STD_LOGIC;
    AXI4_S_IP_TX_TLAST  : in  STD_LOGIC;
    AXI4_S_IP_TX_TKEEP  : in  STD_LOGIC_VECTOR(STRB_WIDTH-1 downto 0);
    AXI4_S_IP_TX_TREADY : out STD_LOGIC
  );
END component;

signal user_clk : std_logic;
signal reset : std_logic;
signal s_CHANNEL_UP : std_logic;
signal s_axi_ip_tready : std_logic;

signal s_axi_data_VHDL : STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
signal s_axi_data_Veri : STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
signal s_axi_keep_VHDL : STD_LOGIC_VECTOR(STRB_WIDTH-1 downto 0);
signal s_axi_keep_Veri : STD_LOGIC_VECTOR(STRB_WIDTH-1 downto 0);
signal s_axi_keep_VHDL_w : STD_LOGIC_VECTOR(STRB_WIDTH-1 downto 0);
signal s_axi_keep_Veri_w : STD_LOGIC_VECTOR(STRB_WIDTH-1 downto 0);
signal s_axi_last_VHDL : std_logic;
signal s_axi_last_Veri : std_logic;
signal s_axi_valid_VHDL : std_logic;
signal s_axi_valid_Veri : std_logic;
signal s_axi_txready_VHDL : std_logic;
signal s_axi_txready_Veri : std_logic;
signal s_error_VHDL : STD_LOGIC_VECTOR(7 downto 0);
signal s_error_Veri : STD_LOGIC_VECTOR(7 downto 0);
signal s_OK_VHDL : STD_LOGIC_VECTOR(7 downto 0);
signal s_OK_Veri : STD_LOGIC_VECTOR(7 downto 0);

constant clock_period : time := 5 ns;

begin

-- self checking testbench
assert_process : process(user_clk)
begin
    -- use falling edge, because the Verilog files use delayed 'DLY assertions so the signals are later than rising_edge
    if falling_edge(user_clk) then
        assert s_axi_data_VHDL = s_axi_data_Veri report "Signal mismatch in <s_axi_data_*> @ " & time'image(now) severity error;
        assert s_axi_keep_VHDL = s_axi_keep_Veri report "Signal mismatch in <s_axi_keep_*> @ " & time'image(now) severity error;
        assert s_axi_last_VHDL = s_axi_last_Veri report "Signal mismatch in <s_axi_last_*> @ " & time'image(now) severity error;
        assert s_axi_valid_VHDL = s_axi_valid_Veri report "Signal mismatch in <s_axi_valid_*> @ " & time'image(now) severity error;
        assert s_error_VHDL = s_error_Veri report "Signal mismatch in <s_error_*> @ " & time'image(now) severity error;
        assert s_OK_VHDL = s_OK_Veri report "Signal mismatch in <s_OK_*> @ " & time'image(now) severity error;
    end if;
end process;

clock_process :process
begin
user_clk <= '0';
wait for clock_period/2;
user_clk <= '1';
wait for clock_period/2;
end process;

reset_process : process
begin
reset <= '1';
s_axi_keep_VHDL_w <= (others => '0');
s_axi_keep_Veri_w <= (others => '0');
wait for 5*clock_period;
reset <= '0';
wait;
end process;

channel_up_process : process
begin
s_CHANNEL_UP <= '0';
s_axi_ip_tready <= '0';
wait for 12*clock_period;
s_axi_ip_tready <='1';
wait for 8*clock_period;
s_CHANNEL_UP <= '1';
wait for 312*clock_period;
s_CHANNEL_UP <= '0';
wait for 113*clock_period;
s_CHANNEL_UP <= '1';
wait for 55*clock_period;
s_axi_ip_tready <= '0';
wait for 77*clock_period;
s_axi_ip_tready <= '1';
wait;
end process;

  vhdl_gen : aurora_64b66b_0_FRAME_GEN port map (
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
  
  verilog_gen : aurora_64b66b_1_FRAME_GEN port map (
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
  
  vhdl_check : aurora_64b66b_0_FRAME_CHECK port map (
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
  
  verilog_check : aurora_64b66b_1_FRAME_CHECK port map (
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


end Behavioral; 
