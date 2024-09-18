`ifndef FPGA_VERSION
`define CHIP_VERSION
`endif

/******************* RDMA DBG_NUM ************************/
//Hierarchical  DBG connections
`define     DBG_NUM_ZERO                        32'd0

`define     DBG_NUM_DOORBELL_PROCESSING         32'd46
`define     DBG_NUM_WQE_SCHEDULER               32'd18
`define     DBG_NUM_WQE_PARSER                  32'd87
`define     DBG_NUM_DATA_PACK                   32'd49
`define     DBG_NUM_SEND_WQE_PROCESSING         (`DBG_NUM_DOORBELL_PROCESSING + `DBG_NUM_WQE_SCHEDULER + `DBG_NUM_WQE_PARSER + `DBG_NUM_DATA_PACK)

`define     DBG_NUM_SCATTERENTRY_MANAGER        32'd21
`define     DBG_NUM_REQUESTER_RECV_CONTROL      (32'd143 + `DBG_NUM_SCATTERENTRY_MANAGER)
`define     DBG_NUM_REQUESTER_TRANS_CONTROL     32'd43
`define     DBG_NUM_MULTI_QUEUE                 32'd96
`define     DBG_NUM_TIMER_CONTROL               32'd14
`define     DBG_NUM_REQ_PKT_GEN                 32'd20
`define     DBG_NUM_REQUESTER_ENGINE            (`DBG_NUM_REQUESTER_RECV_CONTROL + `DBG_NUM_REQUESTER_TRANS_CONTROL + `DBG_NUM_MULTI_QUEUE + `DBG_NUM_TIMER_CONTROL +`DBG_NUM_REQ_PKT_GEN)

`define     DBG_NUM_RECV_WQE_MANAGER            32'd70
`define     DBG_NUM_EXECUTION_ENGINE            32'd108
`define     DBG_NUM_RESP_PKT_GEN                32'd35
`define     DBG_NUM_RESPONDER_ENGINE           	(`DBG_NUM_RECV_WQE_MANAGER + `DBG_NUM_EXECUTION_ENGINE + `DBG_NUM_RESP_PKT_GEN + `DBG_NUM_RESP_PKT_GEN)

`define     DBG_NUM_PACKET_ENCAP                32'd59
`define     DBG_NUM_PACKET_DECAP                32'd19
`define     DBG_NUM_FIFO_TO_AXIS_TRANS          32'd10
`define     DBG_NUM_MISC_LAYER         			(`DBG_NUM_PACKET_ENCAP + `DBG_NUM_PACKET_DECAP + `DBG_NUM_FIFO_TO_AXIS_TRANS)

`define     DBG_NUM_EGRESS_ARBITER              32'd10
`define     DBG_NUM_HEADER_PARSER               32'd44
`define     DBG_NUM_COMPLETION_QUEUE_MGR        32'd9

`define     DBG_NUM_RDMA_ENGINE                 (`DBG_NUM_SEND_WQE_PROCESSING +`DBG_NUM_REQUESTER_ENGINE +`DBG_NUM_RESPONDER_ENGINE + `DBG_NUM_EGRESS_ARBITER + `DBG_NUM_HEADER_PARSER + `DBG_NUM_COMPLETION_QUEUE_MGR)

`define     DBG_NUM_RDMA_ENGINE_WRAPPER         (`DBG_NUM_RDMA_ENGINE + `DBG_NUM_MISC_LAYER + 32'd232)
/******************* RDMA DBG NUM ************************/











