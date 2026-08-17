module deep_chain_original (
    input         clk,
    input  [31:0] a,
    input  [31:0] b,
    input  [31:0] c,
    input  [31:0] d,
    input  [31:0] e,
    input  [31:0] f,
    output reg [31:0] y
);

reg [31:0] s1;
reg [31:0] s2;
reg [31:0] s3;
reg [31:0] s4;
reg [31:0] s5;

always @(*) begin
    s1 = a + b;
    s2 = s1 ^ c;
    s3 = s2 + d;
    s4 = s3 ^ e;
    s5 = s4 + f;
end

always @(posedge clk) begin
    y <= s5;
end

endmodule
