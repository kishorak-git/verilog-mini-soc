`timescale 1ns/1ps
module spi_slave_model(
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
if(rst) begin
rx_shift<=0;
rx_data<=0;
rx_count<=0;
rx_done<=0;
end
else if(cs) begin
rx_shift<=0;
rx_count<=0;
end
else if(rx_count<8) begin
rx_shift<={rx_shift[6:0],mosi};
if(rx_count==7) begin
rx_data<={rx_shift[6:0],mosi};
rx_count<=8;
rx_done<=1;
end
else rx_count<=rx_count+1'b1;
end
end

always @(negedge cs or negedge sclk or posedge cs or posedge rst) begin
if(rst || cs) begin
miso<=1;
tx_count<=0;
end
else begin
if(tx_count==0) begin
miso<=tx_data[7];
tx_count<=1;
end
else if(tx_count<8) begin
miso<=tx_data[7-tx_count];
tx_count<=tx_count+1'b1;
end
end
end

initial begin
tx_data=8'h3C;
rx_data=0;
rx_done=0;
rx_shift=0;
rx_count=0;
tx_count=0;
miso=1;
end
endmodule

module spi_tb;
reg clk=0;
reg rst=1;
reg sel=0;
reg [11:0] offset=0;
reg we=0;
reg re=0;
reg [31:0] wdata=0;
wire sclk;
wire cs;
wire mosi;
wire miso;
wire [31:0] rdata;
wire [7:0] slave_rx;
wire slave_done;
integer checks=0;
integer errors=0;

always #5 clk=~clk;

spi_bus dut(.clk(clk),.rst(rst),.sel(sel),.offset(offset),.we(we),.re(re),.wdata(wdata),.miso(miso),.sclk(sclk),.cs(cs),.mosi(mosi),.rdata(rdata));
spi_slave_model slave(.rst(rst),.cs(cs),.sclk(sclk),.mosi(mosi),.miso(miso),.rx_data(slave_rx),.rx_done(slave_done));

task write_reg;
input [11:0] addr;
input [31:0] value;
begin
@(negedge clk);
sel=1; we=1; offset=addr; wdata=value;
re=0;
@(negedge clk);
we=0;
end
endtask

task read_reg;
input [11:0] addr;
begin
@(negedge clk);
sel=1; we=0; offset=addr;
re=1;
#1;
@(negedge clk);
re=0;
end
endtask

initial begin
$dumpfile("simulation/waves/spi_tb.vcd");
$dumpvars(0, spi_tb);
$display("========== SPI TEST ==========");
repeat(3) @(negedge clk);
rst=0;
write_reg(12'h00C,32'd2);
read_reg(12'h00C);
checks=checks+1;
if(rdata==2) $display("PASS: SPI divider register");
else begin errors=errors+1; $display("FAIL: SPI divider register, got %0d",rdata); end
write_reg(12'h000,32'h000000A5);
write_reg(12'h008,32'd1);
repeat(180) @(negedge clk);
read_reg(12'h00C);
@(negedge clk);
sel=1; re=1; we=0; offset=12'h004;
#1;
checks=checks+1;
if(rdata[1] && !rdata[0]) $display("PASS: SPI transfer completed");
else begin errors=errors+1; $display("FAIL: SPI status register %08h",rdata); end
@(negedge clk);
re=0;
read_reg(12'h004);
checks=checks+1;
if(!rdata[1] && !rdata[0]) $display("PASS: SPI done clears after status read");
else begin errors=errors+1; $display("FAIL: SPI status remained set after status read, status=%08h",rdata); end
write_reg(12'h000,32'h000000A5);
write_reg(12'h008,32'd1);
repeat(180) @(negedge clk);
@(negedge clk);
sel=1; re=1; we=0; offset=12'h004;
#1;
checks=checks+1;
if(rdata[1] && !rdata[0]) $display("PASS: SPI new transfer done asserted");
else begin errors=errors+1; $display("FAIL: SPI new transfer status=%08h",rdata); end
@(negedge clk);
re=0;
read_reg(12'h004);
checks=checks+1;
if(!rdata[1]) $display("PASS: SPI consecutive same-register status read clears done");
else begin errors=errors+1; $display("FAIL: SPI consecutive status read did not clear done"); end
read_reg(12'h000);
checks=checks+1;
if(rdata[7:0]==8'h3C) $display("PASS: SPI master received 3C");
else begin errors=errors+1; $display("FAIL: SPI master expected 3C got %02h",rdata[7:0]); end
checks=checks+1;
if(slave_done && slave_rx==8'hA5) $display("PASS: SPI slave received A5");
else begin errors=errors+1; $display("FAIL: SPI slave received %02h done=%b",slave_rx,slave_done); end
$display("SPI CHECKS: %0d  ERRORS: %0d",checks,errors);
if(errors==0) $display("SPI TEST: ALL PASSED");
else $display("SPI TEST: FAILED");
$finish;
end
endmodule
