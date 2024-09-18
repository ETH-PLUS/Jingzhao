`ifndef __HCA_EVENT_GENERATOR__
`define __HCA_EVENT_GENERATOR__

class hca_event_generator extends uvm_object;
    event cmd_done;

    `uvm_object_param_utils_begin(hca_event_generator)
    `uvm_object_utils_end

    function new(string name = "hca_event_generator");
        super.new(name);
    endfunction: new
endclass: hca_event_generator
`endif