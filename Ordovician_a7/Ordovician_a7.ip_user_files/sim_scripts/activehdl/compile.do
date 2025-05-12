transcript off
onbreak {quit -force}
onerror {quit -force}
transcript on

vlib work
vlib activehdl/xpm
vlib activehdl/blk_mem_gen_v8_4_10
vlib activehdl/xil_defaultlib

vmap xpm activehdl/xpm
vmap blk_mem_gen_v8_4_10 activehdl/blk_mem_gen_v8_4_10
vmap xil_defaultlib activehdl/xil_defaultlib

vlog -work xpm  -sv2k12 -l xpm -l blk_mem_gen_v8_4_10 -l xil_defaultlib \
"E:/vivado/Vivado/2024.2/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv" \

vcom -work xpm -93  \
"E:/vivado/Vivado/2024.2/data/ip/xpm/xpm_VCOMP.vhd" \

vlog -work blk_mem_gen_v8_4_10  -v2k5 -l xpm -l blk_mem_gen_v8_4_10 -l xil_defaultlib \
"../../ipstatic/simulation/blk_mem_gen_v8_4.v" \

vlog -work xil_defaultlib  -v2k5 -l xpm -l blk_mem_gen_v8_4_10 -l xil_defaultlib \
"../../../Ordovician_a7.gen/sources_1/ip/blk_mem_gen_1/sim/blk_mem_gen_1.v" \
"../../../Ordovician_a7.gen/sources_1/ip/blk_mem_gen_0_1/sim/blk_mem_gen_0.v" \

vlog -work xil_defaultlib  -sv2k12 -l xpm -l blk_mem_gen_v8_4_10 -l xil_defaultlib \
"../../../Ordovician_a7.srcs/sources_1/new/CALC_Matrix.sv" \
"../../../Ordovician_a7.srcs/sources_1/new/Ordovician_top.sv" \
"../../../Ordovician_a7.srcs/sources_1/new/PE.sv" \
"../../../Ordovician_a7.srcs/sources_1/new/READ_Matrix.sv" \
"../../../Ordovician_a7.srcs/sources_1/new/SystolicArray.sv" \
"../../../Ordovician_a7.srcs/sources_1/new/WRITE_Matrix.sv" \
"../../../Ordovician_a7.srcs/sim_1/new/top_tb.sv" \

vlog -work xil_defaultlib \
"glbl.v"

