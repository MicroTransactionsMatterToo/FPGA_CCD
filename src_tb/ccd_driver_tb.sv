`timescale 100ns / 1ps
`include "../src/ccd_driver.sv"


module ccd_driver_tb ();

	// Design Outputs
	wire SH;		// Shift Latch
	wire PH1A1;	// Phase 1A1
	wire PH1A2;	// Phase 1A2
	wire PH2A1;	// Phase 2A1
	wire PH2A2;	// Phase 2A2
	wire CP;		// Clamp Gate
	wire RS;		// Reset Gate
	wire PH1B;	// Phase 1B
	wire PHC;	// Phase C
	wire pixel_ready;	// FPGA interrupt to CPU to initiate I2C read;
	wire init_state;
	wire ready;

	// Design Inputs
	reg clk, rst_n;
	reg read_i = '0;
	reg line_mode = '0;
	reg cp_mode = '0;
	reg advance = '1;

	ccd_driver CCD(
		.clk(clk),
		.ready(ready),
		.rst_n(rst_n),
		.read_i(read_i),
		.pixel_ready(pixel_ready),
		.init_state(init_state),
		.line_mode(line_mode),
		.advance(advance),
		.cp_mode(cp_mode),
		.SH(SH),
		.PH1A1(PH1A1),
		.PH1A2(PH1A2),
		.PH2A1(PH2A1),
		.PH2A2(PH2A2),
		.CP(CP),
		.RS(RS),
		.PH1B(PH1B),
		.PHC(PHC)
	);


	// Clock Gen
	initial begin
		clk = 1'b0;
		forever #2 clk = ~clk;
	end

	// Reset Gen
	initial begin
		rst_n = 1'b0;
		#100
		rst_n = 1'b1;
	end

	initial begin
		$dumpfile("ccd_driver.fst");
		$dumpvars(0, ccd_driver_tb);
		#200
		read_i = '1;
		#276000
		read_i = '0;
		#2000
		read_i = '1;
		#1921000
		$finish;
	end

endmodule
