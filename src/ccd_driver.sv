`default_nettype none

`define ASSERT_CLK1(state) assert({PH1A1, PH1A2, PH1B} == {3{'state}})
`define ASSERT_CLK2(state) assert({PH2A1, PH2A2, PHC} == {3{'state}})
`define ASSERT_CNTR_LEQ(max) assert(counter	<= COUNTER_WIDTH'(max) && counter >= COUNTER_WIDTH'(1'd1))
`define ASSERT_PREV_STATE(prev_state) assert(state == prev_state)
`define ASSERT_PREV_STATES(prev_state1, prev_state2) assert(state == prev_state1 || state == prev_state2)
`define ASSERT_RDCNT(_)	assert(read_count <= ELEMENT_COUNT && read_count >= ELEMNT_CTR_WIDTH'(1'd1))

module ccd_driver
	#(
		parameter WIDTH_M = 1'b1,
		parameter CLK_FREQ = 'd35
	) (
		input clk,		// Clock, min 5MHz
		input rst_n,	// Reset, Active Low
		input read_i,	// Trigger Read
		input line_mode,// Line Mode (0 = 1200dpi, 1 = 600 dpi)
		input cp_mode,	// Clamp Mode (0 = Line Clamp, 1 = Bit Clamp)
		input advance,	// Continue read

		output reg SH,		// Shift Latch
		output reg PH1A1,	// Phase 1A1
		output reg PH1A2,	// Phase 1A2
		output reg PH2A1,	// Phase 2A1
		output reg PH2A2,	// Phase 2A2
		output reg CP,		// Clamp Gate
		output reg RS,		// Reset Gate
		output reg PH1B,	// Phase 1B
		output reg PHC,		// Phase C

		output reg pixel_ready, // Used to indicate current pixel has been clocked out
		output reg init_state,	// Whether the PREP_* needs to be run again or not
		output reg ready	// Whether ready for another read
	);

	typedef enum bit [5:0] {
		INIT,
		IDLE,
		PREP_1, PREP_W1,
		PREP_2, PREP_W2,
		PREP_3, PREP_W3,
		PREP_4, PREP_W4,
		PREP_5_RS, PREP_5_CP, PREP_W5,
		PREP_6, PREP_W6,
		CLK_S1, CLK_S2, CLK_S3, CLK_S4,
		CLK_ADV_WAIT1,
		CLK_S5, CLK_S6, CLK_S7, CLK_S8,
		CLK_ADV_WAIT2,
		CLK_S9, CLK_S10,
		XX
	} CCD_STATE;

	parameter COUNTER_WIDTH = 16;
	
	localparam ELEMNT_CTR_WIDTH = (WIDTH_M) ? 14 : 13;
	localparam bit unsigned [ELEMNT_CTR_WIDTH:0] ELEMENT_COUNT = (WIDTH_M) ? 10776 : 5338;
	localparam bit unsigned [COUNTER_WIDTH-1:0] W1_CMAX = 6;
	localparam bit unsigned [COUNTER_WIDTH-1:0] W2_CMAX = 5;
	localparam bit unsigned [COUNTER_WIDTH-1:0] W3_CMAX = 150;
	`ifndef FORMAL
	localparam bit unsigned [COUNTER_WIDTH-1:0] W4_CMAX = (COUNTER_WIDTH'($rtoi($ceil(500E-9 / (1.0 / CLK_FREQ)))));
	localparam bit unsigned [COUNTER_WIDTH-1:0] W5_CMAX = (COUNTER_WIDTH'($rtoi($ceil(600E-9 / (1.0 / CLK_FREQ)))));
	localparam bit unsigned [COUNTER_WIDTH-1:0] S10_CMAX = 1000;
	`else
	localparam bit unsigned [COUNTER_WIDTH-1:0] W4_CMAX	= 18;
	localparam bit unsigned [COUNTER_WIDTH-1:0] W5_CMAX = 21;
	localparam bit unsigned [COUNTER_WIDTH-1:0] S10_CMAX = 1000;
	`endif

	localparam bit unsigned [COUNTER_WIDTH-1:0] W6_CMAX = 200;
	
	CCD_STATE state, next;

	reg unsigned [31:0] read_count 					= '0;
	reg unsigned [COUNTER_WIDTH-1:0] counter 		= '0;

	reg read_latch								= '0;
	

	`ifdef FORMAL
		initial assume(!rst_n);
	`endif

	initial state 	= INIT;

	always_ff @(posedge clk, negedge rst_n)
		if (!rst_n)	state <= INIT;
		else		state <= next;
	// verilator lint_off UNSIGNED
	always_comb begin
		next = XX;
		case (state)
			INIT		:											next = IDLE;
			IDLE		: 	if (read_i && ready && !read_latch)		next = PREP_1;
							else									next = IDLE;
			PREP_1		:											next = PREP_W1;
			PREP_W1		:	if (counter >= W1_CMAX)					next = PREP_2;
							else									next = PREP_W1;
			PREP_2		:											next = PREP_W2;
			PREP_W2		:	if (counter >= W2_CMAX)					next = PREP_3;
							else									next = PREP_W2;
			PREP_3		:											next = PREP_W3;
			PREP_W3		:	if (counter >= W3_CMAX)					next = PREP_4;
							else									next = PREP_W3;
			PREP_4		:											next = PREP_W4;
			PREP_W4		:	if (counter >= W4_CMAX)					next = PREP_5_RS;
							else									next = PREP_W4;
			PREP_5_RS	:											next = PREP_5_CP;
			PREP_5_CP	:											next = PREP_W5;
			PREP_W5		:	if (counter >= W5_CMAX)					next = PREP_6;
			PREP_6		:											next = PREP_W6;
			PREP_W6		:	if (counter >= W6_CMAX)					next = CLK_S1;
							else									next = PREP_W6;
		//  ----- MAIN READ CYCLE -----			
			CLK_S1		:											next = CLK_S2;
			CLK_S2		:											next = CLK_S3;
			CLK_S3		:											next = CLK_S4;
			CLK_S4		:											next = CLK_ADV_WAIT1;
		CLK_ADV_WAIT1	:	if (advance == '1)						next = CLK_S5;
							else									next = CLK_ADV_WAIT1;
			CLK_S5		:											next = CLK_S6;
			CLK_S6		:											next = CLK_S7;
			CLK_S7		:											next = CLK_S8;
			CLK_S8		:											next = CLK_ADV_WAIT2;
		CLK_ADV_WAIT2	:	if (advance == '1)						next = CLK_S9;
							else									next = CLK_ADV_WAIT2;
			CLK_S9		:											next = CLK_S10;
			CLK_S10		:	if (counter >= S10_CMAX || 
								read_count >= ELEMENT_COUNT)		next = IDLE;
							else if (
								advance == '1 &&
								!(counter >= S10_CMAX || read_count == ELEMENT_COUNT)
							)										next = CLK_S1;
							else									next = CLK_S10;
			XX			:											next = INIT;
			default		:											next = XX;
		endcase
	end
	// verilator lint_on UNSIGNED

	// verilator lint_off WIDTHEXPAND
	always_ff @(posedge clk, negedge rst_n)
		if (!rst_n) begin
			pixel_ready <= '0;
			ready 		<= '0;
		end
		else begin
			case (next)
				INIT : begin
					counter 	<= '0;
					read_count	<= '0;
					init_state	<= '1;
					ready		<= '0;
					pixel_ready <= '0;
				end
				IDLE : begin
					// OUTPUTS
					{SH, RS, CP}			<= {3{'0}};
					{PH1A1, PH1A2, PH1B}	<= {3{'1}};
					{PH2A1, PH2A2, PHC}		<= {3{'0}};

					pixel_ready				<= '0;
					ready					<= '1;
					// INTERNAL
					read_count				<= '0;
					counter					<= '0;

					read_latch				<= read_i;

					// ASSERTIONS
					`ifdef FORMAL
					assert(
						state == INIT ||
						state == IDLE ||
						state == CLK_S10
					);
					`endif
				end
				PREP_1 : begin
					// OUTPUTS
					{PH1A1, PH1A2, PH1B}	<= {3{'0}};
					ready					<= '0;
					pixel_ready 			<= '0;
					init_state 				<= '1;
					read_latch				<= '1;

					// INTERNAL
					counter <= counter + COUNTER_WIDTH'(1);

					// ASSERTIONS
					`ifdef FORMAL
					assert({SH, RS, CP} 		== {3{'0}});
					assert(ready 				== '1);
					assert(pixel_ready			== '0);
					assert(counter				== '0);
					assert(read_latch			== '0);

					`ASSERT_CLK1(1);
					`ASSERT_CLK2(0);

					assert(
						state	== IDLE
					);
					// ASSUMES
					assume(read_i	== '1);
					assume(advance	== '0);

					`endif
				end
				PREP_W1 : begin
					// INTERNAL
					counter <= counter + 16'd1;

					// ASSERTIONS
					`ifdef FORMAL
					assert({SH, RS, CP} 		== {3{'0}});
					assert(ready 				== '0);
					assert(pixel_ready			== '0);
					assert(init_state			== '1);
					assert(read_latch			== '1);

					`ASSERT_CLK1(0);
					`ASSERT_CLK2(0);
					`ASSERT_CNTR_LEQ(W1_CMAX);

					assert(
						state	== PREP_1 ||
						state	== PREP_W1
					);					
					`endif
				end
				PREP_2 : begin
					// OUTPUTS
					{PH1A1, PH1A2, PH1B}	<= {3{'1}};

					// INTERNAL
					counter 				<= COUNTER_WIDTH'(1);

					// ASSERTIONS
					`ifdef FORMAL
					assert({SH, RS, CP} 		== {3{'0}});
					assert(ready 				== '0);
					assert(pixel_ready			== '0);
					assert(init_state			== '1);
					assert(read_latch			== '1);

					`ASSERT_CLK1(0);
					`ASSERT_CLK2(0);
					`ASSERT_CNTR_LEQ(W1_CMAX);

					`ASSERT_PREV_STATE(PREP_W1);
					`endif
				end
				PREP_W2 : begin
					// INTERNAL
					counter	<= counter + COUNTER_WIDTH'(1);

					// ASSERTIONS
					`ifdef FORMAL
					assert({SH, RS, CP} 		== {3{'0}});
					assert(ready 				== '0);
					assert(pixel_ready			== '0);
					assert(init_state			== '1);
					assert(read_latch			== '1);

					`ASSERT_CLK1(1);
					`ASSERT_CLK2(0);
					`ASSERT_CNTR_LEQ(W2_CMAX);
					`ASSERT_PREV_STATES(PREP_2, PREP_W2);
					`endif
				end
				PREP_3 : begin
					// OUTPUTS
					SH	<= '1;

					// INTERNAL
					counter				<= COUNTER_WIDTH'(1);

					// ASSERTIONS
					`ifdef FORMAL
					assert({SH, RS, CP} 		== {3{'0}});
					assert(ready 				== '0);
					assert(pixel_ready			== '0);
					assert(init_state			== '1);
					assert(read_latch			== '1);

					`ASSERT_CLK1(1);
					`ASSERT_CLK2(0);
					`ASSERT_CNTR_LEQ(W2_CMAX);
					`ASSERT_PREV_STATE(PREP_W2);
					`endif
				end
				PREP_W3 : begin
					// INTERNAL
					counter 	<= counter + COUNTER_WIDTH'(1);
					
					// ASSERTIONS
					`ifdef FORMAL
					assert(SH == '1);
					assert({RS, CP} 		== {2{'0}});
					assert(ready 				== '0);
					assert(pixel_ready			== '0);
					assert(init_state			== '1);
					assert(read_latch			== '1);

					`ASSERT_CLK1(1);
					`ASSERT_CLK2(0);
					`ASSERT_CNTR_LEQ(W3_CMAX);
					`ASSERT_PREV_STATES(PREP_3, PREP_W3);
					`endif
				end
				PREP_4 : begin
					// OUTPUTS
					SH	<= '0;
					// INTERNAL
					counter <= COUNTER_WIDTH'(1);

					// ASSERTIONS
					`ifdef FORMAL
					assert(SH == '1);
					assert({RS, CP} 		== {2{'0}});
					assert(ready 				== '0);
					assert(pixel_ready			== '0);
					assert(init_state			== '1);
					assert(read_latch			== '1);

					`ASSERT_CLK1(1);
					`ASSERT_CLK2(0);
					`ASSERT_CNTR_LEQ(W3_CMAX);
					`ASSERT_PREV_STATE(PREP_W3);
					`endif
				end
				PREP_W4 : begin
					// INTERNAL
					counter <= counter + COUNTER_WIDTH'(1);

					// ASSERTIONS
					`ifdef FORMAL
					assert({SH, RS, CP} 		== {3{'0}});
					assert(ready 				== '0);
					assert(pixel_ready			== '0);
					assert(init_state			== '1);
					assert(read_latch			== '1);

					`ASSERT_CLK1(1);
					`ASSERT_CLK2(0);
					`ASSERT_CNTR_LEQ(W4_CMAX);
					`ASSERT_PREV_STATES(PREP_4, PREP_W4);
					`endif
				end
				PREP_5_RS : begin
					// OUTPUTS
					RS <= '1;

					// INTERNAL
					counter <= COUNTER_WIDTH'(1);

					// ASSERTIONS
					`ifdef FORMAL
					assert({SH, RS, CP} 		== {3{'0}});
					assert(ready 				== '0);
					assert(pixel_ready			== '0);
					assert(init_state			== '1);
					assert(read_latch			== '1);

					`ASSERT_CLK1(1);
					`ASSERT_CLK2(0);
					`ASSERT_CNTR_LEQ(W4_CMAX);
					`ASSERT_PREV_STATE(PREP_W4);
					`endif
				end
				PREP_5_CP : begin
					// OUTPUTS
					CP <= '1;

					// ASSERTIONS
					`ifdef FORMAL
					assert(RS					== '1);
					assert({SH, CP} 			== {2{'0}});
					assert(ready 				== '0);
					assert(pixel_ready			== '0);
					assert(init_state			== '1);
					assert(read_latch			== '1);

					`ASSERT_CLK1(1);
					`ASSERT_CLK2(0);
					`ASSERT_PREV_STATE(PREP_5_RS);
					assert(counter == COUNTER_WIDTH'(1));
					`endif
				end
				PREP_W5 : begin
					// INTERNAL
					counter <= counter + COUNTER_WIDTH'(1);

					// ASSERTIONS
					`ifdef FORMAL
					assert(SH					== '0);
					assert({RS, CP} 			== {2{'1}});
					assert(ready 				== '0);
					assert(pixel_ready			== '0);
					assert(init_state			== '1);
					assert(read_latch			== '1);

					`ASSERT_CLK1(1);
					`ASSERT_CLK2(0);
					`ASSERT_CNTR_LEQ(W5_CMAX);
					`ASSERT_PREV_STATES(PREP_5_CP, PREP_W5);
					`endif
				end
				PREP_6 : begin
					// INTERNAL
					counter 	<= COUNTER_WIDTH'(1);
					
					// ASSERTIONS
					`ifdef FORMAL
					assert(SH					== '0);
					assert({RS, CP} 			== {2{'1}});
					assert(ready 				== '0);
					assert(pixel_ready			== '0);
					assert(init_state			== '1);
					assert(read_latch			== '1);

					`ASSERT_CLK1(1);
					`ASSERT_CLK2(0);
					`ASSERT_CNTR_LEQ(W5_CMAX);
					`ASSERT_PREV_STATE(PREP_W5);
					`endif
				end
				PREP_W6 : begin
					counter <= counter + COUNTER_WIDTH'(1);
					init_state <= '0;

					// ASSERTIONS
					`ifdef FORMAL
					assert(SH					== '0);
					assert({RS, CP} 			== {2{'1}});
					assert(ready 				== '0);
					assert(pixel_ready			== '0);

					`ASSERT_CLK1(1);
					`ASSERT_CLK2(0);
					`ASSERT_CNTR_LEQ(W6_CMAX);
					`ASSERT_PREV_STATES(PREP_6, PREP_W6);
					`endif
				end
				CLK_S1	: begin
					{PH1A1, PH1A2, PH1B}	<= {3{'1}};
					{PH2A1, PH2A2}			<= {2{'0}};
					PHC						<= '1;
					RS						<= '1;
					CP						<= '1;

					// ASSERTIONS
					`ifdef FORMAL
					`ASSERT_PREV_STATES(PREP_W6, CLK_S10);
					assert(init_state		== '0);
					`endif
				end
				CLK_S2	: begin
					RS						<= '0;

					// ASSERTIONS
					`ifdef FORMAL
					assert(CP == '1);
					assert(RS == '1);
					assert(PHC == '1);

					`ASSERT_PREV_STATE(CLK_S1);
					`ASSERT_CLK1(1);
					assert({PH2A1, PH2A2}	== {2{'0}});
					`endif
				end
				CLK_S3	: begin
					CP						<= '0;

					// ASSERTIONS
					`ifdef FORMAL
					assert(CP == '1);
					assert(RS == '0);
					assert(PHC == '1);

					`ASSERT_PREV_STATE(CLK_S2);
					`ASSERT_CLK1(1);
					assert({PH2A1, PH2A2}	== {2{'0}});
					`endif
				end
				CLK_S4	: begin
					PHC						<= '0;

					// ASSERTIONS
					`ifdef FORMAL
					assert(CP == '0);
					assert(RS == '0);
					assert(PHC == '1);

					`ASSERT_PREV_STATE(CLK_S3);
					`ASSERT_CLK1(1);
					assert({PH2A1, PH2A2}	== {2{'0}});
					`endif
				end
				CLK_ADV_WAIT1 : begin
					pixel_ready				<= '1;

					// ASSERTIONS
					`ifdef FORMAL
					assert(CP == '0);
					assert(RS == '0);
					assert(PHC == '0);

					`ASSERT_PREV_STATES(CLK_S4, CLK_ADV_WAIT1);
					`ASSERT_CLK1(1);
					assert({PH2A1, PH2A2}	== {2{'0}});
					`endif
				end
				CLK_S5	: begin
					read_count				<= read_count + ELEMNT_CTR_WIDTH'(1);
					pixel_ready				<= '0;
					RS						<= '1;
					CP						<= '1;

					// ASSERTIONS
					`ifdef FORMAL
					assert(CP == '0);
					assert(RS == '0);
					assert(PHC == '0);

					assert(pixel_ready	== '1);

					`ASSERT_PREV_STATE(CLK_ADV_WAIT1);
					`ASSERT_CLK1(1);
					assert({PH2A1, PH2A2}	== {2{'0}});
					`endif
				end
				CLK_S6	: begin
					RS						<= '0;

					// ASSERTIONS
					`ifdef FORMAL
					assert(CP == '1);
					assert(RS == '1);
					assert(PHC == '0);


					`ASSERT_PREV_STATE(CLK_S5);
					`ASSERT_CLK1(1);
					assert({PH2A1, PH2A2}	== {2{'0}});
					`endif
				end
				CLK_S7	: begin
					CP						<= '0;

					// ASSERTIONS
					`ifdef FORMAL
					assert(CP == '1);
					assert(RS == '0);
					assert(PHC == '0);


					`ASSERT_PREV_STATE(CLK_S6);
					`ASSERT_CLK1(1);
					assert({PH2A1, PH2A2}	== {2{'0}});
					`endif
				end
				CLK_S8	: begin
					{PH1A1, PH1A2, PH1B}	<= {3{'0}};
					{PH2A1, PH2A2}			<= {2{'1}};

					// ASSERTIONS
					`ifdef FORMAL
					assert(CP == '0);
					assert(RS == '0);
					assert(PHC == '0);


					`ASSERT_PREV_STATE(CLK_S7);
					`ASSERT_CLK1(1);
					assert({PH2A1, PH2A2}	== {2{'0}});
					`endif
				end
				CLK_ADV_WAIT2 : begin
					pixel_ready				<= '1;

					// ASSERTIONS
					`ifdef FORMAL
					assert(CP == '0);
					assert(RS == '0);
					assert(PHC == '0);


					`ASSERT_PREV_STATES(CLK_S8, CLK_ADV_WAIT2);
					`ASSERT_CLK1(0);
					assert({PH2A1, PH2A2}	== {2{'1}});
					`endif
				end
				CLK_S9	: begin
					pixel_ready		<= '0;
					read_count		<= read_count + ELEMNT_CTR_WIDTH'(1);
					counter			<= COUNTER_WIDTH'(1);

					// ASSERTIONS
					`ifdef FORMAL
					assert(CP == '0);
					assert(RS == '0);
					assert(PHC == '0);
					assert(pixel_ready == '1);


					`ASSERT_PREV_STATE(CLK_ADV_WAIT2);
					`ASSERT_CLK1(0);
					assert({PH2A1, PH2A2}	== {2{'1}});
					`endif
				end
				CLK_S10	: begin
					counter			<= counter + COUNTER_WIDTH'(1);
					init_state		<= '0;

					// ASSERTIONS
					`ifdef FORMAL
					assert(CP == '0);
					assert(RS == '0);
					assert(PHC == '0);
					assert(pixel_ready == '0);


					`ASSERT_PREV_STATES(CLK_S9, CLK_S10);
					// `ASSERT_RDCNT(X);
					`ASSERT_CLK1(0);
					`ASSERT_CNTR_LEQ(S10_CMAX);
					assert({PH2A1, PH2A2}	== {2{'1}});
					`endif
				end
				default : begin
				end
			endcase
		end
	

endmodule
