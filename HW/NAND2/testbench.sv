module nand2_tb;
  reg[1:0] in_value;
  wire out;

  nand2 nand2_instance(out, in_value[1], in_value[0]);

  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(1);

    $monitor("%0t\tin:%b, out:%b", $time, in_value, out);

    for (in_value = 0; in_value < 3; in_value++) #(in_value+1);
    //#1 in_value = 2'b00;
    //#2 in_value = 2'b01;
    //#3 in_value = 2'b10;
    //#4 in_value = 2'b11;
  end
endmodule
