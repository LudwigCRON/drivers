yosys logger -nostderr

set PROJECT_ROOT "/home/lcr/Documents/drivers"

set v2k [list \
    ${PROJECT_ROOT}/clock_divider/rtl/clock_divider.v  \
    ${PROJECT_ROOT}/tap/rtl/tap.v  \
    ${PROJECT_ROOT}/tap/rtl/opcg.v  \
    ${PROJECT_ROOT}/top/rtl/ana_ctrl.v  \
    ${PROJECT_ROOT}/top/rtl/dsp.v  \
    ${PROJECT_ROOT}/top/rtl/top.v \
]
set sv [list ]
set libs [list ]
set lefs [list ]

# register all in a dict to simplify use
set inputs [dict create ]
dict set inputs "vlog2k" $v2k
dict set inputs "sv" $sv
dict set inputs "libs" $libs
dict set inputs "lefs" $lefs

dict for {type files} $inputs {
    foreach file $files {
        yosys read -$type $file
    }
}
yosys hierarchy -check -top top

# expression optimization
yosys proc
yosys opt
yosys fsm -expand
yosys opt
yosys memory
yosys opt

# map to the technology cells
# dfflibmap -liberty <>
# abc -liberty <>
# abc -dont_use <sdff,clk cells,...>
# abc -constr <constraint file> (set_driving_cell, set_load)
# abc -keepff # for logic equivalence checking
# abc -dress # keep naming for equivalence checking
# clean
# ideally should add IGC
# hilomap -hicell <cell type> < portname>
# hilomap -locell <cell type> < portname>
# techmap; opt
# check -mapped

# save optimized mapped netlist
yosys write_verilog -renameprefix _gen_ -noattr -noexpr -v ${PROJECT_ROOT}/top/synth/syn.v

# save some stats
yosys stat -hierarchy liberty <> -top top
