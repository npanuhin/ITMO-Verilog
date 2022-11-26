module not_tb;
  reg in_value;
  reg[3:0] t_value;
  wire out;

  not_switch not_instance(.out(out), .in(in_value));
  //not_switch not_instance1(.out(out), .in(out)); // короткое замыкание

  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(1);

    $monitor("in:%b, out:%b, time: %d", in_value, out, t_value);

    in_value = 0;
    t_value = 0;

    #1 t_value += 1;

    #2 t_value += 1;

    #3 t_value += 1;
    #3 in_value = 1;

    #4 t_value += 1;
    #4 in_value = 0;
  end
endmodule
