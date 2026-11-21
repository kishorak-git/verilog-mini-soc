`timescale 1ns/1ps
module ram (
    input clk,
    input sel,
    input [11:0] offset,
    input we,
    input [31:0] wdata,
    output [31:0] rdata
);
    reg [31:0] memory [0:1023];

    always @(posedge clk) begin
        if (sel && we)
            memory[offset[11:2]] <= wdata;
    end

    assign rdata = sel ? memory[offset[11:2]] : 32'd0;
endmodule
