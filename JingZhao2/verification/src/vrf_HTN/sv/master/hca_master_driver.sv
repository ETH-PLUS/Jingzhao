//CREATE INFORMATION
//--------------------------------------------------------------------------------------
//
//  (C) COPYRIGHT 2021 BY ICT-HPC CORPORATION ALL RIGHTS RESERVED
//  DATE     : 2021-01-19
//  AUTHOR   : mazhenlong@ncic.ac.cn
//  FILENAME : hca_master_driver.sv
//  FUNCTION : This file supplies the driver of registers, transferring a pcie
//             packet to signals on ports of DUT.
//
//--------------------------------------------------------------------------------------

//CHANGE HISTORY
//--------------------------------------------------------------------------------------
//
//  AUTHOR          DATE            VERSION         REASON
//  mazhenlong      2021-01-19      v1.0            create
//  mazhenlong      2021-03-03      v1.1            rewrite drive_reg_item
//  mazhenlong      2021-03-22      v1.2            finish the procedure of receiving read 
//                                                  response
//  mazhenlong      2021-04-01      v1.3            change filename and reg_* to mst_*
//  mazhenlong      2022-01-28      v2              add multi host support: v_if[]
//
//--------------------------------------------------------------------------------------


`ifndef __HCA_MASTER_DRIVER__
`define __HCA_MASTER_DRIVER__

//----------------------------------------------------------------------------------------
//
// CLASS: hca_master_driver
//
//----------------------------------------------------------------------------------------
class hca_master_driver extends uvm_driver #(hca_pcie_item);
    virtual hca_interface v_if;
    hca_pcie_item         req_item;

    // hca_memory mem;

    mailbox cmd_done;

    uvm_analysis_port #(hca_pcie_item) port2rm_cfg;
    uvm_analysis_port #(hca_pcie_item) port2rm_comm;

    `uvm_component_utils_begin(hca_master_driver)
    `uvm_component_utils_end

    //------------------------------------------------------------------------------
    // function name : new
    // function      : constructor
    // invoked       : invoked when instantiates the class
    //------------------------------------------------------------------------------
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    //------------------------------------------------------------------------------
    // function name : build_phase
    // function      : build_phase in uvm library, instantiates port and get virtual
    //                 interface.
    // invoked       : automatically by uvm
    //------------------------------------------------------------------------------
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(virtual hca_interface)::get(this, "", "virtual_if", v_if)) begin
            `uvm_fatal("NOVIF", {"virtual interface must be set for: ",get_full_name(),".v_if!"});
        end
        port2rm_cfg = new("port2rm_cfg", this);
        port2rm_comm = new("port2rm_comm", this);
        // cmd_done = new();
        // uvm_config_db#(mailbox)::set(uvm_root::get(), "*.env.sub_env[*].mst_agt.mst_sqr*", "mbx_cmd_done", cmd_done);
        // `uvm_info("PARAM_INFO", $sformatf("uvm_config_db get waiting! full name: %s.", get_full_name()), UVM_LOW);
        if(!uvm_config_db#(mailbox)::get(null, get_full_name(), "mbx_cmd_done", cmd_done)) begin
            `uvm_fatal("NO_MBX", "mailbox not get in master_driver!");
        end
        // `uvm_info("NOTICE", {"build phase finished in ", get_full_name}, UVM_LOW)
    endfunction: build_phase

    //------------------------------------------------------------------------------
    // task name     : run_phase
    // function      : run_phase in uvm library, sends the pcie items to DUT
    // invoked       : invoked by uvm automaticly
    //------------------------------------------------------------------------------
    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        `uvm_info("NOTICE", {"run phase begin in ", get_full_name}, UVM_LOW)
        @ (posedge v_if.veri_en);
        `uvm_info("NOTICE", {"veri_en enabled in ", get_full_name}, UVM_LOW);
        forever begin
            @ (posedge v_if.pcie_clk);
            `uvm_info("NOTICE", "before get_next_item...", UVM_LOW);
            seq_item_port.get_next_item(req_item);
            `uvm_info("NOTICE", {"req_item get in ", get_full_name}, UVM_LOW);
            // if (req_item.item_type == DOORBELL) begin
            //     if (req_item.db.host_id == 0) begin
            //         for (int i = 0; i < `CFG_COMM_GAP; i++) begin
            //             @ (posedge v_if.pcie_clk);
            //         end
            //     end
            // end
            drive_item(req_item);
            if (req_item.item_type == GLOBAL_STOP) begin
                `uvm_info("NOTICE", "global stop item received in master driver!", UVM_LOW);
                v_if.global_stop = 1'b1;
                seq_item_port.item_done();
                break;
            end
            seq_item_port.item_done();
            for (int i = 0; i < `CFG_GAP; i++) begin
                @ (posedge v_if.pcie_clk);
            end
        end
        `uvm_info("NOTICE", "master driver run_phase end!", UVM_LOW);
        phase.drop_objection(this);
    endtask: run_phase

    //------------------------------------------------------------------------------
    // task name     : drive_item
    // function      : send the pcie items to DUT
    // invoked       : invoked by run_phase
    //------------------------------------------------------------------------------
    task drive_item(hca_pcie_item req_item);
        bit     [`DATA_WIDTH-1: 0]      temp_wr_data;
        bit     [`DATA_WIDTH-1: 0]      temp_rd_data;
        hca_pcie_item                   item2rm;

        bit [31:0] parity;
        int i, j, m, n;
        int sent_dw_num = 0;

        // send req_item to reference model
        item2rm = hca_pcie_item::type_id::create("item2rm");
        // item2rm.item_type == DMA_RD;
        item2rm.copy(req_item);
        item2rm.copy_struct(req_item);
        if (item2rm.item_type == HCR) begin
            // `uvm_info("NOTICE", "config item send to ref model from master driver begin!", UVM_LOW);
            port2rm_cfg.write(item2rm);
            // `uvm_info("NOTICE", "config item send to ref model from master driver finish!", UVM_LOW);
        end
        else if (item2rm.item_type == DOORBELL) begin
            // `uvm_info("NOTICE", "comm item send to ref model from master driver begin!", UVM_LOW);
            port2rm_comm.write(item2rm);
            // `uvm_info("NOTICE", "comm item send to ref model from master driver finish!", UVM_LOW);
        end
        else if (item2rm.item_type == GLOBAL_STOP) begin
            port2rm_comm.write(item2rm);
            port2rm_cfg.write(item2rm);
            `uvm_info("NOTICE", "global stop item sent to ref model!", UVM_LOW);
            return;
        end
        else begin
            `uvm_fatal("ITEM_TYPE_ERROR", $sformatf("illegal item_type in master driver! item2rm item_type: %h", item2rm.item_type));
        end
        // `uvm_info("NOTICE", {"port2rm write finished in ", get_full_name}, UVM_LOW);


        // drive signal to duv
        if (req_item.cq_req_type == MEM_WR) begin
            `uvm_info("NOTICE", {"MEM_WR begin in ", get_full_name()}, UVM_LOW)
            if (req_item.item_type == HCR) begin
                drive_hcr_item(req_item);
            end
            else if (req_item.item_type == DOORBELL) begin
                drive_db_item(req_item);
            end
            else begin
                `uvm_error("ILG_REQ_TYP", "illegal master driver input req item type!");
            end
            // drive_item_to_dut(req_item);
        end
        else begin
            `uvm_error("ILG_REQ_TYP", "illegal master driver input req item cq_req_type!");
        end
    endtask: drive_item

    //------------------------------------------------------------------------------
    // task name     : drive_hcr_item
    // function      : send the pcie items containint hcr content to DUT
    // invoked       : invoked by drive_item
    //------------------------------------------------------------------------------
    task drive_hcr_item(hca_pcie_item req_item);
        bit     [`DATA_WIDTH-1: 0]      temp_wr_data;
        bit     [`DATA_WIDTH-1: 0]      temp_rd_data;
        bit     [63:0]                  temp_addr;
        bit [31:0] parity;
        int i, j, m, n;
        int sent_dw_num = 0;
        `uvm_info("NOTICE", {"drive HCR item begin in ", get_full_name()}, UVM_LOW);
        temp_addr = req_item.cq_addr;
        temp_wr_data = req_item.data_payload.pop_front();
        for (int i = 0; i < `HCR_BYTE_SIZE / `DW_BYTE_SIZE; i++) begin
            // `uvm_info("NOTICE", {"MEM_WR beat ", get_full_name()}, UVM_LOW)
            // set tlast
            v_if.m_axis_cq_tlast = 1'b1;

            // set tvalid
            v_if.m_axis_cq_tvalid <= 1'b1;

            // set tkeep
            v_if.m_axis_cq_tkeep = 8'b0001_1111;

            // set tdata
            v_if.m_axis_cq_tdata[1:0]           = req_item.cq_addr_type;
            v_if.m_axis_cq_tdata[63:2]          = temp_addr[63:2];
            v_if.m_axis_cq_tdata[74:64]         = 11'b000_0000_0001;
            v_if.m_axis_cq_tdata[78:75]         = req_item.cq_req_type;
            v_if.m_axis_cq_tdata[79]            = 1'b0;
            v_if.m_axis_cq_tdata[87:80]         = req_item.cq_device;
            v_if.m_axis_cq_tdata[95:88]         = req_item.cq_bus;
            v_if.m_axis_cq_tdata[103:96]        = req_item.cq_tag;
            v_if.m_axis_cq_tdata[111:104]       = req_item.cq_target_function;
            v_if.m_axis_cq_tdata[114:112]       = req_item.cq_bar_id;
            v_if.m_axis_cq_tdata[120:115]       = req_item.cq_bar_aperture;
            v_if.m_axis_cq_tdata[123:121]       = req_item.cq_tc;
            v_if.m_axis_cq_tdata[126:124]       = req_item.cq_attr;
            v_if.m_axis_cq_tdata[127]           = 1'b0;
            v_if.m_axis_cq_tdata[159:128]       = temp_wr_data[i * 32 + 31 -: 32];
            v_if.m_axis_cq_tdata[255:160]       = 0;

            temp_addr = temp_addr + 4;

            // set tuser
            /*  CQ tuser
            * |  84:53 |    52:45   |   44:43  |      42     |     41      | 40  |  39:8   |   7:4   |    3:0   |
            * | parity | tph_st_tag | tph_type | tph_present | discontinue | sop | byte_en | last_be | first_be |
            * |        |     0      |     0    |   ignore    |   ignore    |     | ignore  |         |          |
            */
            for (m = 0; m < 32; m++) begin
                for (n = 0; n < 8; n++) begin
                    if (v_if.m_axis_cq_tdata[m * 8 + n] == 1'b1) begin
                        parity[m] = ~parity[m];
                    end
                end
            end
            v_if.m_axis_cq_tuser[84:53]         = parity; 
            v_if.m_axis_cq_tuser[52:41]         = 0;
            v_if.m_axis_cq_tuser[40]            = 1'b1;
            v_if.m_axis_cq_tuser[39:8]          = 0;
            v_if.m_axis_cq_tuser[7:4]           = 4'b1111; // last be
            v_if.m_axis_cq_tuser[3:0]           = 4'b1111; // first be

            while (1) begin
                @ (posedge v_if.pcie_clk);
                if (v_if.m_axis_cq_tready == 1'b1) begin
                    break;
                end
            end
        end
        v_if.m_axis_cq_tvalid = 1'b0;
        wait_clear();
        cmd_done.put(1'b1); // inform config sequence hardware finished
    endtask: drive_hcr_item

    //------------------------------------------------------------------------------
    // task name     : wait_clear
    // function      : wait go bit of hcr register turning from 1 to 0
    // invoked       : invoked by drive_hcr_item
    //------------------------------------------------------------------------------
    task wait_clear();
        int read_go_gap = `READ_GO_GAP;
        int read_go_counter;
        bit go;
        bit [7:0] status;
        int threshold;
        int i;
        string seq_name;
        read_go_counter = 0;
        threshold = 100;
        while (1) begin
            @ (posedge v_if.pcie_clk);
            read_go_counter++;
            if (read_go_counter > read_go_gap) begin
                read_go_counter = 0;
                check_status(go, status);
                if (status != 0) begin
                    if (!$value$plusargs("HCA_CASE_NAME=%s", seq_name)) begin
                        `uvm_fatal("hca_master_driver", "HCA_CASE_NAME not get!");
                    end
                    if (seq_name != "test_ilg_op") begin
                        `uvm_fatal("ilg_op", "status abnormal!");
                    end
                end
                if (go == 0) begin // if cmd excuted successfully
                    `uvm_info("CONFIG_INFO", "CMD go cleared!", UVM_LOW);
                    break;
                end
                else begin
                    `uvm_info("CONFIG_INFO", "CMD go uncleared!", UVM_LOW);
                    i++;
                    if (i >= threshold) begin
                        `uvm_fatal("CONFIG_ERR", "config too long!");
                    end
                end
            end
        end
    endtask: wait_clear

    //------------------------------------------------------------------------------
    // task name     : check_status
    // function      : read go and status fields of HCR register to check the execution
    //                 status of the cmd.
    // invoked       : invoked by wait_clear
    //------------------------------------------------------------------------------
    task check_status(ref bit go, ref bit [7:0] status);
        // bit go;
        bit     [63:0]                  temp_addr = `HCR_BAR_ADDR + 24;
        int                             parity;
        bit     [7:0]                   tag = 8'h12;
        int i, j, m, n;

        fork
            // send read req
            begin
                parity = 0;

                // set tvalid
                v_if.m_axis_cq_tvalid = 1'b1;

                // set tlast
                v_if.m_axis_cq_tlast = 1;

                // set tkeep
                v_if.m_axis_cq_tkeep = 8'b0000_1111;

                // set tdata
                v_if.m_axis_cq_tdata[1:0]       = 0;
                v_if.m_axis_cq_tdata[63:2]      = temp_addr[63:2];
                v_if.m_axis_cq_tdata[76:64]     = 8'b0000_0001;
                v_if.m_axis_cq_tdata[78:75]     = MEM_RD;
                v_if.m_axis_cq_tdata[79]        = 1'b0;
                v_if.m_axis_cq_tdata[87:80]     = 0;
                v_if.m_axis_cq_tdata[95:88]     = 0;
                v_if.m_axis_cq_tdata[103:96]    = tag;
                v_if.m_axis_cq_tdata[111:104]   = 0;
                v_if.m_axis_cq_tdata[114:112]   = 0;
                v_if.m_axis_cq_tdata[120:115]   = 28;
                v_if.m_axis_cq_tdata[123:121]   = 0;
                v_if.m_axis_cq_tdata[126:124]   = 0;
                v_if.m_axis_cq_tdata[127]       = 1'b0;
                v_if.m_axis_cq_tdata[255:128]   = 0;

                // set tuser
                /*  CQ tuser
                    * |  84:53 |    52:45   |   44:43  |      42     |     41      | 40  |  39:8   |   7:4   |    3:0   |
                    * | parity | tph_st_tag | tph_type | tph_present | discontinue | sop | byte_en | last_be | first_be |
                    * |        |     0      |     0    |   ignore    |   ignore    |     | ignore  |         |          |
                    */
                for (m = 0; m < 32; m++) begin
                    for (n = 0; n < 8; n++) begin
                        if (v_if.m_axis_cq_tdata[m * 8 + n] == 1'b1) begin
                            parity[m] = ~parity[m];
                        end
                    end
                end
                v_if.m_axis_cq_tuser[84:53]     = parity; 
                v_if.m_axis_cq_tuser[52:41]     = 0;
                v_if.m_axis_cq_tuser[40]        = 1'b1;
                v_if.m_axis_cq_tuser[39:8]      = 0;
                v_if.m_axis_cq_tuser[7:4]       = 4'b1111; // last be
                v_if.m_axis_cq_tuser[3:0]       = 4'b1111; // first be

                while (1) begin
                    @ (posedge v_if.pcie_clk);
                    if (v_if.m_axis_cq_tready == 1'b1) begin
                        break;
                    end
                end
                v_if.m_axis_cq_tvalid = 1'b0;
                // `uvm_info("NOTICE", {"MEM_RD req sent finished ... ", get_full_name()}, UVM_LOW);
            end

            // recieve response
            begin
                v_if.s_axis_cc_tready = 1'b1;
                // judge valid data
                // WARNING: possibly get wrong response!
                while (1) begin
                    @ (posedge v_if.pcie_clk);
                    if (v_if.s_axis_cc_tvalid == 1'b1 && v_if.s_axis_cc_tdata[71:64] == tag) begin
                        break;
                    end
                end
                v_if.s_axis_cc_tready = 1'b0;
                go = v_if.s_axis_cc_tdata[119];
                status = v_if.s_axis_cc_tdata[127:120];
            end
        join
        // return go;
    endtask: check_status

    task drive_db_item(hca_pcie_item req_item); // currently only support 64B doorbell
        bit     [`DATA_WIDTH-1: 0]      temp_wr_data;
        bit     [63:0]                  temp_addr;
        bit [31:0] parity;
        int i, j, m, n;
        `uvm_info("NOTICE", {"db req begin in ", get_full_name()}, UVM_LOW)
        temp_addr = req_item.cq_addr;
        temp_wr_data = req_item.data_payload.pop_front();

        // different from driving hcr, driving doorbell only needs one beat
        // set tlast
        v_if.m_axis_cq_tlast = 1'b1;

        // set tvalid
        v_if.m_axis_cq_tvalid <= 1'b1;

        // set tkeep
        v_if.m_axis_cq_tkeep = 8'b0011_1111;

        // set tdata
        v_if.m_axis_cq_tdata[1:0]           = req_item.cq_addr_type;
        v_if.m_axis_cq_tdata[63:2]          = temp_addr[63:2];
        v_if.m_axis_cq_tdata[76:64]         = 8'h02;
        v_if.m_axis_cq_tdata[78:75]         = req_item.cq_req_type;
        v_if.m_axis_cq_tdata[79]            = 1'b0;
        v_if.m_axis_cq_tdata[87:80]         = req_item.cq_device;
        v_if.m_axis_cq_tdata[95:88]         = req_item.cq_bus;
        v_if.m_axis_cq_tdata[103:96]        = req_item.cq_tag;
        v_if.m_axis_cq_tdata[111:104]       = req_item.cq_target_function;
        v_if.m_axis_cq_tdata[114:112]       = req_item.cq_bar_id;
        v_if.m_axis_cq_tdata[120:115]       = req_item.cq_bar_aperture;
        v_if.m_axis_cq_tdata[123:121]       = req_item.cq_tc;
        v_if.m_axis_cq_tdata[126:124]       = req_item.cq_attr;
        v_if.m_axis_cq_tdata[127]           = 1'b0;
        v_if.m_axis_cq_tdata[191:128]       = temp_wr_data[63:0];
        v_if.m_axis_cq_tdata[255:192]       = 0;

        temp_addr = temp_addr + 4;

        // set tuser
        /*  CQ tuser
        * |  84:53 |    52:45   |   44:43  |      42     |     41      | 40  |  39:8   |   7:4   |    3:0   |
        * | parity | tph_st_tag | tph_type | tph_present | discontinue | sop | byte_en | last_be | first_be |
        * |        |     0      |     0    |   ignore    |   ignore    |     | ignore  |         |          |
        */
        for (m = 0; m < 32; m++) begin
            for (n = 0; n < 8; n++) begin
                if (v_if.m_axis_cq_tdata[m * 8 + n] == 1'b1) begin
                    parity[m] = ~parity[m];
                end
            end
        end
        v_if.m_axis_cq_tuser[84:53]         = parity; 
        v_if.m_axis_cq_tuser[52:41]         = 0;
        v_if.m_axis_cq_tuser[40]            = 1'b1;
        v_if.m_axis_cq_tuser[39:8]          = 0;
        v_if.m_axis_cq_tuser[7:4]           = 4'b1111; // last be
        v_if.m_axis_cq_tuser[3:0]           = 4'b1111; // first be

        while (1) begin
            @ (posedge v_if.pcie_clk);
            if (v_if.m_axis_cq_tready == 1'b1) begin
                break;
            end
        end
        
        v_if.m_axis_cq_tvalid = 1'b0;
    endtask: drive_db_item
endclass: hca_master_driver
`endif