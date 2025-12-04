#Author: Nhat Nguyen

#run with vsim -do run_txrx.do

vlog subm_tx.sv subm_rx.sv txrx_TB.sv 
#this compiles the module and testbench

vsim -voptargs="+acc" txrx_TB
#this allows viewing of internal signals during debugging
#also <put tb name here> is the name of the testbench module

add wave *
add wave txrx_TB/TX/*
#this adds all the signal waveforms to Questasim (saves lots of time)

run -all	
#this runs the simulation for 600 ns, otherwise use -all
#from shell the run.do (or.tcl) file is run with "vsim -do run.do"
#this design was verified by observing the waveforms on Questasim and by reading the transcript output
