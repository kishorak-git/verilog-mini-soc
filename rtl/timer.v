`timescale 1ns/1ps
module timer (
    input clk,
    input rst,
    input sel,
    input [11:0] offset,
    input we,
    input [31:0] wdata,
    output [31:0] rdata
);
    reg enable;
    reg [31:0] count;
    reg [31:0] period;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            enable <= 0;
            count <= 0;
            period <= 0;
        end else begin
            if (sel && we) begin
                case (offset)
                    12'h000: enable <= wdata[0];
                    12'h008: period <= wdata;
                endcase
            end

            if (enable) begin
                if (period != 0 && count >= period - 1)
                    count <= 0;
                else
                    count <= count + 1;
            end else begin
                count <= 0;
            end
        end
    end

    assign rdata = !sel ? 32'd0 :
                   offset == 12'h000 ? {31'd0, enable} :
                   offset == 12'h004 ? count :
                   offset == 12'h008 ? period : 32'd0;
endmodule
