RUN_DIR=.work

sim-%: irun-%.args
	mkdir -p ${RUN_DIR}
	iverilog -g2012 -DHL_MODEL -f $(@:sim%=irun%).args -s testcase -o ${RUN_DIR}/$@
	vvp -i ${RUN_DIR}/$@ -fst

view: *.fst
	gtkwave $^ &

syn:
	yosys -L ../synth/syn.log -c ../synth/syn-map.tcl -o top-syn.v
