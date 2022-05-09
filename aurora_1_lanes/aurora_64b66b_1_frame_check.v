 //////////////////////////////////////////////////////////////////////////////
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
 //////////////////////////////////////////////////////////////////////////////
 //
 //  FRAME CHECK
 //
 //
 //
 //  Description: This module is a  pattern checker to test the Aurora
 //               designs in hardware. The frames generated by FRAME_GEN
 //               pass through the Aurora channel and arrive at the frame checker 
 //               through the RX User interface. Every time an error is found in
 //               the data recieved, the error count is incremented until it 
 //               reaches its max value.
 //////////////////////////////////////////////////////////////////////////////
 
`timescale 1 ps / 1 ps
 `define DLY #1
 
(* DowngradeIPIdentifiedWarnings="yes" *)
 module aurora_64b66b_1_FRAME_CHECK #
 (
     parameter            DATA_WIDTH         = 64, // DATA bus width
     parameter            STRB_WIDTH         = 8 // STROBE bus width
 )
 (
     // User Interface
     AXI4_S_IP_TX_TVALID,
     AXI4_S_IP_TX_TREADY,
     AXI4_S_IP_TX_TDATA,
     AXI4_S_IP_TX_TKEEP,
     AXI4_S_IP_TX_TLAST,
     DATA_ERR_COUNT,
     DATA_OK_COUNT,
 
 
     // System Interface
     CHANNEL_UP,
     USER_CLK,       
     RESET
   
 );
 //*********************** Parameter Declarations************************
     parameter            AURORA_LANES    = 1;
     parameter            LANE_DATA_WIDTH = (AURORA_LANES*64);
     parameter            REM_BUS         = 3;
 
 //***********************************Port Declarations*******************************
     //PDU Interface
     input   [0:(DATA_WIDTH-1)]     AXI4_S_IP_TX_TDATA;
     input                          AXI4_S_IP_TX_TVALID;
     input                          AXI4_S_IP_TX_TLAST;
     input   [0:(STRB_WIDTH-1)]     AXI4_S_IP_TX_TKEEP;
     output                         AXI4_S_IP_TX_TREADY;
     
     //System Interface
     input                              CHANNEL_UP; 
     input                              USER_CLK; 
     input                              RESET;  
     output    [0:8-1]         DATA_ERR_COUNT;
     output    [0:8-1]         DATA_OK_COUNT;
 
 //***************************Internal Register Declarations*************************** 
 
     //PDU interface signals
     reg       [0:8-1]         DATA_ERR_COUNT; 
     reg       [0:8-1]         DATA_OK_COUNT;
     reg       [0:15]                   pdu_lfsr_r;
     reg       [LANE_DATA_WIDTH-1:0]    pdu_cmp_data_r;
     reg       [0:LANE_DATA_WIDTH-1]    RX_D_R;

     wire      [0:LANE_DATA_WIDTH-1]    KEEP_CMP; 

     reg                                pdu_data_valid_r;
     reg                                pdu_in_frame_r;
     reg       [0:AURORA_LANES-1]                   pdu_err_detected_c;
     wire       [0:LANE_DATA_WIDTH-1]    pdu_cmp_data_r1;
     wire      [0:AURORA_LANES-1]                   data_err_c; 

 (* shift_extract = "{no}"*)    reg       [0:LANE_DATA_WIDTH-1]    RX_D_R2;
 (* shift_extract = "{no}"*)    reg       [0:STRB_WIDTH-1]            RX_REM_R2;
 (* shift_extract = "{no}"*)    reg       [0:STRB_WIDTH-1]            RX_REM_R3;
 (* shift_extract = "{no}"*)    reg                                RX_EOF_N_R2;
 (* shift_extract = "{no}"*)    reg                                RX_SRC_RDY_N_R2; 
 
     wire                               pdu_in_frame_c;
     wire      [0:LANE_DATA_WIDTH-1]    pdu_lfsr_concat_w;  
     wire                               pdu_data_valid_c;
 
     wire                               reset_i; 
     wire                               RESET_ii; 


     wire   [0:(DATA_WIDTH-1)]     AXI4_S_IP_TX_TDATA_i;
     wire   [0:(STRB_WIDTH-1)]     AXI4_S_IP_TX_TKEEP_i;

 //*********************************Main Body of Code**********************************
 
     assign   AXI4_S_IP_TX_TDATA_i=AXI4_S_IP_TX_TDATA;
     assign   AXI4_S_IP_TX_TKEEP_i=AXI4_S_IP_TX_TKEEP;
 
   assign reset_i = RESET || (!CHANNEL_UP);
   assign resetUFC = reset_i; 

    assign RESET_ii = RESET ; 

  /*****************************PDU Data Genetration & Checking**********************/


 
     //Generate the PDU data using LFSR for data comparision
     always @ (posedge USER_CLK)
     if(reset_i)
       pdu_lfsr_r  <=  `DLY  16'hD5E6;
     else if(pdu_data_valid_c)
       pdu_lfsr_r  <=  `DLY  {!{pdu_lfsr_r[3]^pdu_lfsr_r[12]^pdu_lfsr_r[14]^pdu_lfsr_r[15]}, 
                            pdu_lfsr_r[0:14]};
 
     assign pdu_lfsr_concat_w = {AURORA_LANES*4{pdu_lfsr_r}};

    always @ (posedge USER_CLK)
    begin
       RX_D_R2         <= `DLY AXI4_S_IP_TX_TDATA_i;
       RX_REM_R2       <= `DLY AXI4_S_IP_TX_TKEEP_i; 
       RX_REM_R3       <= `DLY AXI4_S_IP_TX_TKEEP_i;
       RX_EOF_N_R2     <= `DLY !AXI4_S_IP_TX_TLAST; 
       RX_SRC_RDY_N_R2 <= `DLY !AXI4_S_IP_TX_TVALID; 
    end

 
     //______________________________ Capture incoming data ___________________________    
 
     //PDU data is valid when RX_SRC_RDY_N_R2 is asserted
     assign pdu_data_valid_c    =   pdu_in_frame_c && !RX_SRC_RDY_N_R2;
 
     //PDU data is in a frame if it is a single cycle frame or a multi_cycle frame has started
     assign  pdu_in_frame_c  =   pdu_in_frame_r  ||  (!RX_SRC_RDY_N_R2);
 
     //Start a multicycle PDU frame when a frame starts without ending on the same cycle. End 
     //the frame when an RX_EOF_N_R2 is detected
     always @(posedge USER_CLK)
     if(RESET_ii)
       pdu_in_frame_r  <=  `DLY    1'b0;
     else if(!pdu_in_frame_r && !RX_SRC_RDY_N_R2 && RX_EOF_N_R2)
       pdu_in_frame_r  <=  `DLY    1'b1;
     else if(pdu_in_frame_r && !RX_SRC_RDY_N_R2 && !RX_EOF_N_R2)
       pdu_in_frame_r  <=  `DLY    1'b0;

     assign KEEP_CMP = {
       {8{RX_REM_R2[0]}}, 
       {8{RX_REM_R2[1]}}, 
       {8{RX_REM_R2[2]}}, 
       {8{RX_REM_R2[3]}}, 
       {8{RX_REM_R2[4]}}, 
       {8{RX_REM_R2[5]}}, 
       {8{RX_REM_R2[6]}}, 
       {8{RX_REM_R2[7]}}, 
       {8{RX_REM_R2[8]}}, 
       {8{RX_REM_R2[9]}}, 
       {8{RX_REM_R2[10]}}, 
       {8{RX_REM_R2[11]}}, 
       {8{RX_REM_R2[12]}}, 
       {8{RX_REM_R2[13]}}, 
       {8{RX_REM_R2[14]}}, 
       {8{RX_REM_R2[15]}}, 
       {8{RX_REM_R2[16]}}, 
       {8{RX_REM_R2[17]}}, 
       {8{RX_REM_R2[18]}}, 
       {8{RX_REM_R2[19]}}, 
       {8{RX_REM_R2[20]}}, 
       {8{RX_REM_R2[21]}}, 
       {8{RX_REM_R2[22]}}, 
       {8{RX_REM_R2[23]}}, 
       {8{RX_REM_R2[24]}}, 
       {8{RX_REM_R2[25]}}, 
       {8{RX_REM_R2[26]}}, 
       {8{RX_REM_R2[27]}}, 
       {8{RX_REM_R2[28]}}, 
       {8{RX_REM_R2[29]}}, 
       {8{RX_REM_R2[30]}}, 
       {8{RX_REM_R2[31]}} 
     };



     //Register and decode the RX_D_R2 data with RX_REM_R2 bus
     always @ (posedge USER_CLK)
     begin 	       
       if((!RX_EOF_N_R2) && (!RX_SRC_RDY_N_R2))
       begin
           RX_D_R <=  `DLY RX_D_R2 & KEEP_CMP;
       end  
       else if(!RX_SRC_RDY_N_R2)
         RX_D_R          <=  `DLY    RX_D_R2;
     end 
 
     //Calculate the expected PDU data 
     always @ (posedge USER_CLK)
     begin
       if(reset_i)
         pdu_cmp_data_r <= `DLY {AURORA_LANES*4{16'hD5E6}};
       else if(pdu_data_valid_c)
       begin	
         pdu_cmp_data_r <=  `DLY pdu_lfsr_concat_w & KEEP_CMP;
       end
     end
 
     //PDU Data in the pdu_cmp_data_r register is valid only if it was valid when captured and had no error
     always @(posedge USER_CLK)
       if(reset_i)   
         pdu_data_valid_r    <=  `DLY    1'b0;
       else
         pdu_data_valid_r    <=  `DLY    pdu_data_valid_c && !pdu_err_detected_c;

     assign pdu_cmp_data_r1 = {
       pdu_cmp_data_r[63], 
       pdu_cmp_data_r[62], 
       pdu_cmp_data_r[61], 
       pdu_cmp_data_r[60], 
       pdu_cmp_data_r[59], 
       pdu_cmp_data_r[58], 
       pdu_cmp_data_r[57], 
       pdu_cmp_data_r[56], 
       pdu_cmp_data_r[55], 
       pdu_cmp_data_r[54], 
       pdu_cmp_data_r[53], 
       pdu_cmp_data_r[52], 
       pdu_cmp_data_r[51], 
       pdu_cmp_data_r[50], 
       pdu_cmp_data_r[49], 
       pdu_cmp_data_r[48], 
       pdu_cmp_data_r[47], 
       pdu_cmp_data_r[46], 
       pdu_cmp_data_r[45], 
       pdu_cmp_data_r[44], 
       pdu_cmp_data_r[43], 
       pdu_cmp_data_r[42], 
       pdu_cmp_data_r[41], 
       pdu_cmp_data_r[40], 
       pdu_cmp_data_r[39], 
       pdu_cmp_data_r[38], 
       pdu_cmp_data_r[37], 
       pdu_cmp_data_r[36], 
       pdu_cmp_data_r[35], 
       pdu_cmp_data_r[34], 
       pdu_cmp_data_r[33], 
       pdu_cmp_data_r[32], 
       pdu_cmp_data_r[31], 
       pdu_cmp_data_r[30], 
       pdu_cmp_data_r[29], 
       pdu_cmp_data_r[28], 
       pdu_cmp_data_r[27], 
       pdu_cmp_data_r[26], 
       pdu_cmp_data_r[25], 
       pdu_cmp_data_r[24], 
       pdu_cmp_data_r[23], 
       pdu_cmp_data_r[22], 
       pdu_cmp_data_r[21], 
       pdu_cmp_data_r[20], 
       pdu_cmp_data_r[19], 
       pdu_cmp_data_r[18], 
       pdu_cmp_data_r[17], 
       pdu_cmp_data_r[16], 
       pdu_cmp_data_r[15], 
       pdu_cmp_data_r[14], 
       pdu_cmp_data_r[13], 
       pdu_cmp_data_r[12], 
       pdu_cmp_data_r[11], 
       pdu_cmp_data_r[10], 
       pdu_cmp_data_r[9], 
       pdu_cmp_data_r[8], 
       pdu_cmp_data_r[7], 
       pdu_cmp_data_r[6], 
       pdu_cmp_data_r[5], 
       pdu_cmp_data_r[4], 
       pdu_cmp_data_r[3], 
       pdu_cmp_data_r[2], 
       pdu_cmp_data_r[1], 
       pdu_cmp_data_r[0] 
     };
//     assign pdu_cmp_data_r1 = {
//       pdu_cmp_data_r[255], 
//       pdu_cmp_data_r[254], 
//       pdu_cmp_data_r[253], 
//       pdu_cmp_data_r[252], 
//       pdu_cmp_data_r[251], 
//       pdu_cmp_data_r[250], 
//       pdu_cmp_data_r[249], 
//       pdu_cmp_data_r[248], 
//       pdu_cmp_data_r[247], 
//       pdu_cmp_data_r[246], 
//       pdu_cmp_data_r[245], 
//       pdu_cmp_data_r[244], 
//       pdu_cmp_data_r[243], 
//       pdu_cmp_data_r[242], 
//       pdu_cmp_data_r[241], 
//       pdu_cmp_data_r[240], 
//       pdu_cmp_data_r[239], 
//       pdu_cmp_data_r[238], 
//       pdu_cmp_data_r[237], 
//       pdu_cmp_data_r[236], 
//       pdu_cmp_data_r[235], 
//       pdu_cmp_data_r[234], 
//       pdu_cmp_data_r[233], 
//       pdu_cmp_data_r[232], 
//       pdu_cmp_data_r[231], 
//       pdu_cmp_data_r[230], 
//       pdu_cmp_data_r[229], 
//       pdu_cmp_data_r[228], 
//       pdu_cmp_data_r[227], 
//       pdu_cmp_data_r[226], 
//       pdu_cmp_data_r[225], 
//       pdu_cmp_data_r[224], 
//       pdu_cmp_data_r[223], 
//       pdu_cmp_data_r[222], 
//       pdu_cmp_data_r[221], 
//       pdu_cmp_data_r[220], 
//       pdu_cmp_data_r[219], 
//       pdu_cmp_data_r[218], 
//       pdu_cmp_data_r[217], 
//       pdu_cmp_data_r[216], 
//       pdu_cmp_data_r[215], 
//       pdu_cmp_data_r[214], 
//       pdu_cmp_data_r[213], 
//       pdu_cmp_data_r[212], 
//       pdu_cmp_data_r[211], 
//       pdu_cmp_data_r[210], 
//       pdu_cmp_data_r[209], 
//       pdu_cmp_data_r[208], 
//       pdu_cmp_data_r[207], 
//       pdu_cmp_data_r[206], 
//       pdu_cmp_data_r[205], 
//       pdu_cmp_data_r[204], 
//       pdu_cmp_data_r[203], 
//       pdu_cmp_data_r[202], 
//       pdu_cmp_data_r[201], 
//       pdu_cmp_data_r[200], 
//       pdu_cmp_data_r[199], 
//       pdu_cmp_data_r[198], 
//       pdu_cmp_data_r[197], 
//       pdu_cmp_data_r[196], 
//       pdu_cmp_data_r[195], 
//       pdu_cmp_data_r[194], 
//       pdu_cmp_data_r[193], 
//       pdu_cmp_data_r[192], 
//       pdu_cmp_data_r[191], 
//       pdu_cmp_data_r[190], 
//       pdu_cmp_data_r[189], 
//       pdu_cmp_data_r[188], 
//       pdu_cmp_data_r[187], 
//       pdu_cmp_data_r[186], 
//       pdu_cmp_data_r[185], 
//       pdu_cmp_data_r[184], 
//       pdu_cmp_data_r[183], 
//       pdu_cmp_data_r[182], 
//       pdu_cmp_data_r[181], 
//       pdu_cmp_data_r[180], 
//       pdu_cmp_data_r[179], 
//       pdu_cmp_data_r[178], 
//       pdu_cmp_data_r[177], 
//       pdu_cmp_data_r[176], 
//       pdu_cmp_data_r[175], 
//       pdu_cmp_data_r[174], 
//       pdu_cmp_data_r[173], 
//       pdu_cmp_data_r[172], 
//       pdu_cmp_data_r[171], 
//       pdu_cmp_data_r[170], 
//       pdu_cmp_data_r[169], 
//       pdu_cmp_data_r[168], 
//       pdu_cmp_data_r[167], 
//       pdu_cmp_data_r[166], 
//       pdu_cmp_data_r[165], 
//       pdu_cmp_data_r[164], 
//       pdu_cmp_data_r[163], 
//       pdu_cmp_data_r[162], 
//       pdu_cmp_data_r[161], 
//       pdu_cmp_data_r[160], 
//       pdu_cmp_data_r[159], 
//       pdu_cmp_data_r[158], 
//       pdu_cmp_data_r[157], 
//       pdu_cmp_data_r[156], 
//       pdu_cmp_data_r[155], 
//       pdu_cmp_data_r[154], 
//       pdu_cmp_data_r[153], 
//       pdu_cmp_data_r[152], 
//       pdu_cmp_data_r[151], 
//       pdu_cmp_data_r[150], 
//       pdu_cmp_data_r[149], 
//       pdu_cmp_data_r[148], 
//       pdu_cmp_data_r[147], 
//       pdu_cmp_data_r[146], 
//       pdu_cmp_data_r[145], 
//       pdu_cmp_data_r[144], 
//       pdu_cmp_data_r[143], 
//       pdu_cmp_data_r[142], 
//       pdu_cmp_data_r[141], 
//       pdu_cmp_data_r[140], 
//       pdu_cmp_data_r[139], 
//       pdu_cmp_data_r[138], 
//       pdu_cmp_data_r[137], 
//       pdu_cmp_data_r[136], 
//       pdu_cmp_data_r[135], 
//       pdu_cmp_data_r[134], 
//       pdu_cmp_data_r[133], 
//       pdu_cmp_data_r[132], 
//       pdu_cmp_data_r[131], 
//       pdu_cmp_data_r[130], 
//       pdu_cmp_data_r[129], 
//       pdu_cmp_data_r[128], 
//       pdu_cmp_data_r[127], 
//       pdu_cmp_data_r[126], 
//       pdu_cmp_data_r[125], 
//       pdu_cmp_data_r[124], 
//       pdu_cmp_data_r[123], 
//       pdu_cmp_data_r[122], 
//       pdu_cmp_data_r[121], 
//       pdu_cmp_data_r[120], 
//       pdu_cmp_data_r[119], 
//       pdu_cmp_data_r[118], 
//       pdu_cmp_data_r[117], 
//       pdu_cmp_data_r[116], 
//       pdu_cmp_data_r[115], 
//       pdu_cmp_data_r[114], 
//       pdu_cmp_data_r[113], 
//       pdu_cmp_data_r[112], 
//       pdu_cmp_data_r[111], 
//       pdu_cmp_data_r[110], 
//       pdu_cmp_data_r[109], 
//       pdu_cmp_data_r[108], 
//       pdu_cmp_data_r[107], 
//       pdu_cmp_data_r[106], 
//       pdu_cmp_data_r[105], 
//       pdu_cmp_data_r[104], 
//       pdu_cmp_data_r[103], 
//       pdu_cmp_data_r[102], 
//       pdu_cmp_data_r[101], 
//       pdu_cmp_data_r[100], 
//       pdu_cmp_data_r[99], 
//       pdu_cmp_data_r[98], 
//       pdu_cmp_data_r[97], 
//       pdu_cmp_data_r[96], 
//       pdu_cmp_data_r[95], 
//       pdu_cmp_data_r[94], 
//       pdu_cmp_data_r[93], 
//       pdu_cmp_data_r[92], 
//       pdu_cmp_data_r[91], 
//       pdu_cmp_data_r[90], 
//       pdu_cmp_data_r[89], 
//       pdu_cmp_data_r[88], 
//       pdu_cmp_data_r[87], 
//       pdu_cmp_data_r[86], 
//       pdu_cmp_data_r[85], 
//       pdu_cmp_data_r[84], 
//       pdu_cmp_data_r[83], 
//       pdu_cmp_data_r[82], 
//       pdu_cmp_data_r[81], 
//       pdu_cmp_data_r[80], 
//       pdu_cmp_data_r[79], 
//       pdu_cmp_data_r[78], 
//       pdu_cmp_data_r[77], 
//       pdu_cmp_data_r[76], 
//       pdu_cmp_data_r[75], 
//       pdu_cmp_data_r[74], 
//       pdu_cmp_data_r[73], 
//       pdu_cmp_data_r[72], 
//       pdu_cmp_data_r[71], 
//       pdu_cmp_data_r[70], 
//       pdu_cmp_data_r[69], 
//       pdu_cmp_data_r[68], 
//       pdu_cmp_data_r[67], 
//       pdu_cmp_data_r[66], 
//       pdu_cmp_data_r[65], 
//       pdu_cmp_data_r[64], 
//       pdu_cmp_data_r[63], 
//       pdu_cmp_data_r[62], 
//       pdu_cmp_data_r[61], 
//       pdu_cmp_data_r[60], 
//       pdu_cmp_data_r[59], 
//       pdu_cmp_data_r[58], 
//       pdu_cmp_data_r[57], 
//       pdu_cmp_data_r[56], 
//       pdu_cmp_data_r[55], 
//       pdu_cmp_data_r[54], 
//       pdu_cmp_data_r[53], 
//       pdu_cmp_data_r[52], 
//       pdu_cmp_data_r[51], 
//       pdu_cmp_data_r[50], 
//       pdu_cmp_data_r[49], 
//       pdu_cmp_data_r[48], 
//       pdu_cmp_data_r[47], 
//       pdu_cmp_data_r[46], 
//       pdu_cmp_data_r[45], 
//       pdu_cmp_data_r[44], 
//       pdu_cmp_data_r[43], 
//       pdu_cmp_data_r[42], 
//       pdu_cmp_data_r[41], 
//       pdu_cmp_data_r[40], 
//       pdu_cmp_data_r[39], 
//       pdu_cmp_data_r[38], 
//       pdu_cmp_data_r[37], 
//       pdu_cmp_data_r[36], 
//       pdu_cmp_data_r[35], 
//       pdu_cmp_data_r[34], 
//       pdu_cmp_data_r[33], 
//       pdu_cmp_data_r[32], 
//       pdu_cmp_data_r[31], 
//       pdu_cmp_data_r[30], 
//       pdu_cmp_data_r[29], 
//       pdu_cmp_data_r[28], 
//       pdu_cmp_data_r[27], 
//       pdu_cmp_data_r[26], 
//       pdu_cmp_data_r[25], 
//       pdu_cmp_data_r[24], 
//       pdu_cmp_data_r[23], 
//       pdu_cmp_data_r[22], 
//       pdu_cmp_data_r[21], 
//       pdu_cmp_data_r[20], 
//       pdu_cmp_data_r[19], 
//       pdu_cmp_data_r[18], 
//       pdu_cmp_data_r[17], 
//       pdu_cmp_data_r[16], 
//       pdu_cmp_data_r[15], 
//       pdu_cmp_data_r[14], 
//       pdu_cmp_data_r[13], 
//       pdu_cmp_data_r[12], 
//       pdu_cmp_data_r[11], 
//       pdu_cmp_data_r[10], 
//       pdu_cmp_data_r[9], 
//       pdu_cmp_data_r[8], 
//       pdu_cmp_data_r[7], 
//       pdu_cmp_data_r[6], 
//       pdu_cmp_data_r[5], 
//       pdu_cmp_data_r[4], 
//       pdu_cmp_data_r[3], 
//       pdu_cmp_data_r[2], 
//       pdu_cmp_data_r[1], 
//       pdu_cmp_data_r[0] 
//     };

  assign data_err_c[0] = ( pdu_data_valid_r && (RX_D_R[0:63] != pdu_cmp_data_r1[0:63]));      
//  assign data_err_c[1] = ( pdu_data_valid_r && (RX_D_R[64:127] != pdu_cmp_data_r1[64:127]));      
//  assign data_err_c[2] = ( pdu_data_valid_r && (RX_D_R[128:191] != pdu_cmp_data_r1[128:191]));      
//  assign data_err_c[3] = ( pdu_data_valid_r && (RX_D_R[192:255] != pdu_cmp_data_r1[192:255]));      

 
     //An error is detected when LFSR generated PDU data from the pdu_cmp_data_r register, 
     //does not match valid data from the RX_D port
 always @(posedge USER_CLK)
     pdu_err_detected_c    <=  `DLY    data_err_c;

 
     //Compare the incoming PDU data with calculated expected PDU data.
     //Increment the PDU ERR COUNTER if mismatch occurs
     //Stop the PDU ERR COUNTER once it reaches its max value
     always @ (posedge USER_CLK)
     begin	       
       if(RESET_ii)
         begin
           DATA_ERR_COUNT <= `DLY 8'b0;
           DATA_OK_COUNT  <= `DLY 8'b0;
         end
       else if(!CHANNEL_UP)
         begin
           DATA_ERR_COUNT <= `DLY 8'b0;
           DATA_OK_COUNT  <= `DLY 8'b0;
         end
       else if(&DATA_ERR_COUNT)
         DATA_ERR_COUNT <= `DLY DATA_ERR_COUNT;
       else if(|pdu_err_detected_c)
         DATA_ERR_COUNT <= `DLY DATA_ERR_COUNT + 1; 
       else
         DATA_OK_COUNT <= `DLY DATA_OK_COUNT + 1;
       end 
 
 endmodule           