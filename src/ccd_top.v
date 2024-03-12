module ccd_top
    #(
         parameter MODE = 1'b0
     )
     (
         input clk,		// Clock, min 5 MHz
         input rst_n,	// Synchronous Reset Assert Low
         input start,	// Start read cycle
         input mode,		// Mode (0 = 1200 dpi, 1 = 600 dpi)
         input cp_mode,	// Clamp Mode (0 = Line Clamp, 1 = Bit Clamp)
         input cpu_irq,	// CPU interrupt to signal I2C read completion
         output reg SH,		// Shift Latch
         output reg PH1A1,	// Phase 1A1
         output reg PH1A2,	// Phase 1A2
         output reg PH2A1,	// Phase 2A1
         output reg PH2A2,	// Phase 2A2
         output reg CP,		// Clamp Gate
         output reg RS,		// Reset Gate
         output reg PH1B,	// Phase 1B
         output reg PHC,		// Phase C
         output reg rd_irq,	// FPGA interrupt to CPU to initiate I2C read
		 output reg sample, // FPGA signal to trigger ADC read
		 output debug_o1,
		 output debug_o2
     );

	 assign debug_o1 = start;
	 assign debug_o2 = state[5];

    localparam SIZE = 7;
    localparam ELEMENT_COUNT = (MODE) ? 10776 : 5338;
    localparam
        IDLE = 			7'b001,
		CLK_PH_I =		7'b10,
        CLK_PH_1 = 		7'b100,
        CLK_PH_2 = 		7'b1000,
        SEND_INT = 		7'b10000,
        AWAIT_CPU = 	7'b100000,
		TOGGLE_SH = 	7'b1000000;

    reg [15:0] read_count = 16'd0;
    reg [15:0] counter	= 16'd0;
    reg [SIZE-1:0] state;
    reg [SIZE-1:0] next;


    always @(posedge clk)
        if	(!rst_n)	state <= IDLE;
        else			state <= next;

    always @(*) begin
        next = 'bx;
        case (state)
				IDLE :	if (!start)														next = TOGGLE_SH;
						else															next = IDLE;
				TOGGLE_SH:	if (counter >= 1)											next = CLK_PH_I;
							else														next = TOGGLE_SH;
				CLK_PH_I:																next = CLK_PH_2;
				CLK_PH_1:																next = CLK_PH_2;
				CLK_PH_2:																next = SEND_INT;
				SEND_INT:																next = AWAIT_CPU;
				AWAIT_CPU:	if (read_count >= ELEMENT_COUNT && !cpu_irq)					next = IDLE;
							else if (!cpu_irq)											next = CLK_PH_1;
							else														next = AWAIT_CPU;
				default:																next = 'bx;
        endcase
    end

	always @(posedge clk)
	 	if (!rst_n)	begin
			rd_irq <= 1'b0;
		end
		else begin
			case (next)
				IDLE:	begin
							SH <= 1'b0;
							RS <= 1'b0;
							CP <= 1'b0;
							{PH1A1, PH1A2, PH1B} <= {3{1'b1}};
							{PH2A1, PH2A2}	<= {2{1'b0}};
							PHC <= (mode) ? 1'b1 : 1'b0;
							rd_irq <= 1'b0;
							read_count <= 16'b0;
							counter <= 16'b0;
					end
				TOGGLE_SH:begin
							SH <= 1'b1;
							counter <= counter + 16'd1;
					end
				CLK_PH_I: begin
							SH <= 1'b0;
							RS <= 1'b1;
							CP <= 1'b1;
							{PH1A1, PH1A2, PH1B} <= {3{1'b1}};
							{PH2A1, PH2A2} <= {3{1'b0}};
							PHC <= 1'b1;
					end
				CLK_PH_1: begin
							rd_irq <= 1'b0;
							RS <= 1'b1;
							CP <= cp_mode;
							{PH1A1, PH1A2, PH1B} <= {3{1'b1}};
							{PH2A1, PH2A2} <= {3{1'b0}};
							PHC <= 1'b1;
					end
				CLK_PH_2: begin
						if (mode) begin
							RS <= 1'b0;
							CP <= 1'b0;
							{PH1A1, PH1A2, PH1B, PHC} <= {4{1'b0}};
							{PH2A1, PH2A2} <= {2{1'b1}};
						end
						else begin
							RS <= 1'b0;
							CP <= 1'b0;
							PHC <= 1'b0;
						end
					end
				SEND_INT: begin 
					rd_irq <= 1'b1;
					read_count <= read_count + 16'd1;
				end
				AWAIT_CPU: begin end
			endcase
		end

    

endmodule
