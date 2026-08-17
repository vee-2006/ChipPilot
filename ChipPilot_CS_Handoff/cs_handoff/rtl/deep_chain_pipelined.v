module deep_chain_pipelined (
    input        clk,
    input  [31:0] a,
    input  [31:0] b,
    input  [31:0] c,
    input  [31:0] d,
    input  [31:0] e,
    input  [31:0] f,
    output reg [31:0] y
);

reg [31:0] a_r, b_r, c_r, d_r, e_r, f_r;
reg [31:0] s1;
reg [31:0] s2;
reg [31:0] s3;
reg [31:0] s4;
reg [31:0] s5;

always @(posedge clk) begin

    // Stage 1: input capture + first operation
    a_r <= a;
    b_r <= b;
    c_r <= c;
    d_r <= d;
    e_r <= e;
    f_r <= f;

    s1 <= a + b;

    // Stage 2
    s2 <= s1 ^ c_r;

    // Stage 3
    s3 <= s2 + d_r;

    // Stage 4
    s4 <= s3 ^ e_r;

    // Stage 5
    s5 <= s4 + f_r;

    // Output register
    y <= s5;

end

endmodule
