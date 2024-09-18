//CREATE INFORMATION
//----------------------------------------------------------------------------------------------
//
//  (C) COPYRIGHT 2021 BY ICT-HPC CORPORATION ALL RIGHTS RESERVED
//  DATE     : 2021-04-07
//  AUTHOR   : mazhenlong@ncic.ac.cn
//  FILENAME : hca_slave_monitor.sv
//  FUNCTION : This file supplies the function of receiving DMA requests from
//             virtual interface and transform it into hca_pcie_items.
//
//----------------------------------------------------------------------------------------------

//CHANGE HISTORY
//----------------------------------------------------------------------------------------------
//
//  AUTHOR          DATE          VERSION          REASON
//  mazhenlong      2021-04-07    v1.0             create
//  mazhenlong      2021-06-30    v1.1             add judgement of icm access, if the received
//                                                 item accesses icm space, do not send it to scb
//
//----------------------------------------------------------------------------------------------

`ifndef __HCA_SLAVE_MONITOR__
`define __HCA_SLAVE_MONITOR__

//------------------------------------------------------------------------------
//
// CLASS: hca_slave_monitor
//
//------------------------------------------------------------------------------
class hca_slave_monitor extends uvm_monitor;
    hca_pcie_item received_item;
    hca_pcie_item item_to_scb;
    hca_pcie_item item_to_sqr;
    hca_pcie_item probe_item_to_scb;
    virtual hca_interface vif;
    uvm_analysis_port #(hca_pcie_item) seq_port; // to sequencer
    uvm_analysis_port #(hca_pcie_item) port2scb; // duv data
    // uvm_analysis_port #(hca_pcie_item) port2scb_probe;
    // uvm_analysis_port #(hca_pcie_item) port2rm;
    mailbox mon2seq_mbx;

    hca_memory mem;

    `uvm_component_utils_begin(hca_slave_monitor)
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
    // function      : build_phase in uvm lib
    // invoked       : by uvm automatically
    //------------------------------------------------------------------------------
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db #(virtual hca_interface)::get(this, "", "virtual_if", vif)) begin
            `uvm_fatal("NOVIF",{"virtual interface must be set for: ",get_full_name(),".vif"});
        end
        item_to_sqr = hca_pcie_item::type_id::create("item_to_sqr", this);
        item_to_scb = hca_pcie_item::type_id::create("item_to_scb", this);
        // probe_item_to_scb = hca_pcie_item::type_id::create("probe_item_to_scb", this);
        seq_port = new("seq_port", this);
        port2scb = new("port2scb", this);
        mon2seq_mbx = new();
        uvm_config_db#(mailbox)::set(uvm_root::get(), "*", "mon2seq_mbx", mon2seq_mbx);
            `uvm_info("NOTICE", "global stop mailbox send finished!", UVM_LOW);
        // port2scb_probe = new("port2scb_probe", this);
    endfunction: build_phase

    //------------------------------------------------------------------------------
    // task name     : run_phase
    // function      : run_phase in uvm lib
    // invoked       : by uvm automatically
    //------------------------------------------------------------------------------
    task run_phase(uvm_phase phase);
        int beat_num;
        int received_dw_num;
        int heartbeat = 0;
        bit [`DATA_WIDTH-1: 0] temp_data;
        phase.raise_objection(this);
        super.run_phase(phase);
        @ (posedge vif.veri_en);
        vif.s_axis_rq_tready = 1;
        fork
            // generate duv item
            forever begin
                bit [3:0] first_be;
                bit [3:0] last_be;
                hca_pcie_item item_to_sqr_mbx;
                item_to_sqr = hca_pcie_item::type_id::create("item_to_sqr", this);
                item_to_scb = hca_pcie_item::type_id::create("item_to_scb", this);
                item_to_sqr_mbx = hca_pcie_item::type_id::create("item_to_sqr_mbx", this);
                while (1) begin
                    // `uvm_info("NOTICE", "detecting rq_tvalid and global stop in slave monitor!", UVM_LOW);
                    @ (posedge vif.pcie_clk);
                    if (vif.s_axis_rq_tvalid == 1 || vif.global_stop == 1) begin
                        break;
                    end
                end
                
                received_item = hca_pcie_item::type_id::create("received_item", this);

                if (vif.global_stop == 1) begin
                    `uvm_info("GLB_STOP_INFO", "global stop signal received in slave monitor!", UVM_LOW);
                    received_item.item_type = GLOBAL_STOP;
                    seq_port.write(received_item);
                    `uvm_info("GLB_STOP_INFO", "global stop item sent to slave sequencer!", UVM_LOW);
                    // port2scb
                    break;
                end

                //----------------process received dma req-----------------//
                `uvm_info("NOTICE", "DMA req processing begin!", UVM_LOW);
                if (vif.s_axis_rq_tdata[78:75] == `PCIE_MEM_RD) begin
                    `uvm_info("NOTICE", $sformatf("received dma read request! addr: %h", {vif.s_axis_rq_tdata[63:2], 2'b0}), UVM_LOW);
                    received_item.item_type                 = DMA_RD;
                    received_item.rq_req_type               = MEM_RD;
                    received_item.rq_addr                   = {vif.s_axis_rq_tdata[63:2], 2'b0};
                    received_item.rq_dword_count            = vif.s_axis_rq_tdata[74:64];
                    received_item.rq_req_type               = vif.s_axis_rq_tdata[78:75];
                    received_item.rq_poisoned_req           = vif.s_axis_rq_tdata[79];
                    received_item.rq_requester_device       = vif.s_axis_rq_tdata[87:80];
                    received_item.rq_requester_bus          = vif.s_axis_rq_tdata[95:88];
                    received_item.rq_tag                    = vif.s_axis_rq_tdata[103:96];
                    received_item.rq_completer_device       = vif.s_axis_rq_tdata[111:104];
                    received_item.rq_completer_bus          = vif.s_axis_rq_tdata[119:112];
                    received_item.rq_requester_id_en        = vif.s_axis_rq_tdata[120];
                    received_item.rq_tc                     = vif.s_axis_rq_tdata[123:121];
                    received_item.rq_attr                   = vif.s_axis_rq_tdata[126:124];
                    received_item.rq_force_ecrc             = vif.s_axis_rq_tdata[127];
                    received_item.rq_first_be               = vif.s_axis_rq_tuser[3:0];
                    received_item.rq_last_be                = vif.s_axis_rq_tuser[7:4];
                    if (vif.s_axis_rq_tlast != 1) begin
                        `uvm_fatal("RQ_ERR", "RD rq_tlast error!");
                    end
                end
                else if (vif.s_axis_rq_tdata[78:75] == `PCIE_MEM_WR) begin
                    `uvm_info("NOTICE", $sformatf("received dma write request! addr: %h, dw count: %h, first be: %h, last be: %h", 
                        {vif.s_axis_rq_tdata[63:2], 2'b0}, vif.s_axis_rq_tdata[74:64], vif.s_axis_rq_tuser[3:0], 
                        vif.s_axis_rq_tuser[7:4]), UVM_LOW
                    );
                    beat_num                                = 0;
                    received_dw_num                         = 0;
                    received_item.item_type                 = DMA_WR;
                    received_item.rq_req_type               = MEM_WR;
                    received_item.rq_addr                   = {vif.s_axis_rq_tdata[63:2], 2'b0};
                    received_item.rq_dword_count            = vif.s_axis_rq_tdata[74:64];
                    received_item.rq_req_type               = vif.s_axis_rq_tdata[78:75];
                    received_item.rq_poisoned_req           = vif.s_axis_rq_tdata[79];
                    received_item.rq_requester_device       = vif.s_axis_rq_tdata[87:80];
                    received_item.rq_requester_bus          = vif.s_axis_rq_tdata[95:88];
                    received_item.rq_tag                    = vif.s_axis_rq_tdata[103:96];
                    received_item.rq_completer_device       = vif.s_axis_rq_tdata[111:104];
                    received_item.rq_completer_bus          = vif.s_axis_rq_tdata[119:112];
                    received_item.rq_requester_id_en        = vif.s_axis_rq_tdata[120];
                    received_item.rq_tc                     = vif.s_axis_rq_tdata[123:121];
                    received_item.rq_attr                   = vif.s_axis_rq_tdata[126:124];
                    received_item.rq_force_ecrc             = vif.s_axis_rq_tdata[127];

                    received_item.rq_first_be               = vif.s_axis_rq_tuser[3:0];
                    received_item.rq_last_be                = vif.s_axis_rq_tuser[7:4];
                    `uvm_info("NOTICE", $sformatf("Write dw count: %h", received_item.rq_dword_count), UVM_LOW);

                    while (1) begin
                        if (vif.s_axis_rq_tlast != 1) begin // not the last beat
                            if (beat_num == 0) begin // is the first beat
                                temp_data[127:0] = vif.s_axis_rq_tdata[255:128];
                            end
                            else begin // is not the first beat
                                temp_data[255:128] = vif.s_axis_rq_tdata[127:0];
                                received_item.data_payload.push_back(temp_data);
                                `uvm_info("NOTICE", $sformatf("item data payload push: %h", temp_data), UVM_LOW);
                                temp_data[127:0] = vif.s_axis_rq_tdata[255:128];
                            end
                        end
                        else begin // the last beat
                            if (beat_num == 0) begin
                                temp_data[127:0] = vif.s_axis_rq_tdata[255:128];
                                temp_data[255:128] = 0;
                                received_item.data_payload.push_back(temp_data);
                                `uvm_info("NOTICE", $sformatf("item data payload push: %h", temp_data), UVM_LOW);
                            end
                            else begin
                                if (received_dw_num + 4 < received_item.rq_dword_count) begin
                                    temp_data[255:128] = vif.s_axis_rq_tdata[127:0];
                                    received_item.data_payload.push_back(temp_data);
                                    `uvm_info("NOTICE", $sformatf("item data payload push: %h", temp_data), UVM_LOW);
                                    temp_data[127:0] = vif.s_axis_rq_tdata[255:128];
                                    temp_data[255:128] = 0;
                                    received_item.data_payload.push_back(temp_data);
                                    `uvm_info("NOTICE", $sformatf("item data payload push: %h", temp_data), UVM_LOW);
                                end
                                else begin
                                    temp_data[255:128] = vif.s_axis_rq_tdata[127:0];
                                    received_item.data_payload.push_back(temp_data);
                                    `uvm_info("NOTICE", $sformatf("item data payload push: %h", temp_data), UVM_LOW);
                                end
                            end
                        end
                        if (beat_num == 0) begin
                            received_dw_num += 4;
                        end
                        else begin
                            received_dw_num += 8;
                        end
                        beat_num++;

                        if (received_dw_num < received_item.rq_dword_count) begin
                            if (vif.s_axis_rq_tlast == 1 && 
                                vif.s_axis_rq_tvalid == 1 && 
                                vif.s_axis_rq_tready == 1) begin
                                if (vif.s_axis_rq_tlast == 1) begin
                                    `uvm_fatal("RQ_ERR", $sformatf("WR rq_tlast error, should NOT be 1! received_dw_num: %h, received_item.rq_dword_count: %h", 
                                        received_dw_num, received_item.rq_dword_count));
                                end
                            end
                            while (1) begin
                                @ (posedge vif.pcie_clk);
                                if (vif.s_axis_rq_tvalid == 1) begin
                                    // if (vif.s_axis_rq_tlast == 1) begin
                                    //     `uvm_fatal("RQ_ERR", "WR rq_tlast error, should NOT be 1!");
                                    // end
                                    // else begin
                                    //     break;
                                    // end
                                    break;
                                end
                            end
                        end
                        else begin
                            if (vif.s_axis_rq_tlast == 1) begin
                                break;
                            end
                            else begin
                                `uvm_fatal("RQ_ERR", $sformatf("WR rq_tlast error! received_dw_num: %h, received_item.rq_dword_count: %h", 
                                    received_dw_num, received_item.rq_dword_count));
                            end
                        end
                    end
                end
                else begin
                    `uvm_fatal("RQ_ERR", $sformatf("RQ type error, rq_tdata: %h", vif.s_axis_rq_tdata));
                end

                // send received item to slave sequence
                item_to_sqr.copy(received_item);
                seq_port.write(item_to_sqr);
                item_to_sqr_mbx.copy(received_item);
                mon2seq_mbx.put(item_to_sqr_mbx);

                // if received item does not fall into icm space, send item to scoreboard
                if (send2scb(received_item.rq_addr) == 1) begin
                    fork
                        begin
                            hca_pcie_item item_to_scb_cqe;
                            item_to_scb_cqe = hca_pcie_item::type_id::create("item_to_scb_cqe", this);
                            item_to_scb_cqe.copy(received_item);
                            // for (int i = 0; i < `CQE2SCB_GAP; i++) begin
                            //     @(posedge vif.pcie_clk);
                            // end
                            port2scb.write(item_to_scb_cqe);
                            // item_to_scb = hca_pcie_item::type_id::create("item_to_scb", this);
                            // item_to_scb.copy(received_item);
                            // // vif.s_axis_rq_tready = 0;
                            // for (int i = 0; i < `CQE2SCB_GAP; i++) begin
                            //     @(posedge vif.pcie_clk);
                            // end
                            // // vif.s_axis_rq_tready = 1;
                            // port2scb.write(item_to_scb);
                        end
                    join_none
                end
            end

            // detect block
            begin
                heartbeat = 0;
                while (1) begin
                    @ (posedge vif.pcie_clk);
                    if (vif.global_stop == 1) begin
                        break;
                    end
                    if (vif.s_axis_rq_tvalid == 1) begin
                        heartbeat = 0;
                    end
                    else begin
                        heartbeat++;
                        if (heartbeat > `BREAKTIME) begin
                            // `uvm_fatal("AREYOUDEAD?", "Too long no rq_tvalid!");
                            hca_pcie_item item_to_scb;
                            item_to_scb = hca_pcie_item::type_id::create("item_to_scb", this);
                            item_to_scb.item_type = INTR;
                            heartbeat = 0;
                            port2scb.write(item_to_scb);
                        end
                    end
                end
            end

            // begin
            //     while (1) begin
            //         @ (posedge vif.pcie_clk);
            //         if (vif.global_stop == 1) begin
            //             break;
            //         end
            //         if (vif.s_axis_rq_tvalid == 1) begin
            //             heartbeat = 0;
            //         end
            //         else begin
            //             heartbeat++;
            //             if (heartbeat > `BREAKTIME) begin
            //                 `uvm_fatal("AREYOUDEAD?", "Too long no rq_tvalid!");
            //             end
            //         end
            //     end
            // end
        join
        `uvm_info("NOTICE", "\033[47;40mslave monitor run_phase stop!\033[0m", UVM_LOW);
        phase.drop_objection(this);
    endtask: run_phase

    function bit send2scb(addr rq_addr);
        if (rq_addr[47:33] == 15'b1) begin // if is CQ address
            `uvm_info("SLV_MON_NOTICE", $sformatf("slave monitor sends cqe to SCB, address: %h", rq_addr), UVM_LOW);
            return 1;
        end
        else begin
        `uvm_info("SLV_MON_NOTICE", $sformatf("Not CQE, slave monitor does not send item to SCB, address: %h", rq_addr), UVM_LOW);
            return 0;
        end
    endfunction: send2scb
endclass: hca_slave_monitor
`endif