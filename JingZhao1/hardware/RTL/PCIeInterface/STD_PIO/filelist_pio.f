//****************************************************************
// include_file
//****************************************************************
+incdir+../../../Include/PCIeI_Include
../../../Include/PCIeI_Include/pio_include_h.vh

//****************************************************************
// Lib_file
//****************************************************************
//-F ../../../Lib/pciei_lib_file/filelist_pciei_lib.f

//****************************************************************
// rtl_file
//****************************************************************
./STD_PIO.v       
./pio_rsp_split.v   
./cc_composer.v  
./cc_async_fifos.v
./p2p_access.v      
./pio_mux.v         
./pio_req.v
./cq_parser.v    
./pio_demux.v     
./rdma_hcr_space.v
./rdma_hcr.v
./rdma_int.v
./rdma_uar.v
./eth_cfg.v      
./pio_dw_align.v  
./pio_rrsp.v
