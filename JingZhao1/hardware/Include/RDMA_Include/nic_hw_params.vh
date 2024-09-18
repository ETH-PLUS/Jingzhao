`ifndef RDMA_SIM
`define 	QP_NUM						8192
`else 
`define 	QP_NUM 						1
`endif

`define 	TIMER_NUM 					8192

`define     RPB_CONTENT_FREE_NUM        512
`define     REB_CONTENT_FREE_NUM        8192
`define     SWPB_CONTENT_FREE_NUM       4096


/******************** Timer Control *************/
`define     TIMER_ACTIVE        1'b1
`define     TIMER_INACTIVE      1'b0

`define     SET_TIMER           8'h00
`define     STOP_TIMER          8'hFF
`define     RESTART_TIMER       8'h01

`define     TIMER_EXPIRED       8'h00
`define     COUNTER_EXCEEDED	8'hFF
/******************** Timer Control *************/

/******************* EE *************************/
`define     VALID_ENTRY         8'h00
`define     INVALID_ENTRY       8'h01
`define     INVALID_WQE         8'h20

`define     READ_RESPONSE       8'b00000000
`define     ACK                 8'b00010001

`define     UNCERTAIN           0

`define     GEN_READ_RESP       4'd1
`define     GEN_ACK             4'd2
`define     GEN_NAK             4'd3 
`define     GEN_RNR             4'd4

//`define     FETCH_ENTRY         2'b00
//`define     UPDATE_ENTRY        2'b01
//`define     RELEASE_ENTRY       2'b10 
//`define     RELEASE_WQE         2'b11

/******************* EE *************************/

/******************* RRC ************************/
`define     NONE_EVENT                      3'b000
`define     LOSS_TIMER_EVENT                3'b001
`define     RNR_TIMER_EVENT                 3'b010
`define     BAD_REQ_EVENT                   3'b011
`define     PKT_EVENT                       3'b100

`define     NO_STATE                        4'h0
`define     ACK_RELEASE_NORMAL              4'h1
`define     ACK_RELEASE_EXCEPTION           4'h2
`define     ACK_RETRANS                     4'h3
`define     NAK_RETRANS                     4'h4
`define     NAK_RELEASE                     4'h5
`define     READ_RELEASE                    4'h6
`define     READ_RETRANS                    4'h7
`define 	READ_SCATTER 					4'h8
`define 	WQE_FLUSH						4'h9

`define     SYNDROME_ACK                    2'b00
`define     SYNDROME_RNR                    2'b01
`define     SYNDROME_NAK                    2'b11

`define     NAK_PSN_SEQUENCE_ERROR          5'b00000
`define     NAK_INVALID_REQUEST             5'b00001
`define     NAK_REMOTE_ACCESS_ERROR         5'b00010
`define     NAK_REMOTE_OPERATIONAL_ERROR    5'b00011

//`define     VALID_ENTRY                     8'h00

`define     MANDATORY_TIME                  1
/******************* RRC ************************/

/******************* RTC ************************/
//256-bit width packet buffer 
`define     BUFFER_LINE_SIZE    32

`define     READ_PKEY           8'd0
`define     WRITE_PKEY          8'd0

//CQE is fixed 32B
`define     CQE_LENGTH          32'd32
/******************* RTC ************************/

/******************* SEM / RWM ************************/
`define 	EMPTY 				1'b1
`define 	N_EMPTY				1'b0

//For both SEM and RWM
`define     FETCH_ENTRY         3'b000
`define     UPDATE_ENTRY        3'b001 
`define     RELEASE_ENTRY       3'b010 

//For RWM only
`define     RELEASE_WQE         3'b011 

//For both SEM and RWM, release all entries for current QP
`define 	FLUSH_ENTRY 		3'b100
/******************* RWM ************************/

