//****************************************************************
// include_file
//****************************************************************
+incdir+../../../Include/PCIeI_Include
../../../Include/PCIeI_Include/dma_def_h.vh

//****************************************************************
// Lib_file
//****************************************************************
//-F ../../../Lib/pciei_lib_file/filelist_pciei_lib.f

//****************************************************************
// rtl_file
//****************************************************************
-F ./DMA_Read/filelist_dmard.f
-F ./DMA_Write/filelist_dmawr.f

./DMA.v
./int_proc.v
./rc_async_fifos.v
./req_arbiter.v
./req_converter.v
./rq_async_fifos.v
./rsp_converter.v
