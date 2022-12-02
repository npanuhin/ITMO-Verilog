// Tools
`define discard_last_n_bits(register, n) (register >> n)
`define first_n_bits(register, n) `discard_last_n_bits(register, $size(register) - n)
`define last_n_bits(register, n) (register & ((1 << n) - 1))

`define log \
	if (DEBUG_MODE == 1) $write("[%3t | CLK=%0d] ", $time, $time % 2); \  // CLK = $time % 2 representation works much better, more suitable for debugging
	if (DEBUG_MODE == 1)  // $display(...)

// BUSes
`define map_bus1 \
  reg[ADDR1_BUS_SIZE-1:0] A1 = 'z; assign A1_WIRE = A1; \
  reg[DATA_BUS_SIZE-1 :0] D1 = 'z; assign D1_WIRE = D1; \
  reg[CTR1_BUS_SIZE-1 :0] C1 = 'z; assign C1_WIRE = C1;
`define map_bus2 \
  reg[ADDR2_BUS_SIZE-1:0] A2 = 'z; assign A2_WIRE = A2; \
  reg[DATA_BUS_SIZE-1 :0] D2 = 'z; assign D2_WIRE = D2; \
  reg[CTR2_BUS_SIZE-1 :0] C2 = 'z; assign C2_WIRE = C2;
`define close_bus1 C1 = 'z; A1 = 'z; D1 = 'z;
`define close_bus2 C2 = 'z; A2 = 'z; D2 = 'z;

localparam DEBUG_MODE = 0;
