vlib modelsim_lib/work
vlib modelsim_lib/msim

vlib modelsim_lib/msim/xpm
vlib modelsim_lib/msim/blk_mem_gen_v8_4_10
vlib modelsim_lib/msim/xil_defaultlib

vmap xpm modelsim_lib/msim/xpm
vmap blk_mem_gen_v8_4_10 modelsim_lib/msim/blk_mem_gen_v8_4_10
vmap xil_defaultlib modelsim_lib/msim/xil_defaultlib

vlog -work xpm  -incr -mfcu  -sv \
"E:/vivado/Vivado/2024.2/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv" \

vcom -work xpm  -93  \
"E:/vivado/Vivado/2024.2/data/ip/xpm/xpm_VCOMP.vhd" \

vlog -work blk_mem_gen_v8_4_10  -incr -mfcu  \
"../../ipstatic/simulation/blk_mem_gen_v8_4.v" \

vlog -work xil_defaultlib  -incr -mfcu  \
"../../../Ordovician_a7.gen/sources_1/ip/blk_mem_gen_1/sim/blk_mem_gen_1.v" \
"../../../Ordovician_a7.gen/sources_1/ip/blk_mem_gen_0_1/sim/blk_mem_gen_0.v" \

vlog -work xil_defaultlib  -incr -mfcu  -sv \
"../../../Ordovician_a7.srcs/sources_1/new/READ_Matrix.sv" \
"../../../Ordovician_a7.srcs/sim_1/new/read_tb.sv" \

vlog -work xil_defaultlib \
"glbl.v"

