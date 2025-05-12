transcript off
onbreak {quit -force}
onerror {quit -force}
transcript on

asim +access +r +m+SystolicArray_tb  -L xil_defaultlib -L xpm -L unisims_ver -L unimacro_ver -L secureip -O5 xil_defaultlib.SystolicArray_tb xil_defaultlib.glbl

do {SystolicArray_tb.udo}

run 1000ns

endsim

quit -force
