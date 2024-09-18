//+FHDR--------------------------------------------------------------------
// (C) Copyright Institute of Computing Technology (ICT)
// All Right Reserved
//-------------------------------------------------------------------------
// FILE NAME: IB_Constant.v
// AUTHOR: yangfan
// CONTACT INFORMATION: yangfan@ncic.ac.cn
//-------------------------------------------------------------------------
// RELEASE VERSION: V1.0
// VERSION DESCRIPTION: First Edition no errata
//-------------------------------------------------------------------------
// RELEASE DATE: 2020-07-21
//-------------------------------------------------------------------------
// PURPOSE: Constants defined by IB Specification.
//-------------------------------------------------------------------------
//-FHDR--------------------------------------------------------------------

//Base Transport Header Code
`define     RC      3'b000
`define     UC      3'b001
`define     RD      3'b010
`define     UD      3'b011
`define     CNP     3'b100
`define     XRC     3'b101

`define     SEND_FIRST                      5'b00000
`define     SEND_MIDDLE                     5'b00001
`define     SEND_LAST                       5'b00010
`define     SEND_LAST_WITH_IMM              5'b00011
`define     SEND_ONLY                       5'b00100 
`define     SEND_ONLY_WITH_IMM              5'b00101
`define     RDMA_WRITE_FIRST                5'b00110 
`define     RDMA_WRITE_MIDDLE               5'b00111
`define     RDMA_WRITE_LAST                 5'b01000 
`define     RDMA_WRITE_LAST_WITH_IMM        5'b01001 
`define     RDMA_WRITE_ONLY                 5'b01010
`define     RDMA_WRITE_ONLY_WITH_IMM        5'b01011
`define     RDMA_READ_REQUEST               5'b01100
`define     RDMA_READ_RESPONSE_FIRST        5'b01101 
`define     RDMA_READ_RESPONSE_MIDDLE       5'b01110 
`define     RDMA_READ_RESPONSE_LAST         5'b01111 
`define     RDMA_READ_RESPONSE_ONLY         5'b10000
`define     ACKNOWLEDGE                     5'b10001
`define     ATOMIC_ACKNOWLEDGE              5'b10010 
`define     CMP_AND_SWAP                    5'b10011 
`define     FETCH_AND_ADD                   5'b10100
`define     SEND_LAST_WITH_INVALIDATE       5'b10110 
`define     SEND_ONLY_WITH_INVALIDATE       5'b10111
`define     NONE_OPCODE                     5'b11111


//Acknowledgement Extended Transport Header Syndrome Code
`define     ACK_TYPE                        2'b00
`define     RNR_TYPE                        2'b01 
`define     RESERVED_TYPE                   2'b10
`define     NAK_TYPE                        2'b11 
        
`define     PSN_SEQUENCE_ERROR              5'b00000
`define     INVALID_REQUEST                 5'b00001 
`define     REMOTE_ACCESS_ERROR             5'b00010 
`define     REMOTE_OPERATIONAL_ERROR        5'b00011
`define     INVALID_RD_REQUEST              5'b00100

//MTU Constants
`define     MTU_256                         16'd256
`define     MTU_512                         16'd512
`define     MTU_1024                        16'd1024
`define     MTU_2048                        16'd2048
`define     MTU_4096                        16'd4096


