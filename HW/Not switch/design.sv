module not_switch(output wire out, input wire in);

  supply1 power;
  supply0 ground;

  pmos p1(out, power, in);
  nmos n1(out, ground, in);
endmodule
