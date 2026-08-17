module deep_chain_3stage (
    input        clk,
    input  [31:0] a,
    input  [31:0] b,
    input  [31:0] c,
    input  [31:0] d,
    input  [31:0] e,
    input  [31:0] f,
    output reg [31:0] y
);

reg [31:0] d_r;
reg [31:0] e_r1;
reg [31:0] e_r2;
reg [31:0] f_r1;
reg [31:0] f_r2;

reg [31:0] stage1;
reg [31:0] stage2;

always @(posedge clk) begin

    // Stage 1:
    // (a + b) ^ c
    stage1 <= (a + b) ^ c;

    // Delay remaining inputs
    d_r <= d;
    e_r1 <= e;
    e_r2 <= e_r1;
    f_r1 <= f;
    f_r2 <= f_r1;

    // Stage 2:
    // ((a + b) ^ c) + d
    stage2 <= stage1 + d_r;

    // Stage 3:
    // (((a + b) ^ c) + d) ^ e + f
    y <= (stage2 ^ e_r2) + f_r2;

end

endmodule
