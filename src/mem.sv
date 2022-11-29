module MemCTR (
  input wire CLK,
  inout wire[ADDR2_BUS_SIZE-1:0] A2_WIRE,
  inout wire[DATA2_BUS_SIZE-1:0] D2_WIRE,
  inout wire[CTR2_BUS_SIZE-1 :0] C2_WIRE,
  input wire RESET,
  input wire M_DUMP
);
  `map_bus2; // Initialize wires

  reg[7:0] ram [MEM_SIZE];
  reg[CACHE_ADDR_SIZE-1:0] address;

  bit listening_bus2 = 1;

  // Initialization & RESET
  task intialize_ram();
    for (int i = 0; i < 10000; ++i) ram[i] = $random(SEED) >> 16;   // 10000 for testing, should be MEM_SIZE
  endtask
  always @(RESET) intialize_ram();
  initial begin
    intialize_ram();
    // $display("RAM:");
    // for (memory_pointer = 0; memory_pointer < 100; memory_pointer += 1) begin
    //   $display("[%2d] %d", memory_pointer, ram[memory_pointer]);
    // end
    // $display();
  end

  // Dumping
  always @(posedge M_DUMP)
    for (int cur_byte = 0; cur_byte < 100; ++cur_byte)  // 100 for testing, should be MEM_SIZE
      $display("Byte %2d: %d = %b", cur_byte, ram[cur_byte], ram[cur_byte]);

  // Main logic
  always @(posedge CLK) begin
    if (listening_bus2) case (C2_WIRE)
      C2_NOP: $display("[%3t | CLK=%0d] MemCTR: C2_NOP", $time, $time % 2);

      C2_READ_LINE: begin
        $display("[%3t | CLK=%0d] MemCTR: C2_READ_LINE", $time, $time % 2);
        // listening_bus2 = 0;
        // TODO
      end

      C2_WRITE_LINE: begin
        $display("[%3t | CLK=%0d] MemCTR: C2_WRITE_LINE, A2 = %b", $time, $time % 2, A2_WIRE);
        listening_bus2 = 0;
        address = A2_WIRE << CACHE_OFFSET_SIZE;
        fork
          #(MEM_CTR_DELAY * 2); // С одной стороны ждём MEM_CTR_DELAY тактов до отправки C2_RESPONSE, а с другой параллено читаем и пишем данные
          begin
            // Делаем операцию, обратную той, что описана в cache.sv
            for (int bbytes_start = 0; bbytes_start < CACHE_LINE_SIZE; bbytes_start += DATA2_BUS_SIZE_BYTES) begin
              for (int bbyte = 0; bbyte < DATA2_BUS_SIZE_BYTES; ++bbyte) begin
                for (int i = 0; i < 8; ++i) ram[address][i] = D2_WIRE[bbyte * 8 + i];
                $display("[%3t | CLK=%0d] Wrote byte %d = %b to ram[%b]", $time, $time % 2, ram[address], ram[address], address);
                ++address;
              end
              if (bbytes_start + DATA2_BUS_SIZE_BYTES < CACHE_LINE_SIZE) begin  // Ждать надо везде, кроме последней передачи данных
                #2;
              end
            end

            // Чтение окончено, отправляем результат:

            // Тут (в отличии от кэша) на последнем такте передачи данных шиной всё ещё владеет Cache
            // Владение к MemCTR перейдёт только после CLK -> 0
            #1; C2 = C2_NOP; #1; // Чтобы дальнейшие дествия были не на CLK -> 0, а на CLK -> 1, надо подождать ещё 1 такт
          end
        join

        // На последнем такте работы отправляем C2_RESPONSE и, когда CLK -> 0, закрываем соединения
        $display("[%3t | CLK=%0d] sending C2_RESPONSE", $time, $time % 2);
        C2 = C2_RESPONSE;
        #1 `close_bus2; listening_bus2 = 1;
      end
    endcase
  end
endmodule
