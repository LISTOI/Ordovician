transcript off
onbreak {quit -force}
onerror {quit -force}
transcript on

vlib work
vlib activehdl/xpm
vlib activehdl/xil_defaultlib

vmap xpm activehdl/xpm
vmap xil_defaultlib activehdl/xil_defaultlib

vlog -work xpm  -sv2k12 -l xpm -l xil_defaultlib \
"E:/vivado/Vivado/2024.2/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv" \

vcom -work xpm -93  \
"E:/vivado/Vivado/2024.2/data/ip/xpm/xpm_VCOMP.vhd" \

vlog -work xil_defaultlib  -sv2k12 -l xpm -l xil_defaultlib \
"../../../Ordovician.srcs/sources_1/new/PE.sv" \
"../../../Ordovician.srcs/sources_1/new/SystolicArray.sv" \
"../../../Ordovician.srcs/sim_1/new/systolic_array_tb.sv" \

vlog -work xil_defaultlib \
"glbl.v"

