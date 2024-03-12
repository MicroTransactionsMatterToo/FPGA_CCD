PROJ		= filmscanner
BUILD		= ./build
DEVICE		= 8k
FOOTPRINT	= ct256

PROGRAMMER_IP =  "192.168.88.141"


INCLUDES = src/
FILES = src/ccd_driver.sv
TOP_MODULE = ccd_driver
TB_FILES = src_tb/ccd_driver_tb.sv

export OBJCACHE=ccache

all $(BUILD)/$(PROJ).asc $(BUILD)/$(PROJ).bin:
	mkdir -p $(BUILD)
	yosys -q -p "plugin -i systemverilog; read_systemverilog $(FILES); synth_ice40 -top $(TOP_MODULE) -blif $(BUILD)/$(PROJ).blif -json $(BUILD)/$(PROJ).json" 
#$(FILES)
	nextpnr-ice40 -q --package $(FOOTPRINT) --hx$(DEVICE) --json $(BUILD)/$(PROJ).json --pcf filmscanner.pcf --asc $(BUILD)/$(PROJ).asc
	icepack $(BUILD)/$(PROJ).asc $(BUILD)/$(PROJ).bin

testbench_bin:
	mkdir -p $(BUILD)/verilator/obj_dir
	verilator_bin --binary --trace-fst -j 0  $(TB_FILES) -Mdir $(BUILD)/verilator/obj_dir -I$(INCLUDES) -o $(TOP_MODULE)_tb.o
	mv $(BUILD)/verilator/obj_dir/$(TOP_MODULE)_tb.o $(BUILD)/verilator/

tb: testbench_bin
	./build/verilator/$(TOP_MODULE)_tb.o
	mv ccd_driver.fst gtkwave/

sby:
	cd src_tb; \
	sby -f ./ccd_driver.sby


upload: $(BUILD)/$(PROJ).bin
	rsync -aP $(BUILD)/$(PROJ).bin root@$(PROGRAMMER_IP):fpga/$(PROJ).bin

flash: upload
	ssh root@$(PROGRAMMER_IP) "cd fpga; ./flash_fpga.sh $(PROJ).bin"

fsm:
	yosys -p "plugin -i systemverilog; read_systemverilog $(FILES); proc; opt -nodffe -nosdff; fsm_detect -ignore-self-reset; fsm_extract; fsm_opt; fsm_export -o $(BUILD)/fsm.kiss2"
