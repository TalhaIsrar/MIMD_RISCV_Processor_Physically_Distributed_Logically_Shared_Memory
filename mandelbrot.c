#include <stdint.h>

#define WIDTH 320
#define HEIGHT 240
#define MAX_ITER 1000

typedef int32_t fixed; // Q16.16 format

#define FIXED_SHIFT 16
#define TO_FIXED(x) ((fixed)((x) * (1 << FIXED_SHIFT)))
#define FIXED_MUL(a,b) ((fixed)(((int64_t)(a) * (b)) >> FIXED_SHIFT))
#define FIXED_DIV(a,b) ((fixed)(((int64_t)(a) << FIXED_SHIFT) / (b)))

// UART output routines
void uart_putc(char c)
{
    volatile char *uart_tx = (char *)0xFFFF0000;
    *uart_tx = c;
}

void uart_puts(const char *str)
{
    while (*str)
        uart_putc(*str++);
}

// Send iteration as number + newline
void uart_put_iter(uint16_t iter)
{
    char buf[6]; // max 5 digits + null
    int i = 5;
    buf[i--] = 0;
    if (iter == 0)
    {
        buf[i] = '0';
        uart_puts(&buf[i]);
        uart_putc('\n');
        return;
    }
    while (iter && i >= 0)
    {
        buf[i--] = '0' + (iter % 10);
        iter /= 10;
    }
    uart_puts(&buf[i+1]);
    uart_putc('\n');
}

// Map pixel coordinate to complex plane
void pixel_to_complex(int x, int y, fixed *cre, fixed *cim)
{
    *cre = TO_FIXED(-2.0) + FIXED_DIV(TO_FIXED(3.0) * x, TO_FIXED(WIDTH));
    *cim = TO_FIXED(-1.0) + FIXED_DIV(TO_FIXED(2.0) * y, TO_FIXED(HEIGHT));
}

int main(void)
{
    for (int y = 0; y < HEIGHT; y++)
    {
        for (int x = 0; x < WIDTH; x++)
        {
            fixed cre, cim;
            pixel_to_complex(x, y, &cre, &cim);

            fixed zre = 0, zim = 0;
            int iter = 0;

            while (iter < MAX_ITER)
            {
                fixed zre2 = FIXED_MUL(zre, zre);
                fixed zim2 = FIXED_MUL(zim, zim);

                if ((zre2 + zim2) > TO_FIXED(4.0))
                    break;

                fixed temp = zre;
                zre = zre2 - zim2 + cre;
                zim = FIXED_MUL(TO_FIXED(2), FIXED_MUL(temp, zim)) + cim;

                iter++;
            }

            uart_put_iter(iter); // Send iteration count over UART
        }
    }
    return 0;
}