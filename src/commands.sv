typedef enum {
  C1_NOP,
  C1_READ8,
  C1_READ16,
  C1_READ32,
  C1_INVALIDATE_LINE,
  C1_WRITE8,
  C1_WRITE16,
  C1_WRITE32
} C1_COMMANDS;   // CPU <-> Cache (BUS 1)
localparam C1_RESPONSE = 7;

typedef enum {
  C2_NOP,
  C2_RESPONSE,
  C2_READ_LINE,
  C2_WRITE_LINE
} C2_COMMANDS;   // Cache <-> Mem (BUS 2)
