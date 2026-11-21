module gpio_tb;

    reg clk;
    reg rst;
    reg sel;
    reg [11:0] offset;
    reg we;
    reg [31:0] wdata;
    reg [31:0] pin_in;
    wire [31:0] pin_out;
    wire [31:0] rdata;

    integer checks;
    integer errors;

    gpio dut (
        .clk(clk),
        .rst(rst),
        .sel(sel),
        .offset(offset),
        .we(we),
        .wdata(wdata),
        .pin_in(pin_in),
        .pin_out(pin_out),
        .rdata(rdata)
    );

    always #5 clk = ~clk;

    task check;
        input [31:0] expected;
        input [255:0] label_text;
        begin
            #1;
            checks = checks + 1;
            if (rdata === expected)
                $display("PASS: %0s", label_text);
            else begin
                errors = errors + 1;
                $display("FAIL: %0s Expected=%h Actual=%h",
                         label_text, expected, rdata);
            end
        end
    endtask

    initial begin
        clk = 0;
        rst = 1;
        sel = 0;
        offset = 0;
        we = 0;
        wdata = 0;
        pin_in = 0;
        checks = 0;
        errors = 0;

        repeat (2) @(negedge clk);
        rst = 0;

        sel = 1;
        we = 1;
        offset = 0;
        wdata = 32'hA5;
        @(negedge clk);
        we = 0;
        check(32'hA5, "GPIO output register");

        pin_in = 32'h5A;
        offset = 4;
        @(negedge clk);
        check(32'h5A, "GPIO input register");

        sel = 0;
        offset = 0;
        check(32'd0, "GPIO deselected output");

        $display("-----------------------------");
        $display("GPIO CHECKS: %0d", checks);
        $display("GPIO ERRORS: %0d", errors);

        if (errors == 0)
            $display("GPIO TEST: ALL PASSED");
        else
            $display("GPIO TEST: FAILED");

        $finish;
    end

endmodule
