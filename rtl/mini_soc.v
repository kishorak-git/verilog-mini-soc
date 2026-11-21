`timescale 1ns/1ps
module mini_soc (
    input clk,
    input rst,
    input [15:0] addr,
    input we,
    input [31:0] wdata,
    output [31:0] rdata,
    input [31:0] gpio_in,
    output [31:0] gpio_out,
    input uart_rx,
    output uart_tx,
    input spi_miso,
    output spi_sclk,
    output spi_cs,
    output spi_mosi
);
    wire sel_ram = (addr[15:12] == 4'h0);
    wire sel_gpio = (addr[15:12] == 4'h1);
    wire sel_timer = (addr[15:12] == 4'h2);
    wire sel_uart = (addr[15:12] == 4'h3);
    wire sel_spi = (addr[15:12] == 4'h4);

    wire [31:0] ram_rdata;
    wire [31:0] gpio_rdata;
    wire [31:0] timer_rdata;
    wire [31:0] uart_rdata;
    wire [31:0] spi_rdata;

    ram ram_unit (
        .clk(clk),
        .sel(sel_ram),
        .offset(addr[11:0]),
        .we(we),
        .wdata(wdata),
        .rdata(ram_rdata)
    );

    gpio gpio_unit (
        .clk(clk),
        .rst(rst),
        .sel(sel_gpio),
        .offset(addr[11:0]),
        .we(we),
        .wdata(wdata),
        .pin_in(gpio_in),
        .pin_out(gpio_out),
        .rdata(gpio_rdata)
    );

    timer timer_unit (
        .clk(clk),
        .rst(rst),
        .sel(sel_timer),
        .offset(addr[11:0]),
        .we(we),
        .wdata(wdata),
        .rdata(timer_rdata)
    );

    uart_bus uart_unit (
        .clk(clk),
        .rst(rst),
        .sel(sel_uart),
        .offset(addr[11:0]),
        .we(we),
        .wdata(wdata),
        .rx(uart_rx),
        .tx(uart_tx),
        .rdata(uart_rdata)
    );

    spi_bus spi_unit (
        .clk(clk),
        .rst(rst),
        .sel(sel_spi),
        .offset(addr[11:0]),
        .we(we),
        .wdata(wdata),
        .miso(spi_miso),
        .sclk(spi_sclk),
        .cs(spi_cs),
        .mosi(spi_mosi),
        .rdata(spi_rdata)
    );

    assign rdata = sel_ram ? ram_rdata :
                   sel_gpio ? gpio_rdata :
                   sel_timer ? timer_rdata :
                   sel_uart ? uart_rdata :
                   sel_spi ? spi_rdata : 32'd0;
endmodule
