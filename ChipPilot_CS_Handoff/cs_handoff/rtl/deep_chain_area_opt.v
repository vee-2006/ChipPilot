module deep_chain_area_opt (
    input        clk,
    input  [31:0] a,
    input  [31:0] b,
    input  [31:0] c,
    input  [31:0] d,
    input  [31:0] e,
    input  [31:0] f,
    output reg [31:0] y
);

reg [31:0] c_r, d_r, e_r, f_r;

reg [31:0] s1;
reg [31:0] s2;
reg [31:0] s3;
reg [31:0] s4;
reg [31:0] s5;

always @(posedge clk) begin

    // Delay inputs required for pipeline alignment
    c_r <= c;
    d_r <= d;
    e_r <= e;
    f_r <= f;

    // Pipeline stages
    s1 <= a + b;
    s2 <= s1 ^ c_r;
    s3 <= s2 + d_r;
    s4 <= s3 ^ e_r;
    s5 <= s4 + f_r;

    // Output register
    y <= s5;

end

endmodule
