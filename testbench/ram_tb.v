`timescale 1ns/1ps
module ram_tb;
reg clk=0;
reg sel=0;
reg [11:0] offset=0;
reg we=0;
reg [31:0] wdata=0;
wire [31:0] rdata;
integer checks=0;
integer errors=0;

always #5 clk=~clk;

ram dut(.clk(clk),.sel(sel),.offset(offset),.we(we),.wdata(wdata),.rdata(rdata));

task write_word;
input [11:0] addr;
input [31:0] value;
begin
@(negedge clk);
sel=1; we=1; offset=addr; wdata=value;
@(negedge clk);
we=0;
end
endtask

task check_word;
input [11:0] addr;
input [31:0] expected;
begin
@(negedge clk);
sel=1; we=0; offset=addr;
#1;
checks=checks+1;
if(rdata===expected) $display("PASS: RAM address %03h = %08h",addr,rdata);
else begin errors=errors+1; $display("FAIL: RAM address %03h expected %08h got %08h",addr,expected,rdata); end
end
endtask

initial begin
$display("========== RAM TEST ==========");
write_word(12'h000,32'h12345678);
write_word(12'h004,32'hA5A55A5A);
write_word(12'hFFC,32'hDEADBEEF);
check_word(12'h000,32'h12345678);
check_word(12'h004,32'hA5A55A5A);
check_word(12'hFFC,32'hDEADBEEF);
sel=0; #1;
checks=checks+1;
if(rdata===32'h00000000) $display("PASS: RAM deselected output");
else begin errors=errors+1; $display("FAIL: RAM deselected output"); end
$display("RAM CHECKS: %0d  ERRORS: %0d",checks,errors);
if(errors==0) $display("RAM TEST: ALL PASSED");
else $display("RAM TEST: FAILED");
$finish;
end
endmodule
