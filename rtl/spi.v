`timescale 1ns/1ps
module spi_master (
    input clk,
    input rst,
    input start,
    input [7:0] tx_data,
    input miso,
    input [15:0] divider,
    output reg sclk,
    output reg cs,
    output reg mosi,
    output reg [7:0] rx_data,
    output reg busy,
    output reg done
);
    reg [7:0] tx_shift;
    reg [7:0] rx_shift;
    reg [3:0] bit_count;
    reg [15:0] clock_count;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sclk <= 0;
            cs <= 1;
            mosi <= 0;
            rx_data <= 0;
            tx_shift <= 0;
            rx_shift <= 0;
            bit_count <= 0;
            clock_count <= 0;
            busy <= 0;
            done <= 0;
        end else begin
            done <= 0;

            if (!busy && start) begin
                tx_shift <= tx_data;
                rx_shift <= 0;
                bit_count <= 0;
                clock_count <= 0;
                sclk <= 0;
                cs <= 0;
                mosi <= tx_data[7];
                busy <= 1;
            end else if (busy) begin
                if (clock_count >= divider - 1) begin
                    clock_count <= 0;
                    sclk <= ~sclk;

                    if (!sclk) begin
                        rx_shift <= {rx_shift[6:0], miso};
                    end else begin
                        if (bit_count == 7) begin
                            rx_data <= rx_shift;
                            cs <= 1;
                            sclk <= 0;
                            busy <= 0;
                            done <= 1;
                        end else begin
                            bit_count <= bit_count + 1;
                            tx_shift <= {tx_shift[6:0], 1'b0};
                            mosi <= tx_shift[6];
                        end
                    end
                end else clock_count <= clock_count + 1;
            end
        end
    end
endmodule

module spi_bus (
    input clk,
    input rst,
    input sel,
    input [11:0] offset,
    input we,
    input [31:0] wdata,
    input miso,
    output sclk,
    output cs,
    output mosi,
    output [31:0] rdata
);
    reg [7:0] tx_data;
    reg start;
    reg [15:0] divider;
    reg done_latched;
    reg sel_prev;
    reg [11:0] offset_prev;
    reg we_prev;
    wire [7:0] rx_data;
    wire busy;
    wire done;
    wire read_event = sel && !we &&
                      (!sel_prev || we_prev || offset_prev != offset);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tx_data <= 0;
            start <= 0;
            divider <= 2;
            done_latched <= 0;
            sel_prev <= 0;
            offset_prev <= 0;
            we_prev <= 0;
        end else begin
            start <= 0;
            if (read_event && offset == 12'h004)
                done_latched <= 0;
            if (sel && we) begin
                case (offset)
                    12'h000: tx_data <= wdata[7:0];
                    12'h008: begin
                        start <= wdata[0];
                        if (wdata[0])
                            done_latched <= 0;
                    end
                    12'h00C: divider <= wdata[15:0];
                endcase
            end
            if (done && !(sel && we && offset == 12'h008 && wdata[0]))
                done_latched <= 1;
            sel_prev <= sel;
            offset_prev <= offset;
            we_prev <= we;
        end
    end

    spi_master master (
        .clk(clk),
        .rst(rst),
        .start(start),
        .tx_data(tx_data),
        .miso(miso),
        .divider(divider),
        .sclk(sclk),
        .cs(cs),
        .mosi(mosi),
        .rx_data(rx_data),
        .busy(busy),
        .done(done)
    );

    assign rdata = !sel ? 32'd0 :
                   offset == 12'h000 ? {24'd0, rx_data} :
                   offset == 12'h004 ? {30'd0, done_latched, busy} :
                   offset == 12'h00C ? {16'd0, divider} : 32'd0;
endmodule
