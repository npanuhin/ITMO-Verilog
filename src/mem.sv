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

  int accum_delay;

  bit listening_bus2 = 1;

  // Initialization & RESET
  task intialize_ram();
    // for (int i = 0; i < MEM_SIZE; ++i) ram[i] = $random(SEED) >> 16;
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
        accum_delay = 0;

        // Делаем операцию, обратную той, что описана в cache.sv
        for (int bbytes_start = 0; bbytes_start < CACHE_LINE_SIZE; bbytes_start += DATA2_BUS_SIZE_BYTES) begin
          for (int bbyte = 0; bbyte < DATA2_BUS_SIZE_BYTES; ++bbyte) begin
            for (int i = 0; i < 8; ++i) ram[address][i] = D2_WIRE[bbyte * 8 + i];
            $display("Wrote byte %d = %b to ram[%b]", ram[address], ram[address], address);
            ++address;
          end
          if (bbytes_start + DATA2_BUS_SIZE_BYTES < CACHE_LINE_SIZE) begin  // Ждать надо везде, кроме последней передачи данных
            #2; accum_delay += 2;
          end
        end

        // Чтение окончено, приступаем к выполнению (запись в память параллельно уже была, так что больше нечего выполнять, ну и ладно):
        if (MEM_CTR_DELAY * 2 - accum_delay > 1) begin
          #1 C2 = C2_NOP; --accum_delay;
        end

        #(MEM_CTR_DELAY * 2 - accum_delay);

        // На последнем такте работы отправляем C2_RESPONSE и когда CLK -> 0, закрываем соединения
        C2 = C2_RESPONSE;
        #1 `close_bus2; listening_bus2 = 1;
      end
    endcase
  end
endmodule
