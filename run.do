vlib work
vdel -all 
vlib work 
vlog rtl/Submodules/packages.sv
vlog rtl/axi4_if.sv rtl/axi4_lite_subordinate.sv rtl/Submodules/subm_rx.sv rtl/Submodules/subm_tx.sv rtl/Submodules/TB_if.sv rtl/manager.sv +acc
vlog testbench/tb_top.sv
vsim work.top_tb
add wave -r *
run -all
