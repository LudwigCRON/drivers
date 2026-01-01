RUN_DIR=.work

sim: ../rtl/clock_divider.v testcase.sv
	mkdir -p ${RUN_DIR}
	#verilator --quiet --error-limit 100 --sv --binary --timing --trace-fst -Wno-fatal -DHL_MODEL -I../rtl/ --top testcase $^ -o $@
	#./obj_dir/$@
	iverilog -g2012 -DHL_MODEL -I../rtl/ $^ -s testcase -o ${RUN_DIR}/$@
	vvp -i ${RUN_DIR}/$@ -fst

view: waves.fst
	gtkwave $^ &
