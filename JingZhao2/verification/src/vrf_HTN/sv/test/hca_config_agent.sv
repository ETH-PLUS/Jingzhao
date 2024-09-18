//CREATE INFORMATION
//-----------------------------------------------------------------------------------------------
//
//  (C) COPYRIGHT 2021 BY ICT-HPC CORPORATION ALL RIGHTS RESERVED
//  DATE     : 2021-10-21
//  AUTHOR   : mazhenlong@ncic.ac.cn
//  FILENAME : hca_config_agent.sv
//  FUNCTION : This class implements configuration of HCA
//
//-----------------------------------------------------------------------------------------------

//CHANGE HISTORY
//-----------------------------------------------------------------------------------------------
//
//  AUTHOR          DATE          VERSION          REASON
//  mazhenlong      2020-10-21    v1.0             create
//
//-----------------------------------------------------------------------------------------------

`ifndef __HCA_CONFIG_AGENT__
`define __HCA_CONFIG_AGENT__

//----------------------------------------------------------------------------
//
// CLASS: hca_config_agent
//
//----------------------------------------------------------------------------
class hca_config_agent extends uvm_object;

    hca_vsequence vseq;
    hca_icm_vaddr icm_vaddr;
    hca_mem_info mem_info;
    hca_pcie_item pcie_item;

    `uvm_object_utils_begin(hca_config_agent)
    `uvm_object_utils_end
    
    //------------------------------------------------------------------------------
    // function name : new
    // function      : constructor
    // invoked       : invoked when instantiates the class
    //------------------------------------------------------------------------------
    function new(string name = "hca_config_agent");
        super.new(name);
    endfunction

    function init(hca_vsequence input_vseq, hca_icm_vaddr input_icm_vaddr, hca_mem_info input_mem_info);
        this.vseq = input_vseq;
        this.icm_vaddr = input_icm_vaddr;
        this.mem_info = input_mem_info;
    endfunction: init

    task init_hca(int host_id);
        hca_pcie_item init_hca_item;
        init_hca_item = hca_pcie_item::type_id::create($sformatf("init_hca_item[%0d]", host_id));
        assert (init_hca_item.randomize() with {hcr_op == `CMD_INIT_HCA;})
        else begin
            `uvm_fatal("RANDOMIZE_ERROR", "randomize error in init hca!");
        end
        init_hca_item.icm_base_struct.qpc_base          = `QPC_OFFSET;
        init_hca_item.icm_base_struct.cqc_base          = `CQC_OFFSET;
        init_hca_item.icm_base_struct.eqc_base          = `EQC_OFFSET;
        init_hca_item.icm_base_struct.mpt_base          = `MPT_OFFSET;
        init_hca_item.icm_base_struct.mtt_base          = `MTT_OFFSET;
        init_hca_item.icm_base_struct.log_num_qps       = `LOG_NUM_QPS;
        init_hca_item.icm_base_struct.log_num_cqs       = `LOG_NUM_CQS;
        init_hca_item.icm_base_struct.log_num_eqs       = `LOG_NUM_EQS;
        init_hca_item.icm_base_struct.log_mpt_sz        = `LOG_MPT_SZ;
        if (vseq.cfg_mbx[host_id].try_put(init_hca_item) == 0) begin
            `uvm_fatal("TRY_PUT_ERR", $sformatf("init hca error! host_id: %h.", host_id));
        end
    endtask: init_hca

    function bit [63:0] map_icm(int host_id, int m_type, int page_num); // m_type: 1: qp context; 2: cq context; 3: mpt; 4: mtt;
                                             // return the virtual address of the mapped page in ICM space;
        hca_pcie_item map_icm_item;
        bit [63:0] temp_virt_addr;
        bit [63:0] temp_phys_addr;
        // addr start_virt_addr;
        int i;
        bit flag = 0;
        if (page_num > 12'b11111111) begin
            `uvm_fatal("PAGE_NUM_ERROR", "illegal page_num in map_icm!");
        end
        if (m_type == `ICM_QPC_TYP) begin
            icm_vaddr.qpc_page_mapped[host_id] += page_num;
            icm_vaddr.qpc_cap_left[host_id] += `PAGE_SIZE * page_num;
            if (icm_vaddr.qpc_page_mapped[host_id] > icm_vaddr.qpc_page_limit[host_id]) begin
                `uvm_fatal("ICM_ERR", $sformatf("QPC ICM page num exceeds limitation! Page used: %0d", icm_vaddr.qpc_page_mapped[host_id]));
            end

            temp_virt_addr = `QPC_OFFSET;
            foreach (icm_vaddr.qpc_virt_addr[host_id][i]) begin
                if (icm_vaddr.qpc_virt_addr[host_id][i] == temp_virt_addr) begin
                    temp_virt_addr += `PAGE_SIZE;
                end
                else begin
                    if (icm_vaddr.qpc_virt_addr[host_id][i] >= temp_virt_addr + page_num * `PAGE_SIZE) begin
                        // start_virt_addr = temp_virt_addr;
                        for (int j = 0; j < page_num; j++) begin
                            icm_vaddr.qpc_virt_addr[host_id].insert(i, temp_virt_addr + j * `PAGE_SIZE);
                            flag = 1;
                        end
                        break;
                    end
                end
            end
            if (flag == 0) begin
                for (int j; j < page_num; j++) begin
                    icm_vaddr.qpc_virt_addr[host_id].push_back(temp_virt_addr + j * `PAGE_SIZE);
                end
            end
        end
        else if (m_type == `ICM_CQC_TYP) begin
            icm_vaddr.cqc_page_mapped[host_id] += page_num;
            icm_vaddr.cqc_cap_left[host_id] += `PAGE_SIZE * page_num;
            if (icm_vaddr.cqc_page_mapped[host_id] > icm_vaddr.cqc_page_limit[host_id]) begin
                `uvm_fatal("ICM_ERR", $sformatf("CQC ICM page num exceeds limitation! Page used: %0d", icm_vaddr.cqc_page_mapped[host_id]));
            end

            temp_virt_addr = `CQC_OFFSET;
            foreach (icm_vaddr.cqc_virt_addr[host_id][i]) begin
                if (icm_vaddr.cqc_virt_addr[host_id][i] == temp_virt_addr) begin
                    temp_virt_addr += `PAGE_SIZE;
                end
                else begin
                    if (icm_vaddr.cqc_virt_addr[host_id][i] >= temp_virt_addr + page_num * `PAGE_SIZE) begin
                        for (int j = 0; j < page_num; j++) begin
                            icm_vaddr.cqc_virt_addr[host_id].insert(i, temp_virt_addr + j * `PAGE_SIZE);
                            flag = 1;
                        end
                        break;
                    end
                end
            end
            if (flag == 0) begin
                for (int j; j < page_num; j++) begin
                    icm_vaddr.cqc_virt_addr[host_id].push_back(temp_virt_addr + j * `PAGE_SIZE);
                end
            end
        end
        else if (m_type == `ICM_MPT_TYP) begin
            icm_vaddr.mpt_page_mapped[host_id] += page_num;
            icm_vaddr.mpt_cap_left[host_id] += `PAGE_SIZE * page_num;
            if (icm_vaddr.mpt_page_mapped[host_id] > icm_vaddr.mpt_page_limit[host_id]) begin
                `uvm_fatal("ICM_ERR", $sformatf("MPT ICM page num exceeds limitation! Page used: %0d", icm_vaddr.mpt_page_mapped[host_id]));
            end

            temp_virt_addr = `MPT_OFFSET;
            foreach (icm_vaddr.mpt_virt_addr[host_id][i]) begin
                if (icm_vaddr.mpt_virt_addr[host_id][i] == temp_virt_addr) begin
                    temp_virt_addr += `PAGE_SIZE;
                end
                else begin
                    if (icm_vaddr.mpt_virt_addr[host_id][i] >= temp_virt_addr + page_num * `PAGE_SIZE) begin
                        for (int j = 0; j < page_num; j++) begin
                            icm_vaddr.mpt_virt_addr[host_id].insert(i, temp_virt_addr + j * `PAGE_SIZE);
                            flag = 1;
                        end
                        break;
                    end
                end
            end
            if (flag == 0) begin
                for (int j; j < page_num; j++) begin
                    icm_vaddr.mpt_virt_addr[host_id].push_back(temp_virt_addr + j * `PAGE_SIZE);
                end
            end
        end
        else if (m_type == `ICM_MTT_TYP) begin
            icm_vaddr.mtt_page_mapped[host_id] += page_num;
            icm_vaddr.mtt_cap_left[host_id] += `PAGE_SIZE * page_num;
            if (icm_vaddr.mtt_page_mapped[host_id] > icm_vaddr.mtt_page_limit[host_id]) begin
                `uvm_fatal("ICM_ERR", $sformatf("MTT ICM page num exceeds limitation! Page used: %0d", icm_vaddr.mtt_page_mapped[host_id]));
            end

            temp_virt_addr = `MTT_OFFSET;
            foreach (icm_vaddr.mtt_virt_addr[host_id][i]) begin
                if (icm_vaddr.mtt_virt_addr[host_id][i] == temp_virt_addr) begin
                    temp_virt_addr += `PAGE_SIZE;
                end
                else begin
                    if (icm_vaddr.mtt_virt_addr[host_id][i] >= temp_virt_addr + page_num * `PAGE_SIZE) begin
                        for (int j = 0; j < page_num; j++) begin
                            icm_vaddr.mtt_virt_addr[host_id].insert(i, temp_virt_addr + j * `PAGE_SIZE);
                            flag = 1;
                        end
                        break;
                    end
                end
            end
            if (flag == 0) begin
                for (int j; j < page_num; j++) begin
                    icm_vaddr.mtt_virt_addr[host_id].push_back(temp_virt_addr + j * `PAGE_SIZE);
                end
            end
            if (icm_vaddr.mtt_virt_addr[host_id].size() > 512) begin
                `uvm_fatal("ICM_PAGE_EXCEED", "ICM overwrite!");
            end
        end
        else if (m_type == `ICM_EQC_TYP) begin
            temp_virt_addr = `EQC_OFFSET;
            foreach (icm_vaddr.eqc_virt_addr[host_id][i]) begin
                if (icm_vaddr.eqc_virt_addr[host_id][i] == temp_virt_addr) begin
                    temp_virt_addr += `PAGE_SIZE;
                end
                else begin
                    if (icm_vaddr.eqc_virt_addr[host_id][i] >= temp_virt_addr + page_num * `PAGE_SIZE) begin
                        for (int j = 0; j < page_num; j++) begin
                            icm_vaddr.eqc_virt_addr[host_id].insert(i, temp_virt_addr + j * `PAGE_SIZE);
                            flag = 1;
                        end
                        break;
                    end
                end
            end
            if (flag == 0) begin
                for (int j; j < page_num; j++) begin
                    icm_vaddr.eqc_virt_addr[host_id].push_back(temp_virt_addr + j * `PAGE_SIZE);
                end
            end
        end
        else begin
            `uvm_fatal("ILG_INPUT", "illegal m_type in map_icm!");
        end

        map_icm_item = hca_pcie_item::type_id::create("map_icm_item");
        assert(map_icm_item.randomize() with {hcr_op == `CMD_MAP_ICM; map_type == m_type;})
        else begin
            `uvm_fatal("RANDOMIZE_ERROR", "randomize error in map icm!");
        end
        for (int i = 0; i < page_num; i++) begin
            map_icm_item.icm_addr_map.virt.push_back(temp_virt_addr + i * `PAGE_SIZE);
            map_icm_item.icm_addr_map.page.push_back(temp_virt_addr + `ICM_BASE + i * `PAGE_SIZE);
        end
        map_icm_item.icm_addr_map.page_num = page_num;
        vseq.cfg_mbx[host_id].try_put(map_icm_item);
        return temp_virt_addr;
    endfunction: map_icm

    //------------------------------------------------------------------------------
    // task name     : modify_qp
    // function      : generate and send modify qp item.
    // invoked       : by gen_item
    //------------------------------------------------------------------------------
    task modify_qp(int host_id, qp_context qp_ctx);
        hca_pcie_item modify_qp_item;
        modify_qp_item = hca_pcie_item::type_id::create("modify_qp_item");
        modify_qp_item.qp_ctx = qp_ctx;
        assert(modify_qp_item.randomize() with {hcr_op == `CMD_RTR2RTS_QPEE;})// qp_num == 2;};
        else begin
            `uvm_fatal("RANDOMIZE_ERROR", "randomize error in modify qp!");
        end
        vseq.cfg_mbx[host_id].try_put(modify_qp_item);
    endtask: modify_qp

    //------------------------------------------------------------------------------
    // task name     : query_qp
    // function      : generate and send query qp item.
    // invoked       : by gen_item
    //------------------------------------------------------------------------------
    task query_qp(int host_id, int qpn);
        hca_pcie_item query_qp_item;
        query_qp_item = hca_pcie_item::type_id::create("query_qp_item");
        assert(query_qp_item.randomize() with {hcr_op == `CMD_QUERY_QP; hcr_in_modifier == qpn;})
        else begin
            `uvm_fatal("RANDOMIZE_ERROR", "randomize error in query qp!");
        end
        vseq.cfg_mbx[host_id].try_put(query_qp_item);
    endtask: query_qp

    task sw2hw_cq(int host_id, cq_context cq_ctx);
        hca_pcie_item sw2hw_cq_item;
        bit [31:0] cqn;
        icm_vaddr.cqc_cap_left[host_id] -= `CQC_ENTRY_SZ;
        if (icm_vaddr.cqc_cap_left[host_id] < 0) begin
            `uvm_fatal("ICM_ERR", $sformatf("ICM CAPACITY OUT!"));
        end

        sw2hw_cq_item = hca_pcie_item::type_id::create("sw2hw_cq_item");
        sw2hw_cq_item.cq_ctx = cq_ctx;
        cqn = cq_ctx.cqn;
        assert(sw2hw_cq_item.randomize() with {hcr_op == `CMD_SW2HW_CQ; hcr_in_modifier == cq_ctx.cqn;})
        else begin
            `uvm_fatal("RANDOMIZE_ERROR", "randomize error in sw2hw cq!");
        end
        if (vseq.cfg_mbx[host_id].try_put(sw2hw_cq_item) == 0) begin
            `uvm_fatal("TRY_PUT_ERROR", "try_put failed in sw2hw_cq in config_agent!");
        end;
    endtask: sw2hw_cq

    // phys addr must be 4K aligned!!!!
    function addr write_mtt(int host_id, addr phys_addr, int page_num, int temp = 0);
        hca_pcie_item write_mtt_item;
        addr phys_addr_pcie;
        mtt temp_mtt;
        addr temp_index;
        
        icm_vaddr.mtt_cap_left[host_id] = icm_vaddr.mtt_cap_left[host_id] - page_num * 8;
        if (icm_vaddr.mtt_cap_left[host_id] < 0) begin
            `uvm_fatal("ICM_ERR", $sformatf("MTT capacity out!"));
        end

        write_mtt_item = hca_pcie_item::type_id::create("write_mtt_item");
        assert(write_mtt_item.randomize() with {hcr_op == `CMD_WRITE_MTT; num_mtt == page_num;})
        else begin
            `uvm_fatal("RANDOMIZE_ERROR", "randomize error in write mtt!");
        end
        if (page_num > 255) begin
            `uvm_fatal("WRITE_MTT_ERR", "maximum page num exceeded!");
        end
        // calculate start index
        temp_index = mem_info.mem_table[host_id].size();

        // send write mtt pcie item to sequence
        write_mtt_item.mtt_item.start_index = temp_index;
        phys_addr_pcie = phys_addr;
        // `uvm_info("MTT_NOTICE", $sformatf("write_mtt start index: %h", temp_index), UVM_LOW);
        for (int i = 0; i < page_num; i++) begin
            write_mtt_item.mtt_item.phys_addr.push_back(phys_addr_pcie);
            // `uvm_info("MTT_NOTICE", $sformatf("write_mtt phys addr: %h", phys_addr_pcie), UVM_LOW);
            phys_addr_pcie += `PAGE_SIZE;
        end
        vseq.cfg_mbx[host_id].try_put(write_mtt_item);

        // push mtt items to queue
        temp_mtt.index = temp_index;
        temp_mtt.phys_addr = phys_addr;
        for (int i = 0; i < page_num; i++) begin
            mem_info.mem_table[host_id].push_back(temp_mtt);
            temp_mtt.index++;
            temp_mtt.phys_addr += `PAGE_SIZE;
        end
        return temp_index;
    endfunction: write_mtt

    task close_hca(int host_id);
        hca_pcie_item close_hca_item;
        `uvm_info("NOTICE", "close hca begin in test", UVM_LOW);
        close_hca_item = hca_pcie_item::type_id::create("close_hca_item");
        assert(close_hca_item.randomize() with {hcr_op == `CMD_CLOSE_HCA;})
        else begin
            `uvm_fatal("RANDOMIZE_ERROR", "randomize error in close hca!");
        end
        vseq.cfg_mbx[host_id].try_put(close_hca_item);
    endtask: close_hca

    //------------------------------------------------------------------------------
    // func name     : query_adapter
    // function      : query device id
    // invoked       : by gen_item
    //------------------------------------------------------------------------------
    task query_adapter(int host_id);
        hca_pcie_item query_adapter_item;
        query_adapter_item = hca_pcie_item::type_id::create("query_adapter_item");
        assert(query_adapter_item.randomize() with {hcr_op == `CMD_QUERY_ADAPTER;})
        else begin
            `uvm_fatal("RANDOMIZE_ERROR", "randomize error in query adapter!");
        end
        vseq.cfg_mbx[host_id].try_put(query_adapter_item);
    endtask: query_adapter

    //------------------------------------------------------------------------------
    // func name     : query_dev_lim
    // function      : query device limit information
    // invoked       : by gen_item
    //------------------------------------------------------------------------------
    task query_dev_lim(int host_id);
        hca_pcie_item quety_dev_lim_item;
        quety_dev_lim_item = hca_pcie_item::type_id::create("quety_dev_lim_item");
        assert(quety_dev_lim_item.randomize() with {hcr_op == `CMD_QUERY_DEV_LIM;})
        else begin
            `uvm_fatal("RANDOMIZE_ERROR", "randomize error in query dev lim!");
        end
        vseq.cfg_mbx[host_id].try_put(quety_dev_lim_item);
    endtask: query_dev_lim

    task sw2hw_mpt(int host_id, mpt mpt_item);
        icm_vaddr.mpt_cap_left[host_id] -= `MPT_ENTRY_SZ;
        if (icm_vaddr.mpt_cap_left[host_id] < 0) begin
            `uvm_fatal("ICM_ERR", $sformatf("MPT capacity out!"));
        end
        
        pcie_item = hca_pcie_item::type_id::create("pcie_item");
        pcie_item.mpt_item = mpt_item;
        assert(pcie_item.randomize() with {hcr_op == `CMD_SW2HW_MPT;})
        else begin
            `uvm_fatal("RANDOMIZE_ERROR", "randomize error in sw2hw mpt!");
        end
        vseq.cfg_mbx[host_id].try_put(pcie_item);
        mem_info.mem_region[host_id].push_back(mpt_item);
    endtask: sw2hw_mpt

endclass: hca_config_agent
`endif