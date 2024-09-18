//+FHDR--------------------------------------------------------------------
// (C) Copyright Institute of Computing Technology (ICT)
// All Right Reserved
//-------------------------------------------------------------------------
// FILE NAME: SW_HW_Interface_Constant.v
// AUTHOR: yangfan
// CONTACT INFORMATION: yangfan@ncic.ac.cn
//-------------------------------------------------------------------------
// RELEASE VERSION: V1.0
// VERSION DESCRIPTION: First Edition no errata
//-------------------------------------------------------------------------
// RELEASE DATE: 2020-07-21
//-------------------------------------------------------------------------
// PURPOSE: Constants used by Software and Hardware.
//-------------------------------------------------------------------------
//-FHDR--------------------------------------------------------------------

//Request Code Definition
`define     VERBS_SEND                 5'b01010
`define     VERBS_SEND_WITH_IMM        5'b01011
`define     VERBS_RDMA_WRITE           5'b01000
`define     VERBS_RDMA_WRITE_WITH_IMM  5'b01001 
`define     VERBS_RDMA_READ            5'b10000 
`define     VERBS_CMP_AND_SWAP         5'b10001 
`define     VERBS_FETCH_AND_ADD        5'b10010 
`define 	OPCODE_INVALID 			   8'hFF	

//Completion Code Definition
`define     LOC_LEN_ERR             8'b00000001
`define     LOC_QP_OP_ERR           8'b00000010 
`define     LOC_EEC_OP_ERR          8'b00000011
`define     LOC_PROT_ERR            8'b00000100
`define     WR_FLUSH_ERR            8'b00000101 
`define     MW_BIND_ERR             8'b00000110 
`define     BAD_RESP_ERR            8'b00010000
`define     LOC_ACCESS_ERR          8'b00010001
`define     REM_INV_REQ_ERR         8'b00010010 
`define     REM_ACCESS_ERR          8'b00010011
`define     REM_OP_ERR              8'b00010100 
`define     RETRY_EXC_ERR           8'b00010101 
`define     RNR_RETRY_EXC_ERR       8'b00010110 
`define     LOC_RDD_VIOL_ERR        8'b00100000 
`define     REM_INV_RD_REQ_ERR      8'b00100001 
`define     REM_ABORT_ERR           8'b00100010 
`define     INV_EECN_ERR            8'b00100011 
`define     INV_EEC_STATE_ERR       8'b00100100 

//QP State Definition
`define     QP_RESET           3'b000
`define     QP_INIT            3'b001
`define     QP_RTR             3'b010 
`define     QP_RTS             3'b011 
`define     QP_SQD             3'b100 
`define     QP_SQE             3'b101
`define     QP_ERR             3'b110

//WQEParser Error Checking
`define     QP_NORMAL               4'b0000 
`define     QP_STATE_ERR            4'b0001 
`define     QP_OPCODE_ERR           4'b0010 
`define     QP_LOCAL_ACCESS_ERR     4'b0100
 
 //Execution Engine Constant
 `define    RESP_NAK                4'b0001
