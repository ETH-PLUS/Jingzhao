module test252;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    class demote extends uvm_report_catcher;

        function void cdns_tcl_global_stop_request ();
            uvm_domain common;
            uvm_phase e;
            common = uvm_domain::get_common_domain();
            e = common.find_by_name("extract");
            uvm_domain::jump_all(e);
        endfunction

        function new();
            super.new("demote");
        endfunction

        virtual function action_e catch();
            if (get_severity() == UVM_FATAL)
                cdns_tcl_global_stop_request();
            return THROW;
        endfunction

    endclass

    class test extends uvm_test;

        `uvm_component_utils(test)

        function new(input string name, input uvm_component parent=null);
            super.new(name,parent);
        endfunction // new

        virtual function void report();
            $display("still alive");
        endfunction // report

        virtual task run_phase(uvm_phase phase);
            super.run_phase(phase);
            uvm_top.set_report_severity_action_hier(UVM_FATAL,UVM_DISPLAY|UVM_COUNT);
            `uvm_info("FOO","BLA",UVM_NONE)
            `uvm_warning("aWARNING","SUCH")
            `uvm_error("anERROR","ERROR")
            `uvm_fatal("aFATAL","a fatal")
            #20;
        endtask

    endclass

    initial begin
        demote d;
        d = new();
        uvm_report_cb::add(null, d);
        run_test("test");
    end
    
endmodule