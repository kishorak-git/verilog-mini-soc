`timescale 1ns/1ps
module negative_control_tb;
initial begin
    $display("NEGATIVE CONTROL: EXPECTED FAILURE");
    $display("FAIL: deliberately generated negative-control failure");
    $finish(1);
end
endmodule
