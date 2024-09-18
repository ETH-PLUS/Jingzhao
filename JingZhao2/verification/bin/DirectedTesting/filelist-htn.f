//****************************************************************
// Include Files
//****************************************************************
//This is used for explicitly included header files, for example, `include "protocol_engine_def.vh" in source file
+incdir+../../../../hardware/hdl/include/Top
+incdir+../../../../hardware/hdl/include/Common

//This is used for implicitly included header files, no "`include" in source file
-F ../../../../hardware/hdl/include/include.f

//****************************************************************
// Hardware Design Files
//****************************************************************
-F ../../../../hardware/hdl/rtl/hangu_htn_top.f

//*******************************************************
//              Library
//*******************************************************
-F ../../../../hardware/hdl/lib/pciei_lib/pciei_lib.f
-F ../../../../hardware/hdl/lib/xilinx_ip_lib/xilinx_ip_lib.f

//*******************************************************************
//              Simulation
//*******************************************************************
-F ./filelist-sv.f
