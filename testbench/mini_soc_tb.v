module spi_slave_model (
    input rst,
    input cs,
    input sclk,
    input mosi,
    output reg miso,
    output reg [7:0] rx_data,
    output reg rx_done
);
    reg [7:0] rx_shift;
    reg [3:0] rx_count;
    reg [3:0] tx_count;
    reg [7:0] tx_data;

    always @(posedge sclk or posedge cs or posedge rst) begin
        if (rst) begin
            rx_shift <= 0;
            rx_data <= 0;
            rx_count <= 0;
            rx_done <= 0;
        end else if (cs) begin
            rx_shift <= 0;
            rx_count <= 0;
        end else begin
            if (rx_count < 8) begin
                rx_shift <= {rx_shift[6:0], mosi};
                if (rx_count == 7) begin
                    rx_data <= {rx_shift[6:0], mosi};
                    rx_count <= 8;
                    rx_done <= 1;
                end else begin
                    rx_count <= rx_count + 1'b1;
                end
            end
        end
    end

    always @(negedge cs or negedge sclk or posedge cs or posedge rst) begin
        if (rst || cs) begin
            miso <= 1;
            tx_count <= 0;
        end else begin
            if (tx_count == 0) begin
                miso <= tx_data[7];
                tx_count <= 1;
            end else if (tx_count < 8) begin
                miso <= tx_data[7-tx_count];
                tx_count <= tx_count + 1'b1;
            end
        end
    end

    initial begin
        tx_data = 8'h3C;
        rx_data = 0;
        rx_done = 0;
        rx_shift = 0;
        rx_count = 0;
        tx_count = 0;
        miso = 1;
    end
endmodule

module mini_soc_tb;

    reg clk;
    reg rst;
    reg [15:0] addr;
    reg we;
    reg [31:0] wdata;
    wire [31:0] rdata;

    reg [31:0] gpio_in;
    wire [31:0] gpio_out;

    wire uart_rx;
    wire uart_tx;

    wire spi_sclk;
    wire spi_cs;
    wire spi_mosi;
    wire spi_miso;

    wire [7:0] spi_rx_data;
    wire spi_rx_done;

    integer checks;
    integer errors;
    integer uart_seen;
    integer spi_seen;

    assign uart_rx = uart_tx;

    mini_soc dut (
        .clk(clk),
        .rst(rst),
        .addr(addr),
        .we(we),
        .wdata(wdata),
        .rdata(rdata),
        .gpio_in(gpio_in),
        .gpio_out(gpio_out),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .spi_miso(spi_miso),
        .spi_sclk(spi_sclk),
        .spi_cs(spi_cs),
        .spi_mosi(spi_mosi)
    );

    spi_slave_model spi_slave (
        .rst(rst),
        .cs(spi_cs),
        .sclk(spi_sclk),
        .mosi(spi_mosi),
        .miso(spi_miso),
        .rx_data(spi_rx_data),
        .rx_done(spi_rx_done)
    );

    always #5 clk = ~clk;

    task write_reg;
        input [15:0] address;
        input [31:0] value;
        begin
            @(negedge clk);
            addr = address;
            wdata = value;
            we = 1;
            @(negedge clk);
            we = 0;
        end
    endtask

    task read_check;
        input [15:0] address;
        input [31:0] expected;
        input [255:0] label_text;
        begin
            @(negedge clk);
            addr = address;
            we = 0;
            #1;
            checks = checks + 1;
            if (rdata === expected) begin
                $display("PASS: %0s", label_text);
            end else begin
                errors = errors + 1;
                $display("FAIL: %0s Expected=%h Actual=%h",
                         label_text, expected, rdata);
            end
        end
    endtask

    initial begin
        clk = 0;
        rst = 1;
        addr = 0;
        we = 0;
        wdata = 0;
        gpio_in = 0;
        checks = 0;
        errors = 0;
        uart_seen = 0;
        spi_seen = 0;

        $display("========================================");
        $display("       MINI SOC FULL VERIFICATION");
        $display("========================================");

        repeat (5) @(negedge clk);
        rst = 0;

        $display("\n========== RAM TEST ==========");
        write_reg(16'h0000, 32'h12345678);
        write_reg(16'h0004, 32'hAABBCCDD);
        read_check(16'h0000, 32'h12345678, "RAM first word");
        read_check(16'h0004, 32'hAABBCCDD, "RAM second word");

        $display("\n========== GPIO TEST ==========");
        write_reg(16'h1000, 32'h000000A5);
        read_check(16'h1000, 32'h000000A5, "GPIO output register");

        gpio_in = 32'h0000005A;
        repeat (2) @(negedge clk);
        read_check(16'h1004, 32'h0000005A, "GPIO input register");

        $display("\n========== TIMER TEST ==========");
        write_reg(16'h2008, 32'd5);
        read_check(16'h2008, 32'd5, "Timer period register");

        write_reg(16'h2000, 32'd1);
        read_check(16'h2000, 32'd1, "Timer enabled");

        repeat (3) @(negedge clk);
        addr = 16'h2004;
        #1;
        checks = checks + 1;
        if (rdata > 0 && rdata <= 5)
            $display("PASS: Timer counter is operating");
        else begin
            errors = errors + 1;
            $display("FAIL: Timer counter value=%d", rdata);
        end

        $display("\n========== UART TEST ==========");
        write_reg(16'h3008, 32'd8);
        read_check(16'h3008, 32'd8, "UART divider register");

        write_reg(16'h3000, 32'h41);

        repeat (150) begin
            @(negedge clk);
            if (dut.uart_unit.rx_ready)
                uart_seen = 1;
        end

        checks = checks + 1;
        if (uart_seen) begin
            $display("PASS: UART loopback reception completed");
            read_check(16'h3000, 32'h41, "UART received ASCII A");
        end else begin
            errors = errors + 1;
            $display("FAIL: UART loopback reception timed out");
        end

        $display("\n========== SPI TEST ==========");
        write_reg(16'h400C, 32'd2);
        read_check(16'h400C, 32'd2, "SPI divider register");

        write_reg(16'h4000, 32'hA5);
        write_reg(16'h4008, 32'd1);

        repeat (120) begin
            @(negedge clk);
            if (dut.spi_unit.done)
                spi_seen = 1;
        end

        checks = checks + 1;
        if (spi_seen)
            $display("PASS: SPI transfer completed");
        else begin
            errors = errors + 1;
            $display("FAIL: SPI transfer timed out");
        end

        if (spi_seen) begin
            read_check(16'h4000, 32'h3C, "SPI master received 3C");

            checks = checks + 1;
            if (spi_rx_data === 8'hA5)
                $display("PASS: SPI slave received A5");
            else begin
                errors = errors + 1;
                $display("FAIL: SPI slave received %h", spi_rx_data);
            end
        end

        $display("\n========== ADDRESS DECODER TEST ==========");
        read_check(16'h5000, 32'd0, "Invalid address returns zero");

        $display("\n========================================");
        if (errors == 0)
            $display("MINI SOC: ALL TESTS PASSED");
        else
            $display("MINI SOC: %0d TESTS FAILED", errors);

        $display("Checks: %0d  Errors: %0d", checks, errors);
        $display("========================================");

        $finish;
    end
endmodule
