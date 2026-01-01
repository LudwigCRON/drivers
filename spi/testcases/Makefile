RUN_DIR=.work

sim: ../rtl/handshake_2states.v ../rtl/spi_slave.v spi_driver.sv spi_monitor.sv testcase.sv
	mkdir -p ${RUN_DIR}
	# verilator --quiet --error-limit 100 --sv --binary --timing --trace-fst -Wno-fatal -I../rtl/ --top testcase $^ -o $@
	# ./obj_dir/$@
	iverilog -g2012 -I../rtl/ $^ -s testcase -o ${RUN_DIR}/$@
	vvp -i ${RUN_DIR}/$@ -fst

view: waves.fst
	gtkwave $^ &
