/* ---------------------------------------------------------------------
**
// ------------------------------------------------------------------------------
// 
// Copyright 2001 - 2020 Synopsys, INC.
// 
// This Synopsys IP and all associated documentation are proprietary to
// Synopsys, Inc. and may only be used pursuant to the terms and conditions of a
// written license agreement with Synopsys, Inc. All other use, reproduction,
// modification, or distribution of the Synopsys IP or the associated
// documentation is strictly prohibited.
// 
// Component Name   : DW_axi
// Component Version: 4.04a
// Release Type     : GA
// ------------------------------------------------------------------------------

// 
// Release version :  4.04a
// File Version     :        $Revision: #1 $ 
// Revision: $Id: //dwh/DW_ocb/DW_axi/amba_dev/src/DW_axi_constants.vh#1 $ 
**
** ---------------------------------------------------------------------
**h
** File     : DW_axi_constants.v
//
//
** Created  : Tue May 24 17:09:09 MEST 2005
** Modified : $Date: 2020/03/22 $
** Abstract : Some static macro's for DW_axi.
**
** ---------------------------------------------------------------------
*/

//==============================================================================
// Start Guard: prevent re-compilation of includes
//==============================================================================
`define __GUARD__DW_AXI_CONSTANTS__VH__

// Burst Size Width
`define AXI_BSW 3
// Burst Type Width
`define AXI_BTW 2
// Locked Type Width
`define AXI_LTW ((`AXI_INTERFACE_TYPE >0)? 1 :2)
//`define AXI_LTW 2 
// Cache Type Width
`define AXI_CTW 4
// Protection Type Width
`define AXI_PTW 3
// Buffered Response Width
`define AXI_BRW 2
// Read Response Width
`define AXI_RRW 2
// The width of the write strobe bus
`define AXI_SW        (`AXI_DW/8)

// Maximum number of masters or slaves.
// Including default slave.
`define AXI_MAX_NUM_MST_SLVS 17

// Maximum number of user masters.
`define AXI_MAX_NUM_USR_MSTS 16

// Maximum number of user slaves.
`define AXI_MAX_NUM_USR_SLVS 16

// Locked type field macros.
`define AXI_LT_NORM  2'b00
`define AXI_LT_EX    2'b01
`define AXI_LT_LOCK  2'b10

// Protection type field macros.
`define AXI_PT_PRVLGD    3'bxx1
`define AXI_PT_NORM      3'bxx0
`define AXI_PT_SECURE    3'bx1x
`define AXI_PT_NSECURE   3'bx0x
`define AXI_PT_INSTRUCT  3'b1xx
`define AXI_PT_DATA      3'b0xx

`define AXI_PT_PRVLGD_BIT   0
`define AXI_PT_INSTRUCT_BIT 2

// Encoding definition of RESP signals.
`define AXI_RESP_OKAY     2'b00
`define AXI_RESP_EXOKAY   2'b01
`define AXI_RESP_SLVERR   2'b10
`define AXI_RESP_DECERR   2'b11

// Encoding definition of timing option parameters.
`define AXI_TMO_COMB  2'b00
`define AXI_TMO_FRWD  2'b01
`define AXI_TMO_FULL  2'b10

// Macros used as parameter inputs to blocks,
`define AXI_NOREQ_LOCKING  0 // No locking functionality required.
`define AXI_REQ_LOCKING    1 // Locking functionality required.

// Macros to define the encoding of the the AXI arbitration type
// paramters e.g. AXI_AR_ARBITER_S0.
`define AXI_ARB_TYPE_DP   0
`define AXI_ARB_TYPE_FCFS 1
`define AXI_ARB_TYPE_2T   2
`define AXI_ARB_TYPE_USER 3
`define AXI_ARB_TYPE_QOS  4

// Some blocks need to implement different logic depending
// on what type of channel they are implementing, these macros
// are used for that purpose.
`define AXI_W_CH 1      // This channel is a write data channel.
`define AXI_NOT_W_CH  0 // This channel is not a write data channel.

`define AXI_AW_CH 1      // This channel is a write address channel.
`define AXI_NOT_AW_CH  0 // This channel is not a write address channel.

`define AXI_R_CH 1      // This channel is a read data channel.
`define AXI_NOT_R_CH  0 // This channel is not a read data channel.

`define AXI_ADDR_CH 1     // This channel is an address channel.
`define AXI_NOT_ADDR_CH 0 // This channel is not an address channel.

// Macros to pass to the USE_INT_GRANT_INDEX parameter of the
// DW_axi_arb block.
`define USE_INT_GI  1 // Use internal grant index.
`define USE_EXT_GI  0 // Use external grant index.

// Macros, encoding of shared parameters.
`define AXI_SHARED 1
`define AXI_NOT_SHARED 0

// Width of buses containing hold valid status bits for all 
// sources at all other destinations, from master annd slave 
// perspective.
`define AXI_HOLD_VLD_OTHER_S_W (`AXI_NUM_MASTERS*(`AXI_NSP1-1))
`define AXI_HOLD_VLD_OTHER_M_W ((`AXI_NUM_MASTERS > 1) ? (`AXI_NSP1*(`AXI_NUM_MASTERS-1)) : 1)


// Macros for bit field position of components of
// read address channel payload vector.
`define AXI_ARPYLD_PROT_RHS 0
`define AXI_ARPYLD_PROT_LHS ((`AXI_PTW-1) + `AXI_ARPYLD_PROT_RHS)
`define AXI_ARPYLD_PROT    1 
 
`define AXI_ARPYLD_CACHE_RHS (`AXI_ARPYLD_PROT_LHS + 1)
`define AXI_ARPYLD_CACHE_LHS ((`AXI_CTW-1) + `AXI_ARPYLD_CACHE_RHS)
`define AXI_ARPYLD_CACHE     `AXI_ARPYLD_CACHE_LHS:`AXI_ARPYLD_CACHE_RHS
 
`define AXI_ARPYLD_LOCK_RHS (`AXI_ARPYLD_CACHE_LHS + 1)
`define AXI_ARPYLD_LOCK_LHS ((`AXI_LTW-1) + `AXI_ARPYLD_LOCK_RHS)
`define AXI_ARPYLD_LOCK     `AXI_ARPYLD_LOCK_LHS:`AXI_ARPYLD_LOCK_RHS
 
`define AXI_ARPYLD_BURST_RHS (`AXI_ARPYLD_LOCK_LHS + 1)
`define AXI_ARPYLD_BURST_LHS ((`AXI_BTW-1) + `AXI_ARPYLD_BURST_RHS)
`define AXI_ARPYLD_BURST     `AXI_ARPYLD_BURST_LHS:`AXI_ARPYLD_BURST_RHS
 
`define AXI_ARPYLD_SIZE_RHS (`AXI_ARPYLD_BURST_LHS + 1)
`define AXI_ARPYLD_SIZE_LHS ((`AXI_BSW-1) + `AXI_ARPYLD_SIZE_RHS)
`define AXI_ARPYLD_SIZE     `AXI_ARPYLD_SIZE_LHS:`AXI_ARPYLD_SIZE_RHS
 
`define AXI_ARPYLD_LEN_RHS (`AXI_ARPYLD_SIZE_LHS + 1)
`define AXI_ARPYLD_LEN_LHS ((`AXI_BLW-1) + `AXI_ARPYLD_LEN_RHS)
`define AXI_ARPYLD_LEN     `AXI_ARPYLD_LEN_LHS:`AXI_ARPYLD_LEN_RHS
 
`define AXI_ARPYLD_ADDR_RHS (`AXI_ARPYLD_LEN_LHS + 1)
`define AXI_ARPYLD_ADDR_LHS ((`AXI_AW-1) + `AXI_ARPYLD_ADDR_RHS)
`define AXI_ARPYLD_ADDR     `AXI_ARPYLD_ADDR_LHS:`AXI_ARPYLD_ADDR_RHS
 
// Note : Different ID widths in master and slave ports.
`define AXI_ARPYLD_ID_RHS_M (`AXI_ARPYLD_ADDR_LHS + 1)
`define AXI_ARPYLD_ID_LHS_M ((`AXI_MIDW-1) + `AXI_ARPYLD_ID_RHS_M)
`define AXI_ARPYLD_ID_M     `AXI_ARPYLD_ID_LHS_M:`AXI_ARPYLD_ID_RHS_M
 
`define AXI_ARPYLD_ID_RHS_S (`AXI_ARPYLD_ADDR_LHS + 1)
`define AXI_ARPYLD_ID_LHS_S ((`AXI_SIDW-1) + `AXI_ARPYLD_ID_RHS_S)
`define AXI_ARPYLD_ID_S     `AXI_ARPYLD_ID_LHS_S:`AXI_ARPYLD_ID_RHS_S
 
 
// Macros for bit field position of components of
// read data channel payload vector.
`define AXI_RPYLD_LAST_LHS 0
`define AXI_RPYLD_LAST     `AXI_RPYLD_LAST_LHS
 
`define AXI_RPYLD_RESP_RHS (`AXI_RPYLD_LAST_LHS + 1)
`define AXI_RPYLD_RESP_LHS ((`AXI_RRW-1) + `AXI_RPYLD_RESP_RHS)
`define AXI_RPYLD_RESP     `AXI_RPYLD_RESP_LHS:`AXI_RPYLD_RESP_RHS
 
`define AXI_RPYLD_DATA_RHS (`AXI_RPYLD_RESP_LHS + 1)
`define AXI_RPYLD_DATA_LHS ((`AXI_DW-1) + `AXI_RPYLD_DATA_RHS)
`define AXI_RPYLD_DATA     `AXI_RPYLD_DATA_LHS:`AXI_RPYLD_DATA_RHS
 
// Note : Different ID widths in master and slave ports.
`define AXI_RPYLD_ID_RHS_M (`AXI_RPYLD_DATA_LHS + 1)
`define AXI_RPYLD_ID_LHS_M ((`AXI_MIDW-1) + `AXI_RPYLD_ID_RHS_M)
`define AXI_RPYLD_ID_M     `AXI_RPYLD_ID_LHS_M:`AXI_RPYLD_ID_RHS_M
 
`define AXI_RPYLD_ID_RHS_S (`AXI_RPYLD_DATA_LHS + 1)
`define AXI_RPYLD_ID_LHS_S ((`AXI_SIDW-1) + `AXI_RPYLD_ID_RHS_S)
`define AXI_RPYLD_ID_S     `AXI_RPYLD_ID_LHS_S:`AXI_RPYLD_ID_RHS_S
 
 
// Macros for bit field position of components of
// write address channel payload vector.
`define AXI_AWPYLD_PROT_RHS 0
`define AXI_AWPYLD_PROT_LHS ((`AXI_PTW-1) + `AXI_AWPYLD_PROT_RHS)
`define AXI_AWPYLD_PROT     `AXI_AWPYLD_PROT_LHS:`AXI_AWPYLD_PROT_RHS
 
`define AXI_AWPYLD_CACHE_RHS (`AXI_AWPYLD_PROT_LHS + 1)
`define AXI_AWPYLD_CACHE_LHS ((`AXI_CTW-1) + `AXI_AWPYLD_CACHE_RHS)
`define AXI_AWPYLD_CACHE     `AXI_AWPYLD_CACHE_LHS:`AXI_AWPYLD_CACHE_RHS
 
`define AXI_AWPYLD_LOCK_RHS (`AXI_AWPYLD_CACHE_LHS + 1)
`define AXI_AWPYLD_LOCK_LHS ((`AXI_LTW-1) + `AXI_AWPYLD_LOCK_RHS)
`define AXI_AWPYLD_LOCK     `AXI_AWPYLD_LOCK_LHS:`AXI_AWPYLD_LOCK_RHS
 
`define AXI_AWPYLD_BURST_RHS (`AXI_AWPYLD_LOCK_LHS + 1)
`define AXI_AWPYLD_BURST_LHS ((`AXI_BTW-1) + `AXI_AWPYLD_BURST_RHS)
`define AXI_AWPYLD_BURST     `AXI_AWPYLD_BURST_LHS:`AXI_AWPYLD_BURST_RHS
 
`define AXI_AWPYLD_SIZE_RHS (`AXI_AWPYLD_BURST_LHS + 1)
`define AXI_AWPYLD_SIZE_LHS ((`AXI_BSW-1) + `AXI_AWPYLD_SIZE_RHS)
`define AXI_AWPYLD_SIZE     `AXI_AWPYLD_SIZE_LHS:`AXI_AWPYLD_SIZE_RHS
 
`define AXI_AWPYLD_LEN_RHS (`AXI_AWPYLD_SIZE_LHS + 1)
`define AXI_AWPYLD_LEN_LHS ((`AXI_BLW-1) + `AXI_AWPYLD_LEN_RHS)
`define AXI_AWPYLD_LEN     `AXI_AWPYLD_LEN_LHS:`AXI_AWPYLD_LEN_RHS
 
`define AXI_AWPYLD_ADDR_RHS (`AXI_AWPYLD_LEN_LHS + 1)
`define AXI_AWPYLD_ADDR_LHS ((`AXI_AW-1) + `AXI_AWPYLD_ADDR_RHS)
`define AXI_AWPYLD_ADDR     `AXI_AWPYLD_ADDR_LHS:`AXI_AWPYLD_ADDR_RHS
 
// Note : Different ID widths in master and slave ports.
`define AXI_AWPYLD_ID_RHS_M (`AXI_AWPYLD_ADDR_LHS + 1)
`define AXI_AWPYLD_ID_LHS_M ((`AXI_MIDW-1) + `AXI_AWPYLD_ID_RHS_M)
`define AXI_AWPYLD_ID_M     `AXI_AWPYLD_ID_LHS_M:`AXI_AWPYLD_ID_RHS_M
 
`define AXI_AWPYLD_ID_RHS_S (`AXI_AWPYLD_ADDR_LHS + 1)
`define AXI_AWPYLD_ID_LHS_S ((`AXI_SIDW-1) + `AXI_AWPYLD_ID_RHS_S)
`define AXI_AWPYLD_ID_S     `AXI_AWPYLD_ID_LHS_S:`AXI_AWPYLD_ID_RHS_S
 
 
// Macros for bit field position of components of
// write data channel payload vector.
`define AXI_WPYLD_LAST_LHS 0
`define AXI_WPYLD_LAST     `AXI_WPYLD_LAST_LHS
 
`define AXI_WPYLD_STRB_RHS (`AXI_WPYLD_LAST_LHS + 1)
`define AXI_WPYLD_STRB_LHS ((`AXI_SW-1) + `AXI_WPYLD_STRB_RHS)
`define AXI_WPYLD_STRB     `AXI_WPYLD_STRB_LHS:`AXI_WPYLD_STRB_RHS
 
`define AXI_WPYLD_DATA_RHS (`AXI_WPYLD_STRB_LHS + 1)
`define AXI_WPYLD_DATA_LHS ((`AXI_DW-1) + `AXI_WPYLD_DATA_RHS)
`define AXI_WPYLD_DATA     `AXI_WPYLD_DATA_LHS:`AXI_WPYLD_DATA_RHS
 
// Note : Different ID widths in master and slave ports.
`define AXI_WPYLD_ID_RHS_M (`AXI_WPYLD_DATA_LHS + 1)
`define AXI_WPYLD_ID_LHS_M ((`AXI_MIDW-1) + `AXI_WPYLD_ID_RHS_M)
`define AXI_WPYLD_ID_M     `AXI_WPYLD_ID_LHS_M:`AXI_WPYLD_ID_RHS_M
 
`define AXI_WPYLD_ID_RHS_S (`AXI_WPYLD_DATA_LHS + 1)
`define AXI_WPYLD_ID_LHS_S ((`AXI_SIDW-1) + `AXI_WPYLD_ID_RHS_S)
`define AXI_WPYLD_ID_S     `AXI_WPYLD_ID_LHS_S:`AXI_WPYLD_ID_RHS_S
 
 
// Macros for bit field position of components of
// burst response channel payload vector.
`define AXI_BPYLD_RESP_RHS 0
`define AXI_BPYLD_RESP_LHS ((`AXI_BRW-1) + `AXI_BPYLD_RESP_RHS)
`define AXI_BPYLD_RESP     `AXI_BPYLD_RESP_LHS:`AXI_BPYLD_RESP_RHS
 
// Note : Different ID widths in master and slave ports.
`define AXI_BPYLD_ID_RHS_M (`AXI_BPYLD_RESP_LHS + 1)
`define AXI_BPYLD_ID_LHS_M ((`AXI_MIDW-1) + `AXI_BPYLD_ID_RHS_M)
`define AXI_BPYLD_ID_M     `AXI_BPYLD_ID_LHS_M:`AXI_BPYLD_ID_RHS_M
 
`define AXI_BPYLD_ID_RHS_S (`AXI_BPYLD_RESP_LHS + 1)
`define AXI_BPYLD_ID_LHS_S ((`AXI_SIDW-1) + `AXI_BPYLD_ID_RHS_S)
`define AXI_BPYLD_ID_S     `AXI_BPYLD_ID_LHS_S:`AXI_BPYLD_ID_RHS_S
 
// QOS Signal width
`define AXI_QOSW  4
 // APB constant
`define IC_ADDR_SLICE_LHS  5
`define MAX_APB_DATA_WIDTH 32
`define REG_XCT_RATE_W      12
`define REG_BURSTINESS_W    8
`define REG_PEAK_RATE_W     12
`define APB_ADDR_WIDTH      32

//AXI 4 specific constant
`define AXI_ALSW 4 
`define AXI_ALDW 2
`define AXI_ALBW 2
`define AXI_REGIONW 4


`define PL_BUF_AW 0


`define PL_BUF_AR 0


// Active IDs buffer pointer width

`define ACT_ID_BUF_POINTER_W_AW_M1 84


`define LOG2_ACT_ID_BUF_POINTER_W_AW_M1 7


`define ACT_ID_BUF_POINTER_W_AR_M1 84


`define LOG2_ACT_ID_BUF_POINTER_W_AR_M1 7


`define ACT_ID_BUF_POINTER_W_AW_M2 84


`define LOG2_ACT_ID_BUF_POINTER_W_AW_M2 7


`define ACT_ID_BUF_POINTER_W_AR_M2 84


`define LOG2_ACT_ID_BUF_POINTER_W_AR_M2 7


`define ACT_ID_BUF_POINTER_W_AW_M3 84


`define LOG2_ACT_ID_BUF_POINTER_W_AW_M3 7


`define ACT_ID_BUF_POINTER_W_AR_M3 84


`define LOG2_ACT_ID_BUF_POINTER_W_AR_M3 7


`define ACT_ID_BUF_POINTER_W_AW_M4 84


`define LOG2_ACT_ID_BUF_POINTER_W_AW_M4 7


`define ACT_ID_BUF_POINTER_W_AR_M4 84


`define LOG2_ACT_ID_BUF_POINTER_W_AR_M4 7


`define ACT_ID_BUF_POINTER_W_AW_M5 84


`define LOG2_ACT_ID_BUF_POINTER_W_AW_M5 7


`define ACT_ID_BUF_POINTER_W_AR_M5 84


`define LOG2_ACT_ID_BUF_POINTER_W_AR_M5 7


`define ACT_ID_BUF_POINTER_W_AW_M6 84


`define LOG2_ACT_ID_BUF_POINTER_W_AW_M6 7


`define ACT_ID_BUF_POINTER_W_AR_M6 84


`define LOG2_ACT_ID_BUF_POINTER_W_AR_M6 7


`define ACT_ID_BUF_POINTER_W_AW_M7 84


`define LOG2_ACT_ID_BUF_POINTER_W_AW_M7 7


`define ACT_ID_BUF_POINTER_W_AR_M7 84


`define LOG2_ACT_ID_BUF_POINTER_W_AR_M7 7


`define ACT_ID_BUF_POINTER_W_AW_M8 84


`define LOG2_ACT_ID_BUF_POINTER_W_AW_M8 7


`define ACT_ID_BUF_POINTER_W_AR_M8 84


`define LOG2_ACT_ID_BUF_POINTER_W_AR_M8 7


`define ACT_ID_BUF_POINTER_W_AW_M9 84


`define LOG2_ACT_ID_BUF_POINTER_W_AW_M9 7


`define ACT_ID_BUF_POINTER_W_AR_M9 84


`define LOG2_ACT_ID_BUF_POINTER_W_AR_M9 7


`define ACT_ID_BUF_POINTER_W_AW_M10 84


`define LOG2_ACT_ID_BUF_POINTER_W_AW_M10 7


`define ACT_ID_BUF_POINTER_W_AR_M10 84


`define LOG2_ACT_ID_BUF_POINTER_W_AR_M10 7


`define ACT_ID_BUF_POINTER_W_AW_M11 84


`define LOG2_ACT_ID_BUF_POINTER_W_AW_M11 7


`define ACT_ID_BUF_POINTER_W_AR_M11 84


`define LOG2_ACT_ID_BUF_POINTER_W_AR_M11 7


`define ACT_ID_BUF_POINTER_W_AW_M12 84


`define LOG2_ACT_ID_BUF_POINTER_W_AW_M12 7


`define ACT_ID_BUF_POINTER_W_AR_M12 84


`define LOG2_ACT_ID_BUF_POINTER_W_AR_M12 7


`define ACT_ID_BUF_POINTER_W_AW_M13 84


`define LOG2_ACT_ID_BUF_POINTER_W_AW_M13 7


`define ACT_ID_BUF_POINTER_W_AR_M13 84


`define LOG2_ACT_ID_BUF_POINTER_W_AR_M13 7


`define ACT_ID_BUF_POINTER_W_AW_M14 84


`define LOG2_ACT_ID_BUF_POINTER_W_AW_M14 7


`define ACT_ID_BUF_POINTER_W_AR_M14 84


`define LOG2_ACT_ID_BUF_POINTER_W_AR_M14 7


`define ACT_ID_BUF_POINTER_W_AW_M15 84


`define LOG2_ACT_ID_BUF_POINTER_W_AW_M15 7


`define ACT_ID_BUF_POINTER_W_AR_M15 84


`define LOG2_ACT_ID_BUF_POINTER_W_AR_M15 7


`define ACT_ID_BUF_POINTER_W_AW_M16 84


`define LOG2_ACT_ID_BUF_POINTER_W_AW_M16 7


`define ACT_ID_BUF_POINTER_W_AR_M16 84


`define LOG2_ACT_ID_BUF_POINTER_W_AR_M16 7

//==============================================================================
// End Guard
//==============================================================================  
