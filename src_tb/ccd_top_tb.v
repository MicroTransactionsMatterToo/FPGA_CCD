`timescale 100ns / 1ps
`include "../src/ccd_top.v"

module ccd_top_tb ();

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
	wire rd_irq;	// FPGA interrupt to CPU to initiate I2C read;

	// Design Inputs
	reg clk, rst_n;
	reg cpu_irq = 1'b0;	// CPU interrupt to FPGA to indicate read finished
	reg start = 1'b1;		// CPU line to request start of read
	reg mode = 1'b1;
	reg cp_mode = 1'b0;

	ccd_top CCD(
		.clk(clk),
		.rst_n(rst_n),
		.cpu_irq(cpu_irq),
		.start(start),
		.cp_mode(cp_mode),
		.mode(mode),
		.SH(SH),
		.PH1A1(PH1A1),
		.PH1A2(PH1A2),
		.PH2A1(PH2A1),
		.PH2A2(PH2A2),
		.CP(CP),
		.RS(RS),
		.PH1B(PH1B),
		.PHC(PHC),
		.rd_irq(rd_irq),
		.debug_o1(),
		.debug_o2()
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
		$dumpfile("ccd_top.vcd");
		$dumpvars(0, ccd_top_tb);
		#200
		start = 1'b0;
		#100
		start = 1'b1;
		#90800
		#2
		start = 1'b0;
		#2
		start = 1'b1;
		#2
		start = 1'b0;
		#90800 
		start = 1'b0;
		#2
		start = 1'b1;
		#5
		rst_n = 1'b0;
		#5 rst_n = 1'b1;
		#4		$finish;
	end

	always @(posedge rd_irq) begin 
		#3 cpu_irq = ~cpu_irq; 
		#3 cpu_irq = ~cpu_irq;
	end
endmodule