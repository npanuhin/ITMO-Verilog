module MemCTR (
  input CLK,
  inout[ADDR2_BUS_SIZE-1:0] A2_WIRE,
  inout[DATA_BUS_SIZE-1:0] D2_WIRE,
  inout[CTR2_BUS_SIZE-1 :0] C2_WIRE,
  input RESET,
  input M_DUMP
);
  `map_bus2;  // Initialize wires

  reg[7:0] ram [MEM_SIZE];
  reg[CACHE_ADDR_SIZE-1:0] address;

  bit listening_bus2 = 1;

  // Initialization & RESET
  task intialize_ram;
    for (int i = 0; i < MEM_SIZE; ++i) ram[i] = $random(SEED) >> 16;
  endtask
  always @(RESET) intialize_ram();
  initial begin
    intialize_ram();
    // $display("RAM:");
    // for (memory_pointer = 0; memory_pointer < 100; memory_pointer += 1)
    //   $display("[%2d] %d", memory_pointer, ram[memory_pointer]);
    // $display();
  end

  // Dumping
  always @(posedge M_DUMP)
    for (int i = 0; i < 100; ++i)  // 100 for testing, should be MEM_SIZE
      $display("Byte %2d: %d = %b", i, ram[i], ram[i]);

  // --------------------------------------------------- Main logic ----------------------------------------------------
  task send_bytes_D2(input [7:0] byte1, input [7:0] byte2);
    // `log; $display("MemCTR: Sending byte: %d = %b", byte1, byte1);
    // `log; $display("MemCTR: Sending byte: %d = %b", byte2, byte2);
    D2[15:8] = byte2; D2[7:0] = byte1;
  endtask
  task receive_bytes_D2(output [7:0] byte1, output [7:0] byte2);
    byte2 = D2_WIRE[15:8]; byte1 = D2_WIRE[7:0];
  endtask

  task parse_A2;
    address = A2_WIRE << CACHE_OFFSET_SIZE;
  endtask

  always @(posedge CLK) begin
    if (listening_bus2) case (C2_WIRE)
      // C2_NOP: begin `log; $display("MemCTR: C2_NOP"); end

      C2_READ_LINE: begin
        // `log; $display("MemCTR: C2_READ_LINE, A2 = %b", A2_WIRE);
        listening_bus2 = 0; parse_A2();
        #1 C2 = C2_NOP;

        #(MEM_CTR_DELAY - 3);

        #1 C2 = C2_RESPONSE;
        // `log; $display("MemCTR: Sending C2_RESPONSE");
        for (int bytes_start = 0; bytes_start < CACHE_LINE_SIZE; bytes_start += 2) begin
          send_bytes_D2(ram[address], ram[address + 1]);
          // `log; $display("MemCTR: Sent byte %d = %b from ram[%b]", ram[address], ram[address], address);
          ++address;
          // `log; $display("MemCTR: Sent byte %d = %b from ram[%b]", ram[address], ram[address], address);
          ++address;
          if (bytes_start + 2 < CACHE_LINE_SIZE) #2;  // Ждать надо везде, кроме последней передачи данных
        end
        #2 `close_bus2; listening_bus2 = 1;
      end

      C2_WRITE_LINE: begin
        // `log; $display("MemCTR: C2_WRITE_LINE, A2 = %b", A2_WIRE);
        listening_bus2 = 0; parse_A2();
        fork
          #(MEM_CTR_DELAY - 2);  // С одной стороны ждём MEM_CTR_DELAY тактов до отправки C2_RESPONSE, а с другой параллельно читаем и пишем данные
          begin
            for (int bytes_start = 0; bytes_start < CACHE_LINE_SIZE; bytes_start += 2) begin
              receive_bytes_D2(ram[address], ram[address + 1]);
              // `log; $display("MemCTR: Wrote byte %d = %b to ram[%b]", ram[address], ram[address], address);
              ++address;
              // `log; $display("MemCTR: Wrote byte %d = %b to ram[%b]", ram[address], ram[address], address);
              ++address;
              if (bytes_start + 2 < CACHE_LINE_SIZE) #2;  // Ждать надо везде, кроме последней передачи данных
            end

            C2 = C2_NOP;
          end
        join

        #1 C2 = C2_RESPONSE;
        // `log; $display("MemCTR: Sending C2_RESPONSE");
        #2 `close_bus2; listening_bus2 = 1;
      end
    endcase
  end
endmodule
