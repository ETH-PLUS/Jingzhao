module DMA_Channel_Top
(
	input 	wire 									clk,
	input 	wire 									rst,

//Wr Channel
	//Channel 0
	input 	wire 									CEU_dma_wr_req_in_valid,
	input 	wire 		[127:0]						CEU_dma_wr_req_in_head,
	input 	wire 		[511:0]						CEU_dma_wr_req_in_data,
	input 	wire 									CEU_dma_wr_req_in_last,
	output 	wire 									CEU_dma_wr_req_in_ready,

	output 	wire 									CEU_dma_wr_req_out_valid,
	output 	wire 		[127:0]						CEU_dma_wr_req_out_head,
	output 	wire 		[255:0]						CEU_dma_wr_req_out_data,
	output 	wire 									CEU_dma_wr_req_out_last,
	input 	wire 									CEU_dma_wr_req_out_ready,

	//Channel 1
	input 	wire 									QPC_dma_wr_req_in_valid,
	input 	wire 		[127:0]						QPC_dma_wr_req_in_head,
	input 	wire 		[511:0]						QPC_dma_wr_req_in_data,
	input 	wire 									QPC_dma_wr_req_in_last,
	output 	wire 									QPC_dma_wr_req_in_ready,

	output 	wire 									QPC_dma_wr_req_out_valid,
	output 	wire 		[127:0]						QPC_dma_wr_req_out_head,
	output 	wire 		[255:0]						QPC_dma_wr_req_out_data,
	output 	wire 									QPC_dma_wr_req_out_last,
	input 	wire 									QPC_dma_wr_req_out_ready,

	//Channel 2
	input 	wire 									CQC_dma_wr_req_in_valid,
	input 	wire 		[127:0]						CQC_dma_wr_req_in_head,
	input 	wire 		[511:0]						CQC_dma_wr_req_in_data,
	input 	wire 									CQC_dma_wr_req_in_last,
	output 	wire 									CQC_dma_wr_req_in_ready,

	output 	wire 									CQC_dma_wr_req_out_valid,
	output 	wire 		[127:0]						CQC_dma_wr_req_out_head,
	output 	wire 		[255:0]						CQC_dma_wr_req_out_data,
	output 	wire 									CQC_dma_wr_req_out_last,
	input 	wire 									CQC_dma_wr_req_out_ready,

	//Channel 3
	input 	wire 									EQC_dma_wr_req_in_valid,
	input 	wire 		[127:0]						EQC_dma_wr_req_in_head,
	input 	wire 		[511:0]						EQC_dma_wr_req_in_data,
	input 	wire 									EQC_dma_wr_req_in_last,
	output 	wire 									EQC_dma_wr_req_in_ready,

	output 	wire 									EQC_dma_wr_req_out_valid,
	output 	wire 		[127:0]						EQC_dma_wr_req_out_head,
	output 	wire 		[255:0]						EQC_dma_wr_req_out_data,
	output 	wire 									EQC_dma_wr_req_out_last,
	input 	wire 									EQC_dma_wr_req_out_ready,

	//Channel 4
	input 	wire 									MPT_dma_wr_req_in_valid,
	input 	wire 		[127:0]						MPT_dma_wr_req_in_head,
	input 	wire 		[511:0]						MPT_dma_wr_req_in_data,
	input 	wire 									MPT_dma_wr_req_in_last,
	output 	wire 									MPT_dma_wr_req_in_ready,

	output 	wire 									MPT_dma_wr_req_out_valid,
	output 	wire 		[127:0]						MPT_dma_wr_req_out_head,
	output 	wire 		[255:0]						MPT_dma_wr_req_out_data,
	output 	wire 									MPT_dma_wr_req_out_last,
	input 	wire 									MPT_dma_wr_req_out_ready,

	//Channel 5
	input 	wire 									MTT_dma_wr_req_in_valid,
	input 	wire 		[127:0]						MTT_dma_wr_req_in_head,
	input 	wire 		[511:0]						MTT_dma_wr_req_in_data,
	input 	wire 									MTT_dma_wr_req_in_last,
	output 	wire 									MTT_dma_wr_req_in_ready,

	output 	wire 									MTT_dma_wr_req_out_valid,
	output 	wire 		[127:0]						MTT_dma_wr_req_out_head,
	output 	wire 		[255:0]						MTT_dma_wr_req_out_data,
	output 	wire 									MTT_dma_wr_req_out_last,
	input 	wire 									MTT_dma_wr_req_out_ready,

	//Channel 6
	input 	wire 									TX_REQ_dma_wr_req_in_valid,
	input 	wire 		[127:0]						TX_REQ_dma_wr_req_in_head,
	input 	wire 		[511:0]						TX_REQ_dma_wr_req_in_data,
	input 	wire 									TX_REQ_dma_wr_req_in_last,
	output 	wire 									TX_REQ_dma_wr_req_in_ready,

	output 	wire 									TX_REQ_dma_wr_req_out_valid,
	output 	wire 		[127:0]						TX_REQ_dma_wr_req_out_head,
	output 	wire 		[255:0]						TX_REQ_dma_wr_req_out_data,
	output 	wire 									TX_REQ_dma_wr_req_out_last,
	input 	wire 									TX_REQ_dma_wr_req_out_ready,

	//Channel 7
	input 	wire 									RX_REQ_dma_wr_req_in_valid,
	input 	wire 		[127:0]						RX_REQ_dma_wr_req_in_head,
	input 	wire 		[511:0]						RX_REQ_dma_wr_req_in_data,
	input 	wire 									RX_REQ_dma_wr_req_in_last,
	output 	wire 									RX_REQ_dma_wr_req_in_ready,

	output 	wire 									RX_REQ_dma_wr_req_out_valid,
	output 	wire 		[127:0]						RX_REQ_dma_wr_req_out_head,
	output 	wire 		[255:0]						RX_REQ_dma_wr_req_out_data,
	output 	wire 									RX_REQ_dma_wr_req_out_last,
	input 	wire 									RX_REQ_dma_wr_req_out_ready,

	//Channel 8
	input 	wire 									RX_RESP_dma_wr_req_in_valid,
	input 	wire 		[127:0]						RX_RESP_dma_wr_req_in_head,
	input 	wire 		[511:0]						RX_RESP_dma_wr_req_in_data,
	input 	wire 									RX_RESP_dma_wr_req_in_last,
	output 	wire 									RX_RESP_dma_wr_req_in_ready,

	output 	wire 									RX_RESP_dma_wr_req_out_valid,
	output 	wire 		[127:0]						RX_RESP_dma_wr_req_out_head,
	output 	wire 		[255:0]						RX_RESP_dma_wr_req_out_data,
	output 	wire 									RX_RESP_dma_wr_req_out_last,
	input 	wire 									RX_RESP_dma_wr_req_out_ready,

//Rd Channel
	//Channel 0
	input 	wire 									CEU_dma_rd_rsp_in_valid,
	input 	wire 		[127:0]						CEU_dma_rd_rsp_in_head,
	input 	wire 		[255:0]						CEU_dma_rd_rsp_in_data,
	input 	wire 									CEU_dma_rd_rsp_in_last,
	output 	wire 									CEU_dma_rd_rsp_in_ready,

	output 	wire 									CEU_dma_rd_rsp_out_valid,
	output 	wire 		[127:0]						CEU_dma_rd_rsp_out_head,
	output 	wire 		[511:0]						CEU_dma_rd_rsp_out_data,
	output 	wire 									CEU_dma_rd_rsp_out_last,
	input 	wire 									CEU_dma_rd_rsp_out_ready,

	//Channel 1
	input 	wire 									SQ_dma_rd_rsp_in_valid,
	input 	wire 		[127:0]						SQ_dma_rd_rsp_in_head,
	input 	wire 		[255:0]						SQ_dma_rd_rsp_in_data,
	input 	wire 									SQ_dma_rd_rsp_in_last,
	output 	wire 									SQ_dma_rd_rsp_in_ready,

	output 	wire 									SQ_dma_rd_rsp_out_valid,
	output 	wire 		[127:0]						SQ_dma_rd_rsp_out_head,
	output 	wire 		[511:0]						SQ_dma_rd_rsp_out_data,
	output 	wire 									SQ_dma_rd_rsp_out_last,
	input 	wire 									SQ_dma_rd_rsp_out_ready,

	//Channel 2
	input 	wire 									RQ_dma_rd_rsp_in_valid,
	input 	wire 		[127:0]						RQ_dma_rd_rsp_in_head,
	input 	wire 		[255:0]						RQ_dma_rd_rsp_in_data,
	input 	wire 									RQ_dma_rd_rsp_in_last,
	output 	wire 									RQ_dma_rd_rsp_in_ready,

	output 	wire 									RQ_dma_rd_rsp_out_valid,
	output 	wire 		[127:0]						RQ_dma_rd_rsp_out_head,
	output 	wire 		[511:0]						RQ_dma_rd_rsp_out_data,
	output 	wire 									RQ_dma_rd_rsp_out_last,
	input 	wire 									RQ_dma_rd_rsp_out_ready,

	//Channel 3
	input 	wire 									QPC_dma_rd_rsp_in_valid,
	input 	wire 		[127:0]						QPC_dma_rd_rsp_in_head,
	input 	wire 		[255:0]						QPC_dma_rd_rsp_in_data,
	input 	wire 									QPC_dma_rd_rsp_in_last,
	output 	wire 									QPC_dma_rd_rsp_in_ready,

	output 	wire 									QPC_dma_rd_rsp_out_valid,
	output 	wire 		[127:0]						QPC_dma_rd_rsp_out_head,
	output 	wire 		[511:0]						QPC_dma_rd_rsp_out_data,
	output 	wire 									QPC_dma_rd_rsp_out_last,
	input 	wire 									QPC_dma_rd_rsp_out_ready,

	//Channel 4
	input 	wire 									CQC_dma_rd_rsp_in_valid,
	input 	wire 		[127:0]						CQC_dma_rd_rsp_in_head,
	input 	wire 		[255:0]						CQC_dma_rd_rsp_in_data,
	input 	wire 									CQC_dma_rd_rsp_in_last,
	output 	wire 									CQC_dma_rd_rsp_in_ready,

	output 	wire 									CQC_dma_rd_rsp_out_valid,
	output 	wire 		[127:0]						CQC_dma_rd_rsp_out_head,
	output 	wire 		[511:0]						CQC_dma_rd_rsp_out_data,
	output 	wire 									CQC_dma_rd_rsp_out_last,
	input 	wire 									CQC_dma_rd_rsp_out_ready,

	//Channel 5
	input 	wire 									EQC_dma_rd_rsp_in_valid,
	input 	wire 		[127:0]						EQC_dma_rd_rsp_in_head,
	input 	wire 		[255:0]						EQC_dma_rd_rsp_in_data,
	input 	wire 									EQC_dma_rd_rsp_in_last,
	output 	wire 									EQC_dma_rd_rsp_in_ready,

	output 	wire 									EQC_dma_rd_rsp_out_valid,
	output 	wire 		[127:0]						EQC_dma_rd_rsp_out_head,
	output 	wire 		[511:0]						EQC_dma_rd_rsp_out_data,
	output 	wire 									EQC_dma_rd_rsp_out_last,
	input 	wire 									EQC_dma_rd_rsp_out_ready,

	//Channel 6
	input 	wire 									MPT_dma_rd_rsp_in_valid,
	input 	wire 		[127:0]						MPT_dma_rd_rsp_in_head,
	input 	wire 		[255:0]						MPT_dma_rd_rsp_in_data,
	input 	wire 									MPT_dma_rd_rsp_in_last,
	output 	wire 									MPT_dma_rd_rsp_in_ready,

	output 	wire 									MPT_dma_rd_rsp_out_valid,
	output 	wire 		[127:0]						MPT_dma_rd_rsp_out_head,
	output 	wire 		[511:0]						MPT_dma_rd_rsp_out_data,
	output 	wire 									MPT_dma_rd_rsp_out_last,
	input 	wire 									MPT_dma_rd_rsp_out_ready,

	//Channel 7
	input 	wire 									MTT_dma_rd_rsp_in_valid,
	input 	wire 		[127:0]						MTT_dma_rd_rsp_in_head,
	input 	wire 		[255:0]						MTT_dma_rd_rsp_in_data,
	input 	wire 									MTT_dma_rd_rsp_in_last,
	output 	wire 									MTT_dma_rd_rsp_in_ready,

	output 	wire 									MTT_dma_rd_rsp_out_valid,
	output 	wire 		[127:0]						MTT_dma_rd_rsp_out_head,
	output 	wire 		[511:0]						MTT_dma_rd_rsp_out_data,
	output 	wire 									MTT_dma_rd_rsp_out_last,
	input 	wire 									MTT_dma_rd_rsp_out_ready,

	//Channel 8
	input 	wire 									TX_REQ_dma_rd_rsp_in_valid,
	input 	wire 		[127:0]						TX_REQ_dma_rd_rsp_in_head,
	input 	wire 		[255:0]						TX_REQ_dma_rd_rsp_in_data,
	input 	wire 									TX_REQ_dma_rd_rsp_in_last,
	output 	wire 									TX_REQ_dma_rd_rsp_in_ready,

	output 	wire 									TX_REQ_dma_rd_rsp_out_valid,
	output 	wire 		[127:0]						TX_REQ_dma_rd_rsp_out_head,
	output 	wire 		[511:0]						TX_REQ_dma_rd_rsp_out_data,
	output 	wire 									TX_REQ_dma_rd_rsp_out_last,
	input 	wire 									TX_REQ_dma_rd_rsp_out_ready,

	//Channel 9
	input 	wire 									TX_RESP_dma_rd_rsp_in_valid,
	input 	wire 		[127:0]						TX_RESP_dma_rd_rsp_in_head,
	input 	wire 		[255:0]						TX_RESP_dma_rd_rsp_in_data,
	input 	wire 									TX_RESP_dma_rd_rsp_in_last,
	output 	wire 									TX_RESP_dma_rd_rsp_in_ready,

	output 	wire 									TX_RESP_dma_rd_rsp_out_valid,
	output 	wire 		[127:0]						TX_RESP_dma_rd_rsp_out_head,
	output 	wire 		[511:0]						TX_RESP_dma_rd_rsp_out_data,
	output 	wire 									TX_RESP_dma_rd_rsp_out_last,
	input 	wire 									TX_RESP_dma_rd_rsp_out_ready
);

DMAWrReqChannel DMAWrReqChannel_CEU( 	//512 to 256
	.clk						(			clk							),
	.rst						(			rst							),

	.dma_wr_req_in_valid		(			CEU_dma_wr_req_in_valid		),
	.dma_wr_req_in_head			(			CEU_dma_wr_req_in_head		),
	.dma_wr_req_in_data			(			CEU_dma_wr_req_in_data		),
	.dma_wr_req_in_last			(			CEU_dma_wr_req_in_last		),
	.dma_wr_req_in_ready		(			CEU_dma_wr_req_in_ready		),

	.dma_wr_req_out_valid		(			CEU_dma_wr_req_out_valid	),
	.dma_wr_req_out_head		(			CEU_dma_wr_req_out_head		),
	.dma_wr_req_out_data		(			CEU_dma_wr_req_out_data		),
	.dma_wr_req_out_last		(			CEU_dma_wr_req_out_last		),
	.dma_wr_req_out_ready		(			CEU_dma_wr_req_out_ready	)
);

DMAWrReqChannel DMAWrReqChannel_QPC( 	//512 to 256
	.clk						(			clk							),
	.rst						(			rst							),

	.dma_wr_req_in_valid		(			QPC_dma_wr_req_in_valid		),
	.dma_wr_req_in_head			(			QPC_dma_wr_req_in_head		),
	.dma_wr_req_in_data			(			QPC_dma_wr_req_in_data		),
	.dma_wr_req_in_last			(			QPC_dma_wr_req_in_last		),
	.dma_wr_req_in_ready		(			QPC_dma_wr_req_in_ready		),

	.dma_wr_req_out_valid		(			QPC_dma_wr_req_out_valid	),
	.dma_wr_req_out_head		(			QPC_dma_wr_req_out_head		),
	.dma_wr_req_out_data		(			QPC_dma_wr_req_out_data		),
	.dma_wr_req_out_last		(			QPC_dma_wr_req_out_last		),
	.dma_wr_req_out_ready		(			QPC_dma_wr_req_out_ready	)
);

DMAWrReqChannel DMAWrReqChannel_CQC( 	//512 to 256
	.clk						(			clk							),
	.rst						(			rst							),

	.dma_wr_req_in_valid		(			CQC_dma_wr_req_in_valid		),
	.dma_wr_req_in_head			(			CQC_dma_wr_req_in_head		),
	.dma_wr_req_in_data			(			CQC_dma_wr_req_in_data		),
	.dma_wr_req_in_last			(			CQC_dma_wr_req_in_last		),
	.dma_wr_req_in_ready		(			CQC_dma_wr_req_in_ready		),

	.dma_wr_req_out_valid		(			CQC_dma_wr_req_out_valid	),
	.dma_wr_req_out_head		(			CQC_dma_wr_req_out_head		),
	.dma_wr_req_out_data		(			CQC_dma_wr_req_out_data		),
	.dma_wr_req_out_last		(			CQC_dma_wr_req_out_last		),
	.dma_wr_req_out_ready		(			CQC_dma_wr_req_out_ready	)
);

DMAWrReqChannel DMAWrReqChannel_EQC( 	//512 to 256
	.clk						(			clk							),
	.rst						(			rst							),

	.dma_wr_req_in_valid		(			EQC_dma_wr_req_in_valid		),
	.dma_wr_req_in_head			(			EQC_dma_wr_req_in_head		),
	.dma_wr_req_in_data			(			EQC_dma_wr_req_in_data		),
	.dma_wr_req_in_last			(			EQC_dma_wr_req_in_last		),
	.dma_wr_req_in_ready		(			EQC_dma_wr_req_in_ready		),

	.dma_wr_req_out_valid		(			EQC_dma_wr_req_out_valid	),
	.dma_wr_req_out_head		(			EQC_dma_wr_req_out_head		),
	.dma_wr_req_out_data		(			EQC_dma_wr_req_out_data		),
	.dma_wr_req_out_last		(			EQC_dma_wr_req_out_last		),
	.dma_wr_req_out_ready		(			EQC_dma_wr_req_out_ready	)
);

DMAWrReqChannel DMAWrReqChannel_MPT( 	//512 to 256
	.clk						(			clk							),
	.rst						(			rst							),

	.dma_wr_req_in_valid		(			MPT_dma_wr_req_in_valid		),
	.dma_wr_req_in_head			(			MPT_dma_wr_req_in_head		),
	.dma_wr_req_in_data			(			MPT_dma_wr_req_in_data		),
	.dma_wr_req_in_last			(			MPT_dma_wr_req_in_last		),
	.dma_wr_req_in_ready		(			MPT_dma_wr_req_in_ready		),

	.dma_wr_req_out_valid		(			MPT_dma_wr_req_out_valid	),
	.dma_wr_req_out_head		(			MPT_dma_wr_req_out_head		),
	.dma_wr_req_out_data		(			MPT_dma_wr_req_out_data		),
	.dma_wr_req_out_last		(			MPT_dma_wr_req_out_last		),
	.dma_wr_req_out_ready		(			MPT_dma_wr_req_out_ready	)
);

DMAWrReqChannel DMAWrReqChannel_MTT( 	//512 to 256
	.clk						(			clk							),
	.rst						(			rst							),

	.dma_wr_req_in_valid		(			MTT_dma_wr_req_in_valid		),
	.dma_wr_req_in_head			(			MTT_dma_wr_req_in_head		),
	.dma_wr_req_in_data			(			MTT_dma_wr_req_in_data		),
	.dma_wr_req_in_last			(			MTT_dma_wr_req_in_last		),
	.dma_wr_req_in_ready		(			MTT_dma_wr_req_in_ready		),

	.dma_wr_req_out_valid		(			MTT_dma_wr_req_out_valid	),
	.dma_wr_req_out_head		(			MTT_dma_wr_req_out_head		),
	.dma_wr_req_out_data		(			MTT_dma_wr_req_out_data		),
	.dma_wr_req_out_last		(			MTT_dma_wr_req_out_last		),
	.dma_wr_req_out_ready		(			MTT_dma_wr_req_out_ready	)
);

DMAWrReqChannel DMAWrReqChannel_TX_REQ( 	//512 to 256
	.clk						(			clk								),
	.rst						(			rst								),

	.dma_wr_req_in_valid		(			TX_REQ_dma_wr_req_in_valid		),
	.dma_wr_req_in_head			(			TX_REQ_dma_wr_req_in_head		),
	.dma_wr_req_in_data			(			TX_REQ_dma_wr_req_in_data		),
	.dma_wr_req_in_last			(			TX_REQ_dma_wr_req_in_last		),
	.dma_wr_req_in_ready		(			TX_REQ_dma_wr_req_in_ready		),

	.dma_wr_req_out_valid		(			TX_REQ_dma_wr_req_out_valid		),
	.dma_wr_req_out_head		(			TX_REQ_dma_wr_req_out_head		),
	.dma_wr_req_out_data		(			TX_REQ_dma_wr_req_out_data		),
	.dma_wr_req_out_last		(			TX_REQ_dma_wr_req_out_last		),
	.dma_wr_req_out_ready		(			TX_REQ_dma_wr_req_out_ready		)
);

DMAWrReqChannel DMAWrReqChannel_RX_REQ( 	//512 to 256
	.clk						(			clk								),
	.rst						(			rst								),

	.dma_wr_req_in_valid		(			RX_REQ_dma_wr_req_in_valid		),
	.dma_wr_req_in_head			(			RX_REQ_dma_wr_req_in_head		),
	.dma_wr_req_in_data			(			RX_REQ_dma_wr_req_in_data		),
	.dma_wr_req_in_last			(			RX_REQ_dma_wr_req_in_last		),
	.dma_wr_req_in_ready		(			RX_REQ_dma_wr_req_in_ready		),

	.dma_wr_req_out_valid		(			RX_REQ_dma_wr_req_out_valid		),
	.dma_wr_req_out_head		(			RX_REQ_dma_wr_req_out_head		),
	.dma_wr_req_out_data		(			RX_REQ_dma_wr_req_out_data		),
	.dma_wr_req_out_last		(			RX_REQ_dma_wr_req_out_last		),
	.dma_wr_req_out_ready		(			RX_REQ_dma_wr_req_out_ready		)
);

DMAWrReqChannel DMAWrReqChannel_RX_RESP( 	//512 to 256
	.clk						(			clk								),
	.rst						(			rst								),

	.dma_wr_req_in_valid		(			RX_RESP_dma_wr_req_in_valid		),
	.dma_wr_req_in_head			(			RX_RESP_dma_wr_req_in_head		),
	.dma_wr_req_in_data			(			RX_RESP_dma_wr_req_in_data		),
	.dma_wr_req_in_last			(			RX_RESP_dma_wr_req_in_last		),
	.dma_wr_req_in_ready		(			RX_RESP_dma_wr_req_in_ready		),

	.dma_wr_req_out_valid		(			RX_RESP_dma_wr_req_out_valid	),
	.dma_wr_req_out_head		(			RX_RESP_dma_wr_req_out_head		),
	.dma_wr_req_out_data		(			RX_RESP_dma_wr_req_out_data		),
	.dma_wr_req_out_last		(			RX_RESP_dma_wr_req_out_last		),
	.dma_wr_req_out_ready		(			RX_RESP_dma_wr_req_out_ready	)
);

DMARdRspChannel DMARdRspChannel_CEU( 	//512 to 256
	.clk						(			clk								),
	.rst						(			rst								),

	.dma_rd_rsp_in_valid		(			CEU_dma_rd_rsp_in_valid			),
	.dma_rd_rsp_in_head			(			CEU_dma_rd_rsp_in_head			),
	.dma_rd_rsp_in_data			(			CEU_dma_rd_rsp_in_data			),
	.dma_rd_rsp_in_last			(			CEU_dma_rd_rsp_in_last			),
	.dma_rd_rsp_in_ready		(			CEU_dma_rd_rsp_in_ready			),

	.dma_rd_rsp_out_valid		(			CEU_dma_rd_rsp_out_valid		),
	.dma_rd_rsp_out_head		(			CEU_dma_rd_rsp_out_head			),
	.dma_rd_rsp_out_data		(			CEU_dma_rd_rsp_out_data			),
	.dma_rd_rsp_out_last		(			CEU_dma_rd_rsp_out_last			),
	.dma_rd_rsp_out_ready		(			CEU_dma_rd_rsp_out_ready		)
);

DMARdRspChannel DMARdRspChannel_SQ( 	//512 to 256
	.clk						(			clk								),
	.rst						(			rst								),

	.dma_rd_rsp_in_valid		(			SQ_dma_rd_rsp_in_valid			),
	.dma_rd_rsp_in_head			(			SQ_dma_rd_rsp_in_head			),
	.dma_rd_rsp_in_data			(			SQ_dma_rd_rsp_in_data			),
	.dma_rd_rsp_in_last			(			SQ_dma_rd_rsp_in_last			),
	.dma_rd_rsp_in_ready		(			SQ_dma_rd_rsp_in_ready			),

	.dma_rd_rsp_out_valid		(			SQ_dma_rd_rsp_out_valid			),
	.dma_rd_rsp_out_head		(			SQ_dma_rd_rsp_out_head			),
	.dma_rd_rsp_out_data		(			SQ_dma_rd_rsp_out_data			),
	.dma_rd_rsp_out_last		(			SQ_dma_rd_rsp_out_last			),
	.dma_rd_rsp_out_ready		(			SQ_dma_rd_rsp_out_ready			)
);

DMARdRspChannel DMARdRspChannel_RQ( 	//512 to 256
	.clk						(			clk								),
	.rst						(			rst								),

	.dma_rd_rsp_in_valid		(			RQ_dma_rd_rsp_in_valid			),
	.dma_rd_rsp_in_head			(			RQ_dma_rd_rsp_in_head			),
	.dma_rd_rsp_in_data			(			RQ_dma_rd_rsp_in_data			),
	.dma_rd_rsp_in_last			(			RQ_dma_rd_rsp_in_last			),
	.dma_rd_rsp_in_ready		(			RQ_dma_rd_rsp_in_ready			),

	.dma_rd_rsp_out_valid		(			RQ_dma_rd_rsp_out_valid			),
	.dma_rd_rsp_out_head		(			RQ_dma_rd_rsp_out_head			),
	.dma_rd_rsp_out_data		(			RQ_dma_rd_rsp_out_data			),
	.dma_rd_rsp_out_last		(			RQ_dma_rd_rsp_out_last			),
	.dma_rd_rsp_out_ready		(			RQ_dma_rd_rsp_out_ready			)
);

DMARdRspChannel DMARdRspChannel_QPC( 	//512 to 256
	.clk						(			clk								),
	.rst						(			rst								),

	.dma_rd_rsp_in_valid		(			QPC_dma_rd_rsp_in_valid			),
	.dma_rd_rsp_in_head			(			QPC_dma_rd_rsp_in_head			),
	.dma_rd_rsp_in_data			(			QPC_dma_rd_rsp_in_data			),
	.dma_rd_rsp_in_last			(			QPC_dma_rd_rsp_in_last			),
	.dma_rd_rsp_in_ready		(			QPC_dma_rd_rsp_in_ready			),

	.dma_rd_rsp_out_valid		(			QPC_dma_rd_rsp_out_valid		),
	.dma_rd_rsp_out_head		(			QPC_dma_rd_rsp_out_head			),
	.dma_rd_rsp_out_data		(			QPC_dma_rd_rsp_out_data			),
	.dma_rd_rsp_out_last		(			QPC_dma_rd_rsp_out_last			),
	.dma_rd_rsp_out_ready		(			QPC_dma_rd_rsp_out_ready		)
);

DMARdRspChannel DMARdRspChannel_CQC( 	//512 to 256
	.clk						(			clk								),
	.rst						(			rst								),

	.dma_rd_rsp_in_valid		(			CQC_dma_rd_rsp_in_valid			),
	.dma_rd_rsp_in_head			(			CQC_dma_rd_rsp_in_head			),
	.dma_rd_rsp_in_data			(			CQC_dma_rd_rsp_in_data			),
	.dma_rd_rsp_in_last			(			CQC_dma_rd_rsp_in_last			),
	.dma_rd_rsp_in_ready		(			CQC_dma_rd_rsp_in_ready			),

	.dma_rd_rsp_out_valid		(			CQC_dma_rd_rsp_out_valid		),
	.dma_rd_rsp_out_head		(			CQC_dma_rd_rsp_out_head			),
	.dma_rd_rsp_out_data		(			CQC_dma_rd_rsp_out_data			),
	.dma_rd_rsp_out_last		(			CQC_dma_rd_rsp_out_last			),
	.dma_rd_rsp_out_ready		(			CQC_dma_rd_rsp_out_ready		)
);

DMARdRspChannel DMARdRspChannel_EQC( 	//512 to 256
	.clk						(			clk								),
	.rst						(			rst								),

	.dma_rd_rsp_in_valid		(			EQC_dma_rd_rsp_in_valid			),
	.dma_rd_rsp_in_head			(			EQC_dma_rd_rsp_in_head			),
	.dma_rd_rsp_in_data			(			EQC_dma_rd_rsp_in_data			),
	.dma_rd_rsp_in_last			(			EQC_dma_rd_rsp_in_last			),
	.dma_rd_rsp_in_ready		(			EQC_dma_rd_rsp_in_ready			),

	.dma_rd_rsp_out_valid		(			EQC_dma_rd_rsp_out_valid		),
	.dma_rd_rsp_out_head		(			EQC_dma_rd_rsp_out_head			),
	.dma_rd_rsp_out_data		(			EQC_dma_rd_rsp_out_data			),
	.dma_rd_rsp_out_last		(			EQC_dma_rd_rsp_out_last			),
	.dma_rd_rsp_out_ready		(			EQC_dma_rd_rsp_out_ready		)
);

DMARdRspChannel DMARdRspChannel_MPT( 	//512 to 256
	.clk						(			clk								),
	.rst						(			rst								),

	.dma_rd_rsp_in_valid		(			MPT_dma_rd_rsp_in_valid			),
	.dma_rd_rsp_in_head			(			MPT_dma_rd_rsp_in_head			),
	.dma_rd_rsp_in_data			(			MPT_dma_rd_rsp_in_data			),
	.dma_rd_rsp_in_last			(			MPT_dma_rd_rsp_in_last			),
	.dma_rd_rsp_in_ready		(			MPT_dma_rd_rsp_in_ready			),

	.dma_rd_rsp_out_valid		(			MPT_dma_rd_rsp_out_valid		),
	.dma_rd_rsp_out_head		(			MPT_dma_rd_rsp_out_head			),
	.dma_rd_rsp_out_data		(			MPT_dma_rd_rsp_out_data			),
	.dma_rd_rsp_out_last		(			MPT_dma_rd_rsp_out_last			),
	.dma_rd_rsp_out_ready		(			MPT_dma_rd_rsp_out_ready		)
);

DMARdRspChannel DMARdRspChannel_MTT( 	//512 to 256
	.clk						(			clk								),
	.rst						(			rst								),

	.dma_rd_rsp_in_valid		(			MTT_dma_rd_rsp_in_valid			),
	.dma_rd_rsp_in_head			(			MTT_dma_rd_rsp_in_head			),
	.dma_rd_rsp_in_data			(			MTT_dma_rd_rsp_in_data			),
	.dma_rd_rsp_in_last			(			MTT_dma_rd_rsp_in_last			),
	.dma_rd_rsp_in_ready		(			MTT_dma_rd_rsp_in_ready			),

	.dma_rd_rsp_out_valid		(			MTT_dma_rd_rsp_out_valid		),
	.dma_rd_rsp_out_head		(			MTT_dma_rd_rsp_out_head			),
	.dma_rd_rsp_out_data		(			MTT_dma_rd_rsp_out_data			),
	.dma_rd_rsp_out_last		(			MTT_dma_rd_rsp_out_last			),
	.dma_rd_rsp_out_ready		(			MTT_dma_rd_rsp_out_ready		)
);

DMARdRspChannel DMARdRspChannel_TX_REQ( 	//512 to 256
	.clk						(			clk									),
	.rst						(			rst									),

	.dma_rd_rsp_in_valid		(			TX_REQ_dma_rd_rsp_in_valid			),
	.dma_rd_rsp_in_head			(			TX_REQ_dma_rd_rsp_in_head			),
	.dma_rd_rsp_in_data			(			TX_REQ_dma_rd_rsp_in_data			),
	.dma_rd_rsp_in_last			(			TX_REQ_dma_rd_rsp_in_last			),
	.dma_rd_rsp_in_ready		(			TX_REQ_dma_rd_rsp_in_ready			),

	.dma_rd_rsp_out_valid		(			TX_REQ_dma_rd_rsp_out_valid			),
	.dma_rd_rsp_out_head		(			TX_REQ_dma_rd_rsp_out_head			),
	.dma_rd_rsp_out_data		(			TX_REQ_dma_rd_rsp_out_data			),
	.dma_rd_rsp_out_last		(			TX_REQ_dma_rd_rsp_out_last			),
	.dma_rd_rsp_out_ready		(			TX_REQ_dma_rd_rsp_out_ready			)
);

DMARdRspChannel DMARdRspChannel_TX_RESP( 	//512 to 256
	.clk						(			clk									),
	.rst						(			rst									),

	.dma_rd_rsp_in_valid		(			TX_RESP_dma_rd_rsp_in_valid			),
	.dma_rd_rsp_in_head			(			TX_RESP_dma_rd_rsp_in_head			),
	.dma_rd_rsp_in_data			(			TX_RESP_dma_rd_rsp_in_data			),
	.dma_rd_rsp_in_last			(			TX_RESP_dma_rd_rsp_in_last			),
	.dma_rd_rsp_in_ready		(			TX_RESP_dma_rd_rsp_in_ready			),

	.dma_rd_rsp_out_valid		(			TX_RESP_dma_rd_rsp_out_valid		),
	.dma_rd_rsp_out_head		(			TX_RESP_dma_rd_rsp_out_head			),
	.dma_rd_rsp_out_data		(			TX_RESP_dma_rd_rsp_out_data			),
	.dma_rd_rsp_out_last		(			TX_RESP_dma_rd_rsp_out_last			),
	.dma_rd_rsp_out_ready		(			TX_RESP_dma_rd_rsp_out_ready		)
);

endmodule