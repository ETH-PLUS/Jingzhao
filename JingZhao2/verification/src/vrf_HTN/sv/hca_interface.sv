//CREATE INFORMATION
//----------------------------------------------------------------------------
//
//  (C) COPYRIGHT 2021 BY ICT-HPC CORPORATION ALL RIGHTS RESERVED
//  DATE     : 2021-01-14
//  AUTHOR   : mazhenlong@ncic.ac.cn
//  FILENAME : hca_interface.sv
//  FUNCTION : This file supplies the interface that communicates with DUT.
//
//----------------------------------------------------------------------------

//CHANGE HISTORY
//----------------------------------------------------------------------------
//
//  AUTHOR          DATE          VERSION          REASON
//  mazhenlong      2021-01-14    v1.0             create
//  mazhenlong      2021-03-24    v1.1             add time delay between dut
//                                                 and verification
//
//----------------------------------------------------------------------------
`timescale 1ns/100ps

//----------------------------------------------------------------------------
//
// INTERFACE: hca_interface
//
//----------------------------------------------------------------------------
interface hca_interface #(
    parameter C_DATA_WIDTH              = 256,
    parameter KEEP_WIDTH                = C_DATA_WIDTH /32,
    parameter DMA_HEAD_WIDTH            = 128,
    parameter AXIS_TUSER_WIDTH          = 128,
    // not visable from other module
    parameter PAGE_SIZE_LOG             = 12    // which means, 4K per page
);
    logic                      veri_en;
    logic                      global_stop;

    //-----------------------------------------------------
    // Verification Side Begin
    //-----------------------------------------------------
    logic                      sys_clk;
    logic                      pcie_clk;
    logic                      rdma_clk;
    logic                      user_reset;
    logic                      user_lnk_up;
    logic                      cmd_rst;
    /* -------Requester Request{begin}------- */
    /*  RQ tuser
     * |  59:28 |  27:24  |    23:16   |          15         |   14:13  |      12     |     11      |     10:8    |   7:4   |    3:0   |
     * | parity | seq_num | tph_st_tag | tph_indirect_tag_en | tph_type | tph_present | discontinue | addr_offset | last_be | first_be |
     * |   0    |   0     |     0      |          0          |     0    |      0      |      0      |      0      |         |          |
     */
    logic                       s_axis_rq_tvalid;
    logic                       s_axis_rq_tlast ;
    logic [C_DATA_WIDTH-1:0]    s_axis_rq_tdata ;
    logic [59            :0]    s_axis_rq_tuser ;
    logic [KEEP_WIDTH-1  :0]    s_axis_rq_tkeep ;
    logic                       s_axis_rq_tready;
    /* -------Requester Request{end}------- */

    /* -------Requester Completion{begin}------- */
    /*  RC tuser
     * |  74:43 |      42     |    41:38   |  37:34   |    33    |    32    |  31:0   |  
     * | parity | discontinue |  is_eof_1  | is_eof_0 | is_sof_1 | is_sof_0 | byte_en |
     * |        |   ignore    |  ignore    | ignore   |  ignore  |  ignore  |         |
     */
    logic                        m_axis_rc_tvalid;
    logic                        m_axis_rc_tlast ;
    logic [C_DATA_WIDTH-1:0]     m_axis_rc_tdata ;
    logic [74            :0]     m_axis_rc_tuser ;
    logic [KEEP_WIDTH-1  :0]     m_axis_rc_tkeep ;
    logic                        m_axis_rc_tready;
    /* -------Requester Completion{end}------- */

    /* -------Configuration Status Interface{begin}------- */
    logic [ 2:0]                  max_pyld_sz  ;//useful
    logic [ 2:0]                  max_rd_req_sz;//useful
    /* -------Configuration Status Interface{end}------- */

    /* -------Completer Request{begin}------- */
    /*  CQ tuser
     * |  84:53 |    52:45   |   44:43  |      42     |     41      | 40  |  39:8   |   7:4   |    3:0   |
     * | parity | tph_st_tag | tph_type | tph_present | discontinue | sop | byte_en | last_be | first_be |
     * |   0    |     0      |     0    |             |             |     | ignore  |         |          |
     */
    logic [C_DATA_WIDTH-1:0]     m_axis_cq_tdata;
    logic [84            :0]     m_axis_cq_tuser;
    logic                        m_axis_cq_tlast;
    logic [KEEP_WIDTH-1  :0]     m_axis_cq_tkeep;
    logic                        m_axis_cq_tvalid;
    logic                        m_axis_cq_tready;
    /* -------Completer Request{end}------- */

    /* -------Completer Completion{begin}------- */
    /*  CC tuser
     * |  32:1  |      0      |
     * | parity | discontinue |
     * | ignore |   ignore    |
     */
    logic [C_DATA_WIDTH-1:0]     s_axis_cc_tdata;
    logic [32            :0]     s_axis_cc_tuser;
    logic                        s_axis_cc_tlast;
    logic [KEEP_WIDTH-1  :0]     s_axis_cc_tkeep;
    logic                        s_axis_cc_tvalid;
    logic                        s_axis_cc_tready;
    /* -------Completer Completion{end}------- */
    ///////////////////////////////////////////////////////
    // Verification Side End
    ///////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////
    // DUV Side Begin
    ///////////////////////////////////////////////////////
    logic                        s_axis_rq_tvalid_dut;
    logic                        s_axis_rq_tlast_dut;
    logic [C_DATA_WIDTH-1:0]     s_axis_rq_tdata_dut;
    logic [59            :0]     s_axis_rq_tuser_dut;
    logic [KEEP_WIDTH-1  :0]     s_axis_rq_tkeep_dut;
    logic                        s_axis_rq_tready_dut;

    logic                        m_axis_rc_tvalid_dut;
    logic                        m_axis_rc_tlast_dut;
    logic [C_DATA_WIDTH-1:0]     m_axis_rc_tdata_dut;
    logic [74            :0]     m_axis_rc_tuser_dut;
    logic [KEEP_WIDTH-1  :0]     m_axis_rc_tkeep_dut;
    logic                        m_axis_rc_tready_dut;

    logic [C_DATA_WIDTH-1:0]     m_axis_cq_tdata_dut;
    logic [84            :0]     m_axis_cq_tuser_dut;
    logic                        m_axis_cq_tlast_dut;
    logic [KEEP_WIDTH-1  :0]     m_axis_cq_tkeep_dut;
    logic                        m_axis_cq_tvalid_dut;
    logic                        m_axis_cq_tready_dut;

    logic [C_DATA_WIDTH-1:0]     s_axis_cc_tdata_dut;
    logic [32            :0]     s_axis_cc_tuser_dut;
    logic                        s_axis_cc_tlast_dut;
    logic [KEEP_WIDTH-1  :0]     s_axis_cc_tkeep_dut;
    logic                        s_axis_cc_tvalid_dut;
    logic                        s_axis_cc_tready_dut;
    ///////////////////////////////////////////////////////
    // DUV Side End
    ///////////////////////////////////////////////////////

    //----------------------------------------------------------------------------------------------------------------//
    //  Configuration (CFG) Interface                                                                                 //
    //----------------------------------------------------------------------------------------------------------------//
    logic                              [2:0]     cfg_max_payload;
    logic                              [2:0]     cfg_max_read_req;

    initial begin
        $printtimescale;
    end

    // add a time delay from verification to DUT
    always @(*) begin
        s_axis_rq_tready_dut    <= `DL s_axis_rq_tready;

        m_axis_rc_tvalid_dut    <= `DL m_axis_rc_tvalid;
        m_axis_rc_tlast_dut     <= `DL m_axis_rc_tlast;
        m_axis_rc_tdata_dut     <= `DL m_axis_rc_tdata;
        m_axis_rc_tuser_dut     <= `DL m_axis_rc_tuser;
        m_axis_rc_tkeep_dut     <= `DL m_axis_rc_tkeep;

        m_axis_cq_tdata_dut     <= `DL m_axis_cq_tdata;
        m_axis_cq_tuser_dut     <= `DL m_axis_cq_tuser;
        m_axis_cq_tlast_dut     <= `DL m_axis_cq_tlast;
        m_axis_cq_tkeep_dut     <= `DL m_axis_cq_tkeep;
        m_axis_cq_tvalid_dut    <= `DL m_axis_cq_tvalid;

        s_axis_cc_tready_dut    <= `DL s_axis_cc_tready;
    end

    always @(*) begin
        s_axis_rq_tvalid        <= s_axis_rq_tvalid_dut;
        s_axis_rq_tlast         <= s_axis_rq_tlast_dut;
        s_axis_rq_tdata         <= s_axis_rq_tdata_dut;
        s_axis_rq_tuser         <= s_axis_rq_tuser_dut;
        s_axis_rq_tkeep         <= s_axis_rq_tkeep_dut;

        m_axis_rc_tready        <= m_axis_rc_tready_dut;

        m_axis_cq_tready        <= m_axis_cq_tready_dut;

        s_axis_cc_tdata         <= s_axis_cc_tdata_dut;
        s_axis_cc_tuser         <= s_axis_cc_tuser_dut;
        s_axis_cc_tlast         <= s_axis_cc_tlast_dut;
        s_axis_cc_tkeep         <= s_axis_cc_tkeep_dut;
        s_axis_cc_tvalid        <= s_axis_cc_tvalid_dut;
    end
endinterface: hca_interface