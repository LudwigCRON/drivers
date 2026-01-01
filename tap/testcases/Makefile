RUN_DIR=.work

sim: tap_master.sv ../rtl/opcg.v ../rtl/tap.v testcase.sv
	mkdir -p ${RUN_DIR}
	iverilog -g2012 -DHL_MODEL -I../rtl/ $^ -s testcase -o ${RUN_DIR}/$@
	vvp -i ${RUN_DIR}/$@ -fst

view: waves.fst
	gtkwave $^ &
