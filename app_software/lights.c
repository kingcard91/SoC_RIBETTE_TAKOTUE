#include <stdio.h>
#include <unistd.h>
#include "system.h"
#include "io.h"
#include "alt_types.h"

#define PWM_BASE PWM_AVALON_INTERFACE_0_BASE

#define PWM_RIGHT_OFFSET  0
#define PWM_LEFT_OFFSET   2

#define GO        0x3800
#define BACKWARD  0x1000
#define FORWARD   0x0000

#define PWM_MAX   3125

static alt_u16 motor_cmd(int go, int backward, alt_u16 speed)
{
    if (speed > PWM_MAX)
        speed = PWM_MAX;

    return (go ? GO : 0) |
           (backward ? BACKWARD : FORWARD) |
           (speed & 0x0FFF);
}

static void pwm_write(alt_u16 right, alt_u16 left)
{
    IOWR_16DIRECT(PWM_BASE, PWM_RIGHT_OFFSET, right);
    IOWR_16DIRECT(PWM_BASE, PWM_LEFT_OFFSET, left);
}

static void forward(alt_u16 speed)
{
    pwm_write(
        motor_cmd(1, 0, speed),
        motor_cmd(1, 0, speed)
    );
}

int main(void)
{
    alt_u16 speed = 3125;

    printf("Test HAL PWM Avalon\n");
    printf("PWM BASE = 0x%08X\n", PWM_BASE);

    while (1)
    {
        printf("Avance\n");
        forward(speed);
    }

    return 0;
}