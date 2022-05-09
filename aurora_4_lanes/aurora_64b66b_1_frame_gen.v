 ///////////////////////////////////////////////////////////////////////////////
 //
 // Project:  Aurora 64B/66B 
 // Company:  Xilinx
 //
 //
 //
 // (c) Copyright 2008 - 2009 Xilinx, Inc. All rights reserved.
 //
 // This file contains confidential and proprietary information
 // of Xilinx, Inc. and is protected under U.S. and
 // international copyright and other intellectual property
 // laws.
 //
 // DISCLAIMER
 // This disclaimer is not a license and does not grant any
 // rights to the materials distributed herewith. Except as
 // otherwise provided in a valid license issued to you by
 // Xilinx, and to the maximum extent permitted by applicable
 // law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
 // WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
 // AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
 // BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
 // INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
 // (2) Xilinx shall not be liable (whether in contract or tort,
 // including negligence, or under any other theory of
 // liability) for any loss or damage of any kind or nature
 // related to, arising under or in connection with these
 // materials, including for any direct, or any indirect,
 // special, incidental, or consequential loss or damage
 // (including loss of data, profits, goodwill, or any type of
 // loss or damage suffered as a result of any action brought
 // by a third party) even if such damage or loss was
 // reasonably foreseeable or Xilinx had been advised of the
 // possibility of the same.
 //
 // CRITICAL APPLICATIONS
 // Xilinx products are not designed or intended to be fail-
 // safe, or for use in any application requiring fail-safe
 // performance, such as life-support or safety devices or
 // systems, Class III medical devices, nuclear facilities,
 // applications related to the deployment of airbags, or any
 // other applications that could lead to death, personal
 // injury, or severe property or environmental damage
 // (individually and collectively, "Critical
 // Applications"). Customer assumes the sole risk and
 // liability of any use of Xilinx products in Critical
 // Applications, subject only to applicable laws and
 // regulations governing limitations on product liability.
 //
 // THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
 // PART OF THIS FILE AT ALL TIMES.
 
 //
 //
 ///////////////////////////////////////////////////////////////////////////////
 //  FRAME GEN
 //
 //
 //  Description: This module is a pattern generator to test the Aurora
 //               designs in hardware. It generates data and passes it 
 //               through the Aurora channel. 
 ///////////////////////////////////////////////////////////////////////////////
 
`timescale 1 ps / 1 ps
 `define DLY #1

(* DowngradeIPIdentifiedWarnings="yes" *)
 module aurora_64b66b_1_FRAME_GEN #
 (
     parameter            DATA_WIDTH         = 256, // DATA bus width
     parameter            STRB_WIDTH         = 32 // STROBE bus width
 )
 (
     // User Interface
     AXI4_S_OP_TVALID,
     AXI4_S_OP_TDATA,
     AXI4_S_OP_TKEEP,
     AXI4_S_OP_TLAST,
     AXI4_S_IP_TREADY,
 
 
     // System Interface
     CHANNEL_UP,
     USER_CLK,       
     RESET
 ); 
 
 //*****************************Parameter Declarations****************************
     parameter            AURORA_LANES    = 4;
     parameter            LANE_DATA_WIDTH = (AURORA_LANES*64);
     parameter            REM_BUS         = 5;
     parameter            REM_BITS_MAX    = (LANE_DATA_WIDTH/8);
 
 //***********************************Port Declarations*******************************
 
    //PDU Interface
     output     [0:(DATA_WIDTH-1)]     AXI4_S_OP_TDATA;
     output                            AXI4_S_OP_TVALID;
     output     [0:(STRB_WIDTH-1)]     AXI4_S_OP_TKEEP;
     output                            AXI4_S_OP_TLAST;
     input                             AXI4_S_IP_TREADY;
     
 
 
     // System Interface
       input                            CHANNEL_UP; 
       input                            USER_CLK; 
       input                            RESET;  

 //***************************External Register Declarations***************************
 
       wire    [0:(DATA_WIDTH-1)]       AXI4_S_OP_TDATA; 
       reg                              AXI4_S_OP_TVALID; 
       reg                              AXI4_S_OP_TLAST; 
       reg     [0:STRB_WIDTH-1]         AXI4_S_OP_TKEEP;


 
 //***************************Internal Register Declarations*************************** 
 
       reg                   [0:15]     pdu_lfsr_r; 
       reg                   [0:15]     pdu_lfsr_r2; 
       reg                   [0:7]      ifg_size_r; 
       reg                   first_tx_dst_rdy_n;
       reg                   [0:3]      frame_size_r; 
       reg                   [0:3]      bytes_sent_r; 
       reg    [0:STRB_WIDTH-1]           rem_r;
       reg    [0:STRB_WIDTH-1]           rem_r2;
 
 //State registers for one-hot state machine
       reg                              idle_r; 
       reg                              single_cycle_frame_r; 
       reg                              sof_r; 
       reg                              data_cycle_r; 
       reg                              eof_r; 

 
 //*********************************Wire Declarations**********************************
       wire                              ifg_done_c; 
    // Next state signals for one-hot state machine
       wire                              next_idle_c; 
       wire                              next_single_cycle_frame_c; 
       wire                              next_sof_c; 
       wire                              next_data_cycle_c; 
       wire                              next_eof_c; 
 
 
     wire                             ufc_tx_src_rdy_int;
 
     wire                             reset_i;
     wire                             RESET_ii;
 
 //*********************************Main Body of Code**********************************

    assign RESET_ii = RESET ; 
    assign resetUFC = reset_i; 

    assign reset_i = RESET || (!CHANNEL_UP); 
     //Generate random data using XNOR feedback LFSR
     always @(posedge USER_CLK)
       if(reset_i)
        begin
         pdu_lfsr_r <=  `DLY    16'hABCD;  //random seed value
        end
       else if(AXI4_S_IP_TREADY && !idle_r)
        begin
        pdu_lfsr_r  <=  `DLY    {!{pdu_lfsr_r[3]^pdu_lfsr_r[12]^pdu_lfsr_r[14]^pdu_lfsr_r[15]}, 
                                 pdu_lfsr_r[0:14]};
        end
     
     //Connect TX_D to the pdu_lfsr_r register
     assign AXI4_S_OP_TDATA = {AURORA_LANES*4{pdu_lfsr_r}};
 
 
 
     //Use a freerunning counter to determine the IFG
     always @(posedge USER_CLK)
         if(RESET_ii)
             ifg_size_r      <=  `DLY    8'h0;
         else
             ifg_size_r      <=  `DLY    ifg_size_r + 1;
 
     //IFG is done when ifg_size register is 0
     assign  ifg_done_c  =   (ifg_size_r[5:7] == 3'h0);
     //assign  TX_REM  = (pdu_lfsr_r[0:REM_BUS-1]<REM_BITS_MAX) ? 
     //                   pdu_lfsr_r[0:REM_BUS-1]:{REM_BUS{1'b0}};

      always @ (posedge USER_CLK)
        begin
         if(RESET_ii)
         begin
            rem_r  <= `DLY {STRB_WIDTH{1'b1}};
            rem_r2  <= `DLY {STRB_WIDTH{1'b1}};
         end
	 else 
	  begin  
           if(rem_r2 ==  'd0)
            rem_r2  <= `DLY {STRB_WIDTH{1'b1}};	    
           else if (next_eof_c || next_single_cycle_frame_c)
           begin
            rem_r  <= `DLY rem_r2;
            rem_r2  <= `DLY {rem_r2[1:(STRB_WIDTH-1)],1'b0};
           end
           else
            rem_r  <= `DLY {STRB_WIDTH{1'b1}};    
	  end 
        end
 

       always @ (posedge USER_CLK)
         AXI4_S_OP_TKEEP <= `DLY rem_r;

 
     //Use a counter to determine the size of the next frame to send
     always @(posedge USER_CLK)
         if(RESET_ii)
             frame_size_r    <=  `DLY    4'h0;
         else if(single_cycle_frame_r || eof_r)
             frame_size_r    <=  `DLY    frame_size_r + 1;
 
     //Use a second counter to determine how many bytes of the frame have already been sent
     always @(posedge USER_CLK)
         if(RESET_ii)
             bytes_sent_r    <=  `DLY    4'h0;
         else if(sof_r)
             bytes_sent_r    <=  `DLY    4'h1;
         else if(AXI4_S_IP_TREADY && !idle_r)
             bytes_sent_r    <=  `DLY    bytes_sent_r + 1;
 
     //_____________________________ Framing State machine______________________________ 
     //Use a state machine to determine whether to start a frame, end a frame, send
     //data or send nothing
     
     //State registers for 1-hot state machine
     always @(posedge USER_CLK)
         if(reset_i)
         begin
             idle_r                  <=  `DLY    1'b1;
             single_cycle_frame_r    <=  `DLY    1'b0;
             sof_r                   <=  `DLY    1'b0;
             data_cycle_r            <=  `DLY    1'b0;
             eof_r                   <=  `DLY    1'b0;
         end
         else if(AXI4_S_IP_TREADY)
         begin
             idle_r                  <=  `DLY    next_idle_c;
             single_cycle_frame_r    <=  `DLY    next_single_cycle_frame_c;
             sof_r                   <=  `DLY    next_sof_c;
             data_cycle_r            <=  `DLY    next_data_cycle_c;
             eof_r                   <=  `DLY    next_eof_c;
         end
 
 
     //Nextstate logic for 1-hot state machine
     assign  next_idle_c                 =   !ifg_done_c &&
                                             (single_cycle_frame_r || eof_r || idle_r);
 
     assign  next_single_cycle_frame_c   =   (ifg_done_c && (frame_size_r == 0)) &&
                                             (idle_r || single_cycle_frame_r || eof_r);
 
     assign  next_sof_c                  =   (ifg_done_c && (frame_size_r != 0)) &&
                                             (idle_r || single_cycle_frame_r || eof_r);
 
     assign  next_data_cycle_c           =   (frame_size_r != bytes_sent_r) &&
                                             (sof_r || data_cycle_r);
 
     assign  next_eof_c                  =   (frame_size_r == bytes_sent_r) &&
                                             (sof_r || data_cycle_r);
 
 
     //Output logic for 1-hot state machine
     always @(posedge USER_CLK)
         if(reset_i)
         begin
            AXI4_S_OP_TLAST     <=  `DLY    1'b0;
            AXI4_S_OP_TVALID    <=  `DLY    1'b0;
         end
         else if(AXI4_S_IP_TREADY)
         begin
             AXI4_S_OP_TLAST     <=  `DLY (eof_r || single_cycle_frame_r);
             AXI4_S_OP_TVALID    <=  `DLY (sof_r || single_cycle_frame_r || !idle_r);
         end
 

     always @(posedge USER_CLK)
        if (reset_i || !CHANNEL_UP)
           first_tx_dst_rdy_n <= `DLY 1'b0; 
        else if(AXI4_S_IP_TREADY && CHANNEL_UP)
           first_tx_dst_rdy_n <= `DLY 1'b1; 


 
 endmodule 
