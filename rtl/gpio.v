`timescale 1ns/1ps
module gpio (
    input clk,
    input rst,
    input sel,
    input [11:0] offset,
    input we,
    input [31:0] wdata,
    input [31:0] pin_in,
    output reg [31:0] pin_out,
    output [31:0] rdata
);
    reg [31:0] input_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pin_out <= 0;
            input_reg <= 0;
        end else begin
            input_reg <= pin_in;
            if (sel && we && offset == 12'h000)
                pin_out <= wdata;
        end
    end

    assign rdata = !sel ? 32'd0 :
                   offset == 12'h000 ? pin_out :
                   offset == 12'h004 ? input_reg : 32'd0;
endmodule
