`timescale 1ns/1ps
module timer_tb;
reg clk=0;
reg rst=1;
reg sel=0;
reg [11:0] offset=0;
reg we=0;
reg [31:0] wdata=0;
wire [31:0] rdata;
integer checks=0;
integer errors=0;
reg [31:0] count_value;
reg [31:0] stopped_value;

always #5 clk=~clk;

timer dut(.clk(clk),.rst(rst),.sel(sel),.offset(offset),.we(we),.wdata(wdata),.rdata(rdata));

task write_reg;
input [11:0] addr;
input [31:0] value;
begin
@(negedge clk);
sel=1; we=1; offset=addr; wdata=value;
@(negedge clk);
we=0;
end
endtask

task read_reg;
input [11:0] addr;
begin
@(negedge clk);
sel=1; we=0; offset=addr;
#1;
end
endtask

initial begin
$display("========== TIMER TEST ==========");
repeat(2) @(negedge clk);
rst=0;
write_reg(12'h008,32'd5);
read_reg(12'h008);
checks=checks+1;
if(rdata==5) $display("PASS: Timer period register");
else begin errors=errors+1; $display("FAIL: Timer period register"); end
write_reg(12'h000,32'd1);
repeat(3) @(negedge clk);
read_reg(12'h004);
count_value=rdata;
checks=checks+1;
if(count_value>0 && count_value<5) $display("PASS: Timer counter increments within period");
else begin errors=errors+1; $display("FAIL: Timer counter value %0d",count_value); end
write_reg(12'h000,32'd0);
read_reg(12'h004);
stopped_value=rdata;
repeat(3) @(negedge clk);
read_reg(12'h004);
checks=checks+1;
if(rdata==stopped_value) $display("PASS: Timer stops when disabled");
else begin errors=errors+1; $display("FAIL: Timer changed while disabled"); end
$display("TIMER CHECKS: %0d  ERRORS: %0d",checks,errors);
if(errors==0) $display("TIMER TEST: ALL PASSED");
else $display("TIMER TEST: FAILED");
$finish;
end
endmodule
