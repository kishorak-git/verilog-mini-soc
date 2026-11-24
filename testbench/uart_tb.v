`timescale 1ns/1ps
module uart_tb;
reg clk=0;
reg rst=1;
reg sel=0;
reg [11:0] offset=0;
reg we=0;
reg re=0;
reg [31:0] wdata=0;
reg ext_rx=1;
reg loopback_mode=1;
wire tx;
wire rxtx;
wire [31:0] rdata;
integer checks=0;
integer errors=0;
integer i=0;
integer seed=32'h13579BDF;
integer random_byte=0;

always #5 clk=~clk;
assign rxtx = loopback_mode ? tx : ext_rx;

uart_bus dut(.clk(clk),.rst(rst),.sel(sel),.offset(offset),.we(we),.re(re),.wdata(wdata),.rx(rxtx),.tx(tx),.rdata(rdata));

task write_reg;
input [11:0] addr;
input [31:0] value;
begin
@(negedge clk);
sel=1; re=0; we=1; offset=addr; wdata=value;
@(negedge clk);
we=0;
end
endtask

task read_reg;
input [11:0] addr;
begin
@(negedge clk);
sel=1; we=0; re=1; offset=addr;
#1;
@(negedge clk);
re=0;
end
endtask

task wait_ready;
begin
i=0;
while(i<1000) begin
@(negedge clk);
sel=1; re=0; we=0; offset=12'h004;
#1;
if(rdata[2]) i=1000;
else if(dut.rx_ready_latched) i=1000;
else i=i+1;
end
end
endtask

task send_external_byte;
input [7:0] value;
integer bit_index;
begin
@(negedge clk);
ext_rx=0;
repeat(4) @(negedge clk);
for(bit_index=0; bit_index<8; bit_index=bit_index+1) begin
ext_rx=value[bit_index];
repeat(4) @(negedge clk);
end
ext_rx=1;
repeat(4) @(negedge clk);
end
endtask

task send_bad_stop;
input [7:0] value;
integer bit_index;
begin
@(negedge clk);
ext_rx=0;
repeat(4) @(negedge clk);
for(bit_index=0; bit_index<8; bit_index=bit_index+1) begin
ext_rx=value[bit_index];
repeat(4) @(negedge clk);
end
ext_rx=0;
repeat(4) @(negedge clk);
ext_rx=1;
repeat(4) @(negedge clk);
end
endtask

initial begin
$dumpfile("simulation/waves/uart_tb.vcd");
$dumpvars(0, uart_tb);
$display("========== UART TEST ==========");
repeat(3) @(negedge clk);
rst=0;

write_reg(12'h008,32'd4);
read_reg(12'h008);
checks=checks+1;
if(rdata==4) $display("PASS: UART baud divider register");
else begin errors=errors+1; $display("FAIL: UART baud divider register, got %0d",rdata); end

loopback_mode=1;
write_reg(12'h000,32'h00000041);
wait_ready();
@(negedge clk);
sel=1; re=1; we=0; offset=12'h004;
#1;
checks=checks+1;
if(rdata[2]) $display("PASS: UART loopback reception ready");
else begin errors=errors+1; $display("FAIL: UART loopback receive-ready not set, status=%08h",rdata); end
@(negedge clk);
re=0;
read_reg(12'h004);
checks=checks+1;
if(!rdata[2]) $display("PASS: UART receive-ready clears after status read");
else begin errors=errors+1; $display("FAIL: UART receive-ready remained set, status=%08h",rdata); end
read_reg(12'h000);
checks=checks+1;
if(rdata[7:0]==8'h41) $display("PASS: UART loopback received ASCII A");
else begin errors=errors+1; $display("FAIL: UART loopback expected 41 got %02h",rdata[7:0]); end

write_reg(12'h000,32'h00000042);
wait_ready();
@(negedge clk);
sel=1; re=1; we=0; offset=12'h004;
#1;
checks=checks+1;
if(rdata[2]) $display("PASS: UART first consecutive status read sees ready");
else begin errors=errors+1; $display("FAIL: UART first status read missed ready"); end
@(negedge clk);
re=0;

write_reg(12'h000,32'h00000043);
wait_ready();
@(negedge clk);
sel=1; re=1; we=0; offset=12'h004;
#1;
checks=checks+1;
if(rdata[2]) $display("PASS: UART same-register consecutive read sees new ready");
else begin errors=errors+1; $display("FAIL: UART consecutive same-register ready failed"); end
@(negedge clk);
re=0;

loopback_mode=0;
ext_rx=1;
send_external_byte(8'h00);
wait_ready();
read_reg(12'h000);
checks=checks+1;
if(rdata[7:0]==8'h00) $display("PASS: UART external received 00");
else begin errors=errors+1; $display("FAIL: UART external expected 00 got %02h",rdata[7:0]); end
read_reg(12'h004);

send_external_byte(8'hFF);
wait_ready();
read_reg(12'h000);
checks=checks+1;
if(rdata[7:0]==8'hFF) $display("PASS: UART external received FF");
else begin errors=errors+1; $display("FAIL: UART external expected FF got %02h",rdata[7:0]); end
read_reg(12'h004);

send_external_byte(8'h55);
wait_ready();
read_reg(12'h000);
checks=checks+1;
if(rdata[7:0]==8'h55) $display("PASS: UART external received 55");
else begin errors=errors+1; $display("FAIL: UART external expected 55 got %02h",rdata[7:0]); end
read_reg(12'h004);

send_external_byte(8'hAA);
wait_ready();
read_reg(12'h000);
checks=checks+1;
if(rdata[7:0]==8'hAA) $display("PASS: UART external received AA");
else begin errors=errors+1; $display("FAIL: UART external expected AA got %02h",rdata[7:0]); end
read_reg(12'h004);

send_external_byte(8'h41);
wait_ready();
read_reg(12'h000);
checks=checks+1;
if(rdata[7:0]==8'h41) $display("PASS: UART external received 41");
else begin errors=errors+1; $display("FAIL: UART external expected 41 got %02h",rdata[7:0]); end
read_reg(12'h004);

for(i=0;i<8;i=i+1) begin
seed=(seed*1103515245+12345);
random_byte=seed[7:0];
send_external_byte(random_byte[7:0]);
wait_ready();
read_reg(12'h000);
checks=checks+1;
if(rdata[7:0]==random_byte[7:0]) $display("PASS: UART deterministic random byte %02h",random_byte[7:0]);
else begin errors=errors+1; $display("FAIL: UART deterministic random expected %02h got %02h",random_byte[7:0],rdata[7:0]); end
read_reg(12'h004);
end

send_bad_stop(8'h69);
repeat(300) @(negedge clk);
@(negedge clk);
sel=1; re=1; we=0; offset=12'h004;
#1;
checks=checks+1;
if(rdata[3] && !rdata[2]) $display("PASS: UART bad stop sets framing error without ready");
else begin errors=errors+1; $display("FAIL: UART bad-stop status=%08h",rdata); end
@(negedge clk);
re=0;
read_reg(12'h004);
checks=checks+1;
if(!rdata[3]) $display("PASS: UART framing error clears after status read");
else begin errors=errors+1; $display("FAIL: UART framing error remained set"); end

ext_rx=1;
@(negedge clk); ext_rx=0; #15; ext_rx=1;
repeat(100) @(negedge clk);
read_reg(12'h004);
checks=checks+1;
if(!rdata[2] && !rdata[3]) $display("PASS: UART short glitch generates no ready or framing error");
else begin errors=errors+1; $display("FAIL: UART glitch status=%08h",rdata); end

send_external_byte(8'h5A);
repeat(2) @(negedge clk);
@(negedge clk); ext_rx=0;
repeat(2) @(negedge clk); ext_rx=1;
repeat(300) @(negedge clk);
wait_ready();
read_reg(12'h000);
checks=checks+1;
if(rdata[7:0]==8'h5A) $display("PASS: UART start while busy preserves current byte");
else begin errors=errors+1; $display("FAIL: UART start while busy corrupts byte, got %02h",rdata[7:0]); end
read_reg(12'h004);

$display("UART CHECKS: %0d  ERRORS: %0d",checks,errors);
if(errors==0) $display("UART TEST: ALL PASSED");
else $display("UART TEST: FAILED");
$finish;
end
endmodule
