`timescale 1ns/1ps
module uart_tb;
reg clk=0;
reg rst=1;
reg sel=0;
reg [11:0] offset=0;
reg we=0;
reg [31:0] wdata=0;
wire tx;
wire [31:0] rdata;
wire rx;
integer checks=0;
integer errors=0;

always #5 clk=~clk;
assign rx=tx;

uart_bus dut(.clk(clk),.rst(rst),.sel(sel),.offset(offset),.we(we),.wdata(wdata),.rx(rx),.tx(tx),.rdata(rdata));

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
$display("========== UART TEST ==========");
repeat(3) @(negedge clk);
rst=0;
write_reg(12'h008,32'd4);
read_reg(12'h008);
checks=checks+1;
if(rdata==4) $display("PASS: UART baud divider register");
else begin errors=errors+1; $display("FAIL: UART baud divider register, got %0d",rdata); end
write_reg(12'h000,32'h00000041);
repeat(160) @(negedge clk);
read_reg(12'h008);
read_reg(12'h004);
checks=checks+1;
if(rdata[2]) $display("PASS: UART loopback reception ready");
else begin errors=errors+1; $display("FAIL: UART receive-ready flag not set, status=%08h",rdata); end
checks=checks+1;
if(rdata[1]) $display("PASS: UART transmit done");
else begin errors=errors+1; $display("FAIL: UART transmit done flag not set, status=%08h",rdata); end
read_reg(12'h004);
checks=checks+1;
if(!rdata[2] && !rdata[1]) $display("PASS: UART receive-ready and transmit-done clear after status read");
else begin errors=errors+1; $display("FAIL: UART completion status remained set after status read, status=%08h",rdata); end
read_reg(12'h000);
checks=checks+1;
if(rdata[7:0]==8'h41) $display("PASS: UART received ASCII A");
else begin errors=errors+1; $display("FAIL: UART data expected 41 got %02h",rdata[7:0]); end
$display("UART CHECKS: %0d  ERRORS: %0d",checks,errors);
if(errors==0) $display("UART TEST: ALL PASSED");
else $display("UART TEST: FAILED");
$finish;
end
endmodule
