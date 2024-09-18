//CREATE INFORMATION
//------------------------------------------------------------------------------------------
//
//  (C) COPYRIGHT 2021 BY ICT-HPC CORPORATION ALL RIGHTS RESERVED
//  DATE     : 2021-03-17
//  AUTHOR   : mazhenlong@ncic.ac.cn
//  FILENAME : hca_vsequence.sv
//  FUNCTION : This file supplies the virtual sequence of verification of HCA.
//
//------------------------------------------------------------------------------------------

//CHANGE HISTORY
//------------------------------------------------------------------------------------------
//
//  AUTHOR          DATE          VERSION          REASON
//  mazhenlong      2021-03-17    v1.0             create
//  mazhenlong      2021-04-19    v1.1             change launching cfg_seq from `uvm_do_on 
//                                                 to cfg_seq.start
//  mazhenlong      2021-04-20    v1.2             change pre_do() to pre_body(), for difference 
//                                                 between them see https://www.chipverify.com/uvm/how-to-execute-sequences-via-start-method
//
//------------------------------------------------------------------------------------------

`ifndef __HCA_VSEQ__
`define __HCA_VSEQ__

//--------------------------------------------------------------------------------------------
//
// CLASS: hca_vsequence
//
//--------------------------------------------------------------------------------------------
class hca_vsequence extends uvm_sequence;
    hca_pcie_item recv_item;
    hca_pcie_item cfg_item_que[][$];
    hca_pcie_item comm_item_que[][$];
    hca_config_sequence cfg_seq[];
    hca_slave_sequence slv_seq[];
    hca_comm_sequence comm_seq[];
    mailbox cfg_mbx[];
    mailbox comm_mbx[];
    semaphore cfg_comm_sem[];
    semaphore comm_cfg_sem[];

    int host_num = 1;

    `uvm_object_utils_begin(hca_vsequence)
    `uvm_object_utils_end

    `uvm_declare_p_sequencer(hca_vsequencer)

    //------------------------------------------------------------------------------
    // function name : new
    // function      : constructor
    // invoked       : invoked when instantiates the class
    //------------------------------------------------------------------------------
    function new(string name = "hca_vsequence");
        
    endfunction: new

    function init(int host_num);
        string array_element;
        this.host_num = host_num;
        cfg_item_que = new[host_num];
        comm_item_que = new[host_num];

        cfg_seq = new[host_num];
        slv_seq = new[host_num];
        comm_seq = new[host_num];

        cfg_mbx = new[host_num];
        comm_mbx = new[host_num];

        cfg_comm_sem = new[host_num];
        comm_cfg_sem = new[host_num];
        
        for (int i = 0; i < host_num; i++) begin
            cfg_comm_sem[i] = new(1);
            comm_cfg_sem[i] = new(1);
        end

        for (int i = 0; i < host_num; i++) begin
            cfg_mbx[i] = new();
            comm_mbx[i] = new();
        end
        for (int i = 0; i < host_num; i++) begin
            array_element = $sformatf("cfg_seq[%0d]", i);
            cfg_seq[i] = hca_config_sequence::type_id::create(array_element, ,get_full_name);
        end
        for (int i = 0; i < host_num; i++) begin
            array_element = $sformatf("slv_seq[%0d]", i);
            slv_seq[i] = hca_slave_sequence::type_id::create(array_element, , get_full_name);
            slv_seq[i].host_id = i;
        end
        for (int i = 0; i < host_num; i++) begin
            array_element = $sformatf("comm_seq[%0d]", i);
            comm_seq[i] = hca_comm_sequence::type_id::create(array_element, , get_full_name);
        end
    endfunction: init

    //------------------------------------------------------------------------------
    // task name     : pre_body
    // function      : send cfg item to cfg seq
    // invoked       : invoked by UVM automatically
    //------------------------------------------------------------------------------
    virtual task pre_body();

    endtask: pre_body

    //------------------------------------------------------------------------------
    // task name     : body
    // function      : generate cfg_seq and slv_seq
    // invoked       : invoked by UVM automatically
    //------------------------------------------------------------------------------
    virtual task body();
        for (int i = 0; i < host_num; i++) begin
            fork
                automatic int j = i;
                begin
                    while (1) begin
                        hca_pcie_item cfg_item;
                        comm_cfg_sem[j].get(1);
                        `uvm_info("NOTICE", $sformatf("config thread begin! host_id: %0d.", j), UVM_LOW);
                        while (1) begin
                            cfg_mbx[j].get(cfg_item);
                            if (cfg_item.item_type == BATCH) begin
                                `uvm_info("NOTICE", "BATCH item received by vseq in config! Go to communication!", UVM_LOW);
                                cfg_comm_sem[j].put(1);
                                break;
                            end
                            else if (cfg_item.item_type == GLOBAL_STOP) begin
                                `uvm_info("NOTICE", "GLOBAL_STOP item received by vseq in config!", UVM_LOW);
                                cfg_seq[j].cfg_item_que.push_back(cfg_item);
                                cfg_seq[j].start(p_sequencer.mst_sqr[j], , , 1);
                                cfg_comm_sem[j].put(1);
                                break;
                            end
                            else if (cfg_item.item_type == HCR) begin
                                `uvm_info("NOTICE", "config item received by vseq in config!", UVM_LOW);
                                cfg_seq[j].cfg_item_que.push_back(cfg_item);
                                cfg_seq[j].start(p_sequencer.mst_sqr[j], , , 1);
                            end
                            else begin
                                `uvm_fatal("ITEM TYPE ERROR", "wrong item type!");
                            end
                        end
                        if (cfg_item.item_type == GLOBAL_STOP) begin
                            `uvm_info("NOTICE", "vsequence config thread ends!", UVM_LOW);
                            break;
                        end
                    end
                end
                begin
                    cfg_comm_sem[j].get(1);
                    while (1) begin
                        hca_pcie_item comm_item;
                        cfg_comm_sem[j].get(1);
                        `uvm_info("NOTICE", "comm thread begin!", UVM_LOW);
                        while (1) begin
                            comm_mbx[j].get(comm_item);
                            if (comm_item.item_type == DOORBELL) begin
                                `uvm_info("NOTICE", "doorbell item received by vseq in comm!", UVM_LOW);
                                // slv_seq[j].stop = 1;
                                comm_seq[j].comm_item_que.push_back(comm_item);
                                comm_seq[j].start(p_sequencer.mst_sqr[j], , , 1);
                            end
                            else if (comm_item.item_type == BATCH) begin
                                `uvm_info("NOTICE", "BATCH item received by vseq in comm! Go to Configuration!", UVM_LOW);
                                comm_cfg_sem[j].put(1);
                                break;
                            end
                            else if (comm_item.item_type == GLOBAL_STOP) begin
                                `uvm_info("NOTICE", "GLOBAL_STOP item received by vseq in comm!", UVM_LOW);
                                comm_cfg_sem[j].put(1);
                                break;
                            end
                            else begin
                                `uvm_fatal("ITEM TYPE ERROR", "wrong item type!");
                            end
                        end
                        if (comm_item.item_type == GLOBAL_STOP) begin
                            `uvm_info("NOTICE", "vsequence comm thread ends!", UVM_LOW);
                            break;
                        end
                    end
                end
                slv_seq[j].start(p_sequencer.slv_sqr[j], , , 1);
            join_none
        end
        wait fork;
        `uvm_info("NOTICE", "vsequence body end!", UVM_LOW);
    endtask: body
endclass: hca_vsequence
`endif