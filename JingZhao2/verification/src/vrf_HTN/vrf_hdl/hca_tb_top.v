`timescale 1ns/100ps
//CREATE INFORMATION
//------------------------------------------------------------------------------------
//
//  (C) COPYRIGHT 2021 BY ICT-HPC CORPORATION ALL RIGHTS RESERVED
//  DATE     : 2021-01-26
//  AUTHOR   : mazhenlong@ncic.ac.cn
//  FILENAME : hca_tb_top.v
//  FUNCTION : This file supplies the top module of testbench of HCA.
//
//------------------------------------------------------------------------------------

//CHANGE HISTORY
//------------------------------------------------------------------------------------
//
//  AUTHOR          DATE          VERSION          REASON
//  mazhenlong      2021-01-26    v1.0             create
//  mazhenlong      2021-03-22    v1.1             add `RST_DELAY and `AFTER_RST_DELAY
//  mazhenlong      2021-03-24    v1.2             change ports connected to dut to _dut
//  mazhenlong      2022-01-27    v2               support multi host
//  mazhenlong      2022-09-14    v3               expand line width from 256 to 1024
//
//------------------------------------------------------------------------------------

`ifndef __HCA_TB_TOP__
`define __HCA_TB_TOP__

//------------------------------------------------------------------------------------
//
// MODULE: hca_tb_top
//
//------------------------------------------------------------------------------------
module hca_tb_top #(
    parameter C_DATA_WIDTH = `DATA_WIDTH,
    parameter KEEP_WIDTH = C_DATA_WIDTH / 32,
    parameter DMA_HEAD_WIDTH = 128,
    parameter AXIS_TUSER_WIDTH = 128,
    parameter PAGE_SIZE_LOG = 12
);
    import uvm_pkg::*; // this line can be deleted with everything doing well, no idea about this.
    
    hca_interface #(
        .C_DATA_WIDTH    (C_DATA_WIDTH),
        .KEEP_WIDTH      (`DATA_WIDTH / 32), // C_DATA_WIDTH /32
        .DMA_HEAD_WIDTH  (DMA_HEAD_WIDTH),
        .AXIS_TUSER_WIDTH(AXIS_TUSER_WIDTH),
        .PAGE_SIZE_LOG   (PAGE_SIZE_LOG)
    ) hca_if_a();

    hca_interface #(
        .C_DATA_WIDTH    (C_DATA_WIDTH),
        .KEEP_WIDTH      (`DATA_WIDTH / 32), // C_DATA_WIDTH /32
        .DMA_HEAD_WIDTH  (DMA_HEAD_WIDTH),
        .AXIS_TUSER_WIDTH(AXIS_TUSER_WIDTH),
        .PAGE_SIZE_LOG   (PAGE_SIZE_LOG)
    ) hca_if_b();

    hca_dut #(
        .C_DATA_WIDTH(C_DATA_WIDTH),         // RX/TX interface data width
        .KEEP_WIDTH  (`DATA_WIDTH / 32),
        .DMA_HEAD_WIDTH(DMA_HEAD_WIDTH)
    ) dut (
        .a_sys_clk                          (hca_if_a.sys_clk               ),
        .a_pcie_clk                         (hca_if_a.pcie_clk              ),
        .a_rdma_clk                         (hca_if_a.rdma_clk              ),
        .a_user_reset                       (hca_if_a.user_reset            ),
        .a_user_lnk_up                      (hca_if_a.user_lnk_up           ),
        .a_cmd_rst                          (hca_if_a.cmd_rst               ),

        .a_cfg_max_payload                  (hca_if_a.cfg_max_payload       ),
        .a_cfg_max_read_req                 (hca_if_a.cfg_max_read_req      ),

        .a_s_axis_rq_tlast                  (hca_if_a.s_axis_rq_tlast_dut       ),
        .a_s_axis_rq_tdata                  (hca_if_a.s_axis_rq_tdata_dut       ),
        .a_s_axis_rq_tuser                  (hca_if_a.s_axis_rq_tuser_dut       ),
        .a_s_axis_rq_tkeep                  (hca_if_a.s_axis_rq_tkeep_dut       ),
        .a_s_axis_rq_tready                 (hca_if_a.s_axis_rq_tready_dut      ),
        .a_s_axis_rq_tvalid                 (hca_if_a.s_axis_rq_tvalid_dut      ),

        .a_m_axis_rc_tdata                  (hca_if_a.m_axis_rc_tdata_dut       ),
        .a_m_axis_rc_tuser                  (hca_if_a.m_axis_rc_tuser_dut       ),
        .a_m_axis_rc_tlast                  (hca_if_a.m_axis_rc_tlast_dut       ),
        .a_m_axis_rc_tkeep                  (hca_if_a.m_axis_rc_tkeep_dut       ),
        .a_m_axis_rc_tvalid                 (hca_if_a.m_axis_rc_tvalid_dut      ),
        .a_m_axis_rc_tready                 (hca_if_a.m_axis_rc_tready_dut      ),

        .a_m_axis_cq_tdata                  (hca_if_a.m_axis_cq_tdata_dut       ),
        .a_m_axis_cq_tuser                  (hca_if_a.m_axis_cq_tuser_dut       ),
        .a_m_axis_cq_tlast                  (hca_if_a.m_axis_cq_tlast_dut       ),
        .a_m_axis_cq_tkeep                  (hca_if_a.m_axis_cq_tkeep_dut       ),
        .a_m_axis_cq_tvalid                 (hca_if_a.m_axis_cq_tvalid_dut      ),
        .a_m_axis_cq_tready                 (hca_if_a.m_axis_cq_tready_dut      ),

        .a_s_axis_cc_tdata                  (hca_if_a.s_axis_cc_tdata_dut       ),
        .a_s_axis_cc_tuser                  (hca_if_a.s_axis_cc_tuser_dut       ),
        .a_s_axis_cc_tlast                  (hca_if_a.s_axis_cc_tlast_dut       ),
        .a_s_axis_cc_tkeep                  (hca_if_a.s_axis_cc_tkeep_dut       ),
        .a_s_axis_cc_tvalid                 (hca_if_a.s_axis_cc_tvalid_dut      ),
        .a_s_axis_cc_tready                 (hca_if_a.s_axis_cc_tready_dut      ),

        .b_sys_clk                          (hca_if_b.sys_clk                   ),
        .b_pcie_clk                         (hca_if_b.pcie_clk                  ),
        .b_rdma_clk                         (hca_if_b.rdma_clk                  ),
        .b_user_reset                       (hca_if_b.user_reset                ),
        .b_user_lnk_up                      (hca_if_b.user_lnk_up               ),
        .b_cmd_rst                          (hca_if_b.cmd_rst                   ),

        .b_cfg_max_payload                  (hca_if_b.cfg_max_payload       ),
        .b_cfg_max_read_req                 (hca_if_b.cfg_max_read_req      ),

        .b_s_axis_rq_tlast                  (hca_if_b.s_axis_rq_tlast_dut       ),
        .b_s_axis_rq_tdata                  (hca_if_b.s_axis_rq_tdata_dut       ),
        .b_s_axis_rq_tuser                  (hca_if_b.s_axis_rq_tuser_dut       ),
        .b_s_axis_rq_tkeep                  (hca_if_b.s_axis_rq_tkeep_dut       ),
        .b_s_axis_rq_tready                 (hca_if_b.s_axis_rq_tready_dut      ),
        .b_s_axis_rq_tvalid                 (hca_if_b.s_axis_rq_tvalid_dut      ),

        .b_m_axis_rc_tdata                  (hca_if_b.m_axis_rc_tdata_dut       ),
        .b_m_axis_rc_tuser                  (hca_if_b.m_axis_rc_tuser_dut       ),
        .b_m_axis_rc_tlast                  (hca_if_b.m_axis_rc_tlast_dut       ),
        .b_m_axis_rc_tkeep                  (hca_if_b.m_axis_rc_tkeep_dut       ),
        .b_m_axis_rc_tvalid                 (hca_if_b.m_axis_rc_tvalid_dut      ),
        .b_m_axis_rc_tready                 (hca_if_b.m_axis_rc_tready_dut      ),

        .b_m_axis_cq_tdata                  (hca_if_b.m_axis_cq_tdata_dut       ),
        .b_m_axis_cq_tuser                  (hca_if_b.m_axis_cq_tuser_dut       ),
        .b_m_axis_cq_tlast                  (hca_if_b.m_axis_cq_tlast_dut       ),
        .b_m_axis_cq_tkeep                  (hca_if_b.m_axis_cq_tkeep_dut       ),
        .b_m_axis_cq_tvalid                 (hca_if_b.m_axis_cq_tvalid_dut      ),
        .b_m_axis_cq_tready                 (hca_if_b.m_axis_cq_tready_dut      ),

        .b_s_axis_cc_tdata                  (hca_if_b.s_axis_cc_tdata_dut       ),
        .b_s_axis_cc_tuser                  (hca_if_b.s_axis_cc_tuser_dut       ),
        .b_s_axis_cc_tlast                  (hca_if_b.s_axis_cc_tlast_dut       ),
        .b_s_axis_cc_tkeep                  (hca_if_b.s_axis_cc_tkeep_dut       ),
        .b_s_axis_cc_tvalid                 (hca_if_b.s_axis_cc_tvalid_dut      ),
        .b_s_axis_cc_tready                 (hca_if_b.s_axis_cc_tready_dut      )
    );

    function string get_time();
        string current_time;
        int fp;
        $system("date +%Y-%m-%d' '%H:%M:%S > temp_time");
        fp = $fopen("temp_time", "r");
        $fgets(current_time, fp);
        $fclose(fp);
        $system("rm temp_time");
        return current_time;
    endfunction: get_time

    class report_catcher extends uvm_report_catcher;
        string begin_time;
        string end_time;
        int fp;
        string case_id;
        int a;
        string filename;
        virtual function action_e catch();
            if (get_severity() == UVM_FATAL) begin
                if ($value$plusargs("CASEID=%s", case_id));
                filename = $sformatf("end_time%s", case_id);
                $system({"date +%Y-%m-%d' '%H:%M:%S > ", filename});
                fp = $fopen(filename, "r");
                $fgets(end_time, fp);
                $fclose(fp);
                $system($sformatf("rm %s", filename));
                `uvm_info("TIME_INFO", $sformatf("begin time: %s", begin_time), UVM_LOW);
                `uvm_info("TIME_INFO", $sformatf("end time: %s", end_time), UVM_LOW);
                $system($sformatf("%s >> fatal_case", case_id));
            end
            return THROW;
        endfunction: catch
    endclass: report_catcher

    initial begin
        report_catcher catcher;
        string begin_time;
        string end_time;
        int fp;

        $system("date +%Y-%m-%d' '%H:%M:%S > begin_time");
        fp = $fopen("begin_time", "r");
        $fgets(begin_time, fp);
        $fclose(fp);
        $system("rm begin_time");
        catcher = new();

        catcher.begin_time = begin_time;

        // if UVM_FATAL is produced, get system time in catcher
        uvm_report_cb::add(null, catcher);
        run_test();

        // if verification ends successfully, get system time here
        $system("date +%Y-%m-%d' '%H:%M:%S > end_time");
        fp = $fopen("end", "r");
        $fgets(end_time, fp);
        $fclose(fp);
        $system("rm end_time");
        `uvm_info("TIME_INFO", $sformatf("begin time: %s", begin_time), UVM_LOW);
        `uvm_info("TIME_INFO", $sformatf("end time: %s", end_time), UVM_LOW);
    end

    initial begin
        uvm_config_db#(virtual hca_interface)::set(uvm_root::get(), "*.env.sub_env[0]*", "virtual_if", hca_if_a);
        uvm_config_db#(virtual hca_interface)::set(uvm_root::get(), "*.env.sub_env[1]*", "virtual_if", hca_if_b);
    end

    initial begin
        hca_if_a.user_reset   <= 1'b1;
        hca_if_a.user_lnk_up  <= 1'b0;
        hca_if_a.veri_en      <= 1'b0;
        hca_if_a.global_stop  <= 1'b0;
        # `RST_DELAY;
        hca_if_a.user_reset   <= 1'b0;
        hca_if_a.user_lnk_up  <= 1'b1;
        `uvm_info("NOTICE", "reset finished...", UVM_LOW)
        # `AFTER_RST_DELAY;
        `uvm_info("NOTICE", "verification enabled...", UVM_LOW)
        hca_if_a.veri_en      <= 1'b1;
    end

    initial begin
        hca_if_b.user_reset   <= 1'b1;
        hca_if_b.user_lnk_up  <= 1'b0;
        hca_if_b.veri_en      <= 1'b0;
        hca_if_b.global_stop  <= 1'b0;
        # `RST_DELAY;
        hca_if_b.user_reset   <= 1'b0;
        hca_if_b.user_lnk_up  <= 1'b1;
        `uvm_info("NOTICE", "reset finished...", UVM_LOW);
        # `AFTER_RST_DELAY;
        `uvm_info("NOTICE", "verification enabled...", UVM_LOW);
        hca_if_b.veri_en      <= 1'b1;
    end

    initial begin
        hca_if_a.m_axis_cq_tdata      <= 1'b0;
        hca_if_a.m_axis_cq_tuser      <= 1'b0;
        hca_if_a.m_axis_cq_tlast      <= 1'b0;
        hca_if_a.m_axis_cq_tkeep      <= 1'b0;
        hca_if_a.m_axis_cq_tvalid     <= 1'b0;

        hca_if_a.s_axis_cc_tready     <= 1'b0;

        hca_if_a.m_axis_rc_tdata      <= 1'b0;
        hca_if_a.m_axis_rc_tuser      <= 1'b0;
        hca_if_a.m_axis_rc_tlast      <= 1'b0;
        hca_if_a.m_axis_rc_tkeep      <= 1'b0;
        hca_if_a.m_axis_rc_tvalid     <= 1'b0;

        hca_if_a.s_axis_rq_tready     <= 1'b0;
    end

    initial begin
        hca_if_b.m_axis_cq_tdata      <= 1'b0;
        hca_if_b.m_axis_cq_tuser      <= 1'b0;
        hca_if_b.m_axis_cq_tlast      <= 1'b0;
        hca_if_b.m_axis_cq_tkeep      <= 1'b0;
        hca_if_b.m_axis_cq_tvalid     <= 1'b0;

        hca_if_b.s_axis_cc_tready     <= 1'b0;

        hca_if_b.m_axis_rc_tdata      <= 1'b0;
        hca_if_b.m_axis_rc_tuser      <= 1'b0;
        hca_if_b.m_axis_rc_tlast      <= 1'b0;
        hca_if_b.m_axis_rc_tkeep      <= 1'b0;
        hca_if_b.m_axis_rc_tvalid     <= 1'b0;

        hca_if_b.s_axis_rq_tready     <= 1'b0;
    end

    initial begin
        `ifndef SIMULATION
            `uvm_fatal("NO_DEF", "SIMULATION not defined!");
        `else 
            `uvm_info("DEF_INFO", "SIMULATION defined!", UVM_LOW);
        `endif
        // `ifndef FPGA_V7_VALIDATE
        //     `uvm_fatal("NO_DEF", "FPGA_V7_VALIDATE not defined!");
        // `else
        //     `uvm_info("DEF_INFO", "FPGA_V7_VALIDATE defined!", UVM_LOW);
        // `endif
    end


    // clock driver
    initial begin
        hca_if_a.sys_clk      <= 1'b1;
        hca_if_a.pcie_clk     <= 1'b1;
        hca_if_a.rdma_clk     <= 1'b1;
        hca_if_b.sys_clk      <= 1'b1;
        hca_if_b.pcie_clk     <= 1'b1;
        hca_if_b.rdma_clk     <= 1'b1;
    end
    always begin
        #(`PCIE_CLK_PERIOD / 2);
        hca_if_a.pcie_clk     <= ~hca_if_a.pcie_clk;
        hca_if_b.pcie_clk     <= ~hca_if_b.pcie_clk;
    end
    always begin
        #(`RDMA_CLK_PERIOD / 2);
        hca_if_a.sys_clk      <= ~hca_if_a.sys_clk;
        hca_if_b.sys_clk      <= ~hca_if_b.sys_clk;
    end
    always begin
        #(`RDMA_CLK_PERIOD / 2);
        hca_if_a.rdma_clk      <= ~hca_if_a.rdma_clk;
        hca_if_b.rdma_clk      <= ~hca_if_b.rdma_clk;
    end

reg         clk_td;
always @(posedge hca_if_a.sys_clk or negedge hca_if_a.sys_clk) begin
    clk_td <= #1 hca_if_a.sys_clk;
end 

   // initial begin
   //     $fsdbDumpvars(0, hca_tb_top);
   //     $fsdbDumpon();
   //     $fsdbDumpMDA();
   // end

    initial begin
        $vcdpluson();
        $vcdplusmemon();
        $vcdplusautoflushon();
    end

    initial begin
        /* This signal indicates the max payload size & max read request size
        *  agreed in the communication
        * 3'b000 -- 128 B
        * 3'b001 -- 256 B
        * 3'b010 -- 512 B
        * 3'b011 -- 1024B
        * 3'b100 -- 2048B
        * 3'b101 -- 4096B
        */
        hca_if_a.cfg_max_payload                     <= `MAX_PAYLOAD;
        hca_if_a.cfg_max_read_req                    <= `MAX_READ_REQ;
        hca_if_b.cfg_max_payload                     <= `MAX_PAYLOAD;
        hca_if_b.cfg_max_read_req                    <= `MAX_READ_REQ;
    end
endmodule: hca_tb_top
`endif
