module MemCTR (
  input wire CLK,
  inout wire[ADDR2_BUS_SIZE-1:0] A2_WIRE,
  inout wire[DATA_BUS_SIZE-1:0] D2_WIRE,
  inout wire[CTR2_BUS_SIZE-1 :0] C2_WIRE,
  input wire RESET,
  input wire M_DUMP
);
  `map_bus2;  // Initialize wires

  reg[7:0] ram [MEM_SIZE];
  reg[CACHE_ADDR_SIZE-1:0] address;

  bit listening_bus2 = 1;

  // Initialization & RESET
  task intialize_ram;
    for (int i = 0; i < 10000; ++i) ram[i] = $random(SEED) >> 16;   // 10000 for testing, should be MEM_SIZE
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
    for (int cur_byte = 0; cur_byte < 100; ++cur_byte)  // 100 for testing, should be MEM_SIZE
      $display("Byte %2d: %d = %b", cur_byte, ram[cur_byte], ram[cur_byte]);

  // --------------------------------------------------- Main logic ----------------------------------------------------
  // Передать данные в little-endian, то есть вначале (слева) идёт второй байт ([15:8]), потом (справа) первый ([7:0])
  // Тогда D = (второй байт, первый байт) -> второй байт = D2[15:8], первый байт = D2[7:0]
  task send_bytes_D2(input [7:0] bbyte1, input [7:0] bbyte2);
    // $display("[%3t | CLK=%0d] MemCTR: Sending byte: %d = %b", $time, $time % 2, bbyte1, bbyte1);
    // $display("[%3t | CLK=%0d] MemCTR: Sending byte: %d = %b", $time, $time % 2, bbyte2, bbyte2);
    D2[15:8] = bbyte2; D2[7:0] = bbyte1;
  endtask
  task receive_bytes_D2(output [7:0] bbyte1, output [7:0] bbyte2);
    bbyte2 = D2_WIRE[15:8]; bbyte1 = D2_WIRE[7:0];
  endtask

  task parse_A2;
    address = A2_WIRE << CACHE_OFFSET_SIZE;
  endtask

  always @(posedge CLK) begin
    if (listening_bus2) case (C2_WIRE)
      C2_NOP: $display("[%3t | CLK=%0d] MemCTR: C2_NOP", $time, $time % 2);

      C2_READ_LINE: begin
        $display("[%3t | CLK=%0d] MemCTR: C2_READ_LINE, A2 = %b", $time, $time % 2, A2_WIRE);
        listening_bus2 = 0; parse_A2();
        #1 C2 = C2_NOP;

        #(MEM_CTR_DELAY - 1);

        C2 = C2_RESPONSE;
        for (int bbytes_start = 0; bbytes_start < CACHE_LINE_SIZE; bbytes_start += 2) begin
          send_bytes_D2(ram[address], ram[address + 1]);
          $display("[%3t | CLK=%0d] MemCTR: Sent byte %d = %b from ram[%b]", $time, $time % 2, ram[address], ram[address], address);
          ++address;
          $display("[%3t | CLK=%0d] MemCTR: Sent byte %d = %b from ram[%b]", $time, $time % 2, ram[address], ram[address], address);
          ++address;
          if (bbytes_start + 2 < CACHE_LINE_SIZE) #2;  // Ждать надо везде, кроме последней передачи данных
        end

        #1 `close_bus2; listening_bus2 = 1;
      end

      C2_WRITE_LINE: begin
        $display("[%3t | CLK=%0d] MemCTR: C2_WRITE_LINE, A2 = %b", $time, $time % 2, A2_WIRE);
        listening_bus2 = 0; parse_A2();
        fork
          #MEM_CTR_DELAY;  // С одной стороны ждём MEM_CTR_DELAY тактов до отправки C2_RESPONSE, а с другой параллельно читаем и пишем данные
          begin
            for (int bbytes_start = 0; bbytes_start < CACHE_LINE_SIZE; bbytes_start += 2) begin
              receive_bytes_D2(ram[address], ram[address + 1]);
              $display("[%3t | CLK=%0d] MemCTR: Wrote byte %d = %b to ram[%b]", $time, $time % 2, ram[address], ram[address], address);
              ++address;
              $display("[%3t | CLK=%0d] MemCTR: Wrote byte %d = %b to ram[%b]", $time, $time % 2, ram[address], ram[address], address);
              ++address;
              if (bbytes_start + 2 < CACHE_LINE_SIZE) #2;  // Ждать надо везде, кроме последней передачи данных
            end

            // Тут (в отличии от кэша) на последнем такте передачи данных шиной всё ещё владеет Cache
            // Владение к MemCTR перейдёт только после CLK -> 0
            #1; C2 = C2_NOP; #1;
          end
        join

        // На последнем такте работы отправляем C2_RESPONSE и, когда CLK -> 0, закрываем соединения
        // $display("[%3t | CLK=%0d] MemCTR: Sending C2_RESPONSE", $time, $time % 2);
        C2 = C2_RESPONSE;
        #1 `close_bus2; listening_bus2 = 1;
      end
    endcase
  end
endmodule
