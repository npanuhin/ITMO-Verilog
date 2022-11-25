typedef enum {
  C1_NOP,
  C1_READ8,
  C1_READ16,
  C1_READ32,
  C1_INVALIDATE_LINE,
  C1_WRITE8,
  C1_WRITE16,
  C1_WRITE32
} C1_COMMANDS;   // CPU -> Cache

typedef enum {
  C1b_NOP,
  C1b_RESPONSE = 7
} C1b_COMMANDS;  // Cache -> CPU (back)

typedef enum {
  C2_NOP,
  C2_READ_LINE = 2,
  C2_WRITE_LINE = 3
} C2_COMMANDS;   // Cache -> Mem

typedef enum {
  C2b_NOP,
  C2b_RESPONSE = 1
} C2b_COMMANDS;  // Cache -> Mem (back)
