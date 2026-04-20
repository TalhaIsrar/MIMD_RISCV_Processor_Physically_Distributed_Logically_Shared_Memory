#define __MAIN_C__

#include <stdint.h>
#include <stdbool.h>

// Define the raw base address values for the i/o devices
#define OUT_BASE        0x30000000
#define DMA_BASE        0x20000000
#define RAM2_BASE       0x10000000
#define RAM1_BASE       0x00000000

// Define pointers with correct type for access to 32/16-bit i/o devices
volatile uint32_t* DMA_REGS = (volatile uint32_t*) DMA_BASE;
volatile uint32_t* RAM1_REGS = (volatile uint32_t*) RAM1_BASE;
volatile uint32_t* RAM2_REGS = (volatile uint32_t*) RAM2_BASE;
volatile uint16_t* OUT_REGS = (volatile uint16_t*) OUT_BASE;

// Functions provided to access i/o devices
void write_out(uint16_t value) {
  OUT_REGS[1] = 1;
  OUT_REGS[0] = value;
}

void set_out_invalid(void) {
  OUT_REGS[1] = 0;
  OUT_REGS[0] = 0;
}

uint16_t read_out(void) {
  return OUT_REGS[0];
}

// Main Function

int main(void) {
  write_out( 0xBEEF );
  write_out( read_out());
  write_out( read_out() >> 1 );

  // Fill raw data into RAM2
  for (int i = 0; i < 10 ; i++){
    RAM2_REGS[i+1024] = i;
  };

  write_out( 0x1111 );

  // Read data from RAM2
  for (int i = 0; i < 10 ; i++){
    write_out(RAM2_REGS[i+1024]);
  };  

  write_out( 0x2222 );

  // Read data from RAM2
  for (int i = 0; i < 10 ; i++){
    write_out(RAM2_REGS[i]);
  };  

  write_out( 0x3333 );

  // Copy Raw data from RAM2 to RAM2 using DMA
  DMA_REGS[0] = RAM2_BASE + 1024*4;
  DMA_REGS[1] = RAM2_BASE;
  DMA_REGS[2] = 0xA;
  DMA_REGS[3] = 0x1;
 
  // Wait until DMA sets done bit (bit 1)
  while (!(DMA_REGS[3] & 0x2));

  write_out( 0x4444 );

  // Read data from RAM2
  for (int i = 0; i < 10 ; i++){
    write_out(RAM2_REGS[i]);
  };   

  write_out( 0x5555 );

  // repeat forever (embedded programs generally do not terminate)
  while(1){
    
  }

}
