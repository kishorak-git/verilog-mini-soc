`timescale 1ns/1ps
module uart_tx (
    input clk,
    input rst,
    input start,
    input [7:0] data,
    input [15:0] clocks_per_bit,
    output reg tx,
    output busy,
    output reg done
);
    localparam IDLE = 2'd0;
    localparam START = 2'd1;
    localparam DATA = 2'd2;
    localparam STOP = 2'd3;

    reg [1:0] state;
    reg [15:0] clock_count;
    reg [2:0] bit_index;
    reg [7:0] shift_data;

    assign busy = (state != IDLE);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            tx <= 1;
            clock_count <= 0;
            bit_index <= 0;
            shift_data <= 0;
            done <= 0;
        end else begin
            done <= 0;

            case (state)
                IDLE: begin
                    tx <= 1;
                    clock_count <= 0;
                    bit_index <= 0;
                    if (start) begin
                        shift_data <= data;
                        tx <= 0;
                        state <= START;
                    end
                end

                START: begin
                    if (clock_count >= clocks_per_bit - 1) begin
                        clock_count <= 0;
                        tx <= shift_data[0];
                        state <= DATA;
                    end else clock_count <= clock_count + 1;
                end

                DATA: begin
                    if (clock_count >= clocks_per_bit - 1) begin
                        clock_count <= 0;
                        if (bit_index == 7) begin
                            tx <= 1;
                            state <= STOP;
                        end else begin
                            bit_index <= bit_index + 1;
                            shift_data <= shift_data >> 1;
                            tx <= shift_data[1];
                        end
                    end else clock_count <= clock_count + 1;
                end

                STOP: begin
                    if (clock_count >= clocks_per_bit - 1) begin
                        clock_count <= 0;
                        state <= IDLE;
                        done <= 1;
                        tx <= 1;
                    end else clock_count <= clock_count + 1;
                end
            endcase
        end
    end
endmodule

module uart_rx (
    input clk,
    input rst,
    input rx,
    input [15:0] clocks_per_bit,
    output reg [7:0] data,
    output reg ready
);
    localparam IDLE = 2'd0;
    localparam START = 2'd1;
    localparam DATA = 2'd2;
    localparam STOP = 2'd3;

    reg [1:0] state;
    reg [15:0] clock_count;
    reg [2:0] bit_index;
    reg [7:0] shift_data;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            clock_count <= 0;
            bit_index <= 0;
            shift_data <= 0;
            data <= 0;
            ready <= 0;
        end else begin
            ready <= 0;

            case (state)
                IDLE: begin
                    clock_count <= 0;
                    bit_index <= 0;
                    if (!rx)
                        state <= START;
                end

                START: begin
                    if (clock_count == (clocks_per_bit >> 1)) begin
                        clock_count <= 0;
                        if (!rx)
                            state <= DATA;
                        else
                            state <= IDLE;
                    end else clock_count <= clock_count + 1;
                end

                DATA: begin
                    if (clock_count >= clocks_per_bit - 1) begin
                        clock_count <= 0;
                        shift_data[bit_index] <= rx;
                        if (bit_index == 7)
                            state <= STOP;
                        else
                            bit_index <= bit_index + 1;
                    end else clock_count <= clock_count + 1;
                end

                STOP: begin
                    if (clock_count >= clocks_per_bit - 1) begin
                        clock_count <= 0;
                        data <= shift_data;
                        ready <= 1;
                        state <= IDLE;
                    end else clock_count <= clock_count + 1;
                end
            endcase
        end
    end
endmodule

module uart_bus (
    input clk,
    input rst,
    input sel,
    input [11:0] offset,
    input we,
    input [31:0] wdata,
    input rx,
    output tx,
    output [31:0] rdata
);
    reg [15:0] baud;
    reg [7:0] tx_data;
    reg tx_start;
    reg rx_ready_latched;
    reg tx_done_latched;
    reg sel_prev;
    reg [11:0] offset_prev;
    reg we_prev;
    wire tx_busy;
    wire tx_done;
    wire [7:0] rx_data;
    wire rx_ready;
    wire read_event = sel && !we &&
                      (!sel_prev || we_prev || offset_prev != offset);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            baud <= 8;
            tx_data <= 0;
            tx_start <= 0;
            rx_ready_latched <= 0;
            tx_done_latched <= 0;
            sel_prev <= 0;
            offset_prev <= 0;
            we_prev <= 0;
        end else begin
            tx_start <= 0;
            if (read_event) begin
                case (offset)
                    12'h000: rx_ready_latched <= 0;
                    12'h004: begin
                        rx_ready_latched <= 0;
                        tx_done_latched <= 0;
                    end
                endcase
            end
            if (sel && we) begin
                case (offset)
                    12'h000: begin
                        tx_data <= wdata[7:0];
                        tx_start <= 1;
                        tx_done_latched <= 0;
                    end
                    12'h008: baud <= wdata[15:0];
                endcase
            end
            if (rx_ready)
                rx_ready_latched <= 1;
            if (tx_done && !(sel && we && offset == 12'h000))
                tx_done_latched <= 1;
            sel_prev <= sel;
            offset_prev <= offset;
            we_prev <= we;
        end
    end

    uart_tx transmitter (
        .clk(clk),
        .rst(rst),
        .start(tx_start),
        .data(tx_data),
        .clocks_per_bit(baud),
        .tx(tx),
        .busy(tx_busy),
        .done(tx_done)
    );

    uart_rx receiver (
        .clk(clk),
        .rst(rst),
        .rx(rx),
        .clocks_per_bit(baud),
        .data(rx_data),
        .ready(rx_ready)
    );

    assign rdata = !sel ? 32'd0 :
                   offset == 12'h000 ? {24'd0, rx_data} :
                   offset == 12'h004 ? {29'd0, rx_ready_latched, tx_done_latched, tx_busy} :
                   offset == 12'h008 ? {16'd0, baud} : 32'd0;
endmodule
