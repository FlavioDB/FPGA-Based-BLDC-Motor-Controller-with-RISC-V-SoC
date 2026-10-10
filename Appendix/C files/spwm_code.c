// File: main.c
// Description: C program to test the BLDC motor controller.
// VERSION 6 - Tests an SPWM -> BRAKE sequence.
//             SPWM mode runs for an extended period to check for stability.

#include <stdint.h>
#include <unistd.h>
#include <stdio.h>
#include "bsp/hbird-e200/env/platform.h"
#include "bsp/hbird-e200/env/init.h"

#include "bldc_driver.h" // Your hardware API

// A simple hardware delay loop
void simple_delay(volatile uint32_t count) {
    while(count--) {
        __asm__ volatile ("nop");
    }
}

int main(void) {
    _init(); // Initializes UART for printf

    printf("\n--- BLDC Controller (SPWM -> BRAKE) Test Program Start ---\n");

    // --- 1. Reset and Initialize the Motor Controller ---
    printf("\nStep 1: Initializing BLDC registers...\n");
    
    // Clear all configuration registers to a known state
    CONTROL_REG            = 0;
    CARRIER_TIMING_REG     = 0;
    COMMUTATION_TIMING_REG = 0; // Not used by SPWM, but good practice to clear
    PWM_DUTY_REG           = 0; // Not used by SPWM, but good practice to clear
    SPWM_CONFIG_REG        = 0;
    
    // Trigger a soft reset to ensure all internal state machines are reset
    CONTROL_REG = (1U << REG0_SOFT_RESET_BIT);
    CONTROL_REG = 0; // De-assert reset
    
    printf("Initial hardware registers cleared and soft reset triggered.\n");

    //=====================================================================
    // STAGE 2: RUN IN SPWM (SINUSOIDAL) MODE
    //=====================================================================
    printf("\nStep 2: Configuring for SPWM mode...\n");
    
    // Define parameters for this mode
    uint32_t temp_reg_val = 0;
    uint16_t dead_zone_val = 5;
    uint16_t pwm_carrier_period = 1000;
    uint16_t spwm_phase_increment = 10;  // Controls motor speed (electrical frequency)
    uint8_t  spwm_amplitude = 200;       // Controls voltage/torque (max 255)

    // Configure timing registers (SPWM uses the same PWM carrier)
    CARRIER_TIMING_REG = (dead_zone_val << REG1_DEAD_ZONE_VALUE_BIT) | (pwm_carrier_period << REG1_PWM_CARRIER_PERIOD_BIT);
    printf(" -> Set Dead Zone, Carrier Period. CARRIER_TIMING_REG = 0x%08X\n", (unsigned int)CARRIER_TIMING_REG);
    
    // Configure the SPWM-specific register
    SPWM_CONFIG_REG = (spwm_amplitude << REG4_SPWM_AMPLITUDE_GLOBAL_BIT) | (spwm_phase_increment << REG4_SPWM_PHASE_INCREMENT_BIT);
    printf(" -> Set SPWM Amp, Phase Inc. SPWM_CONFIG_REG = 0x%08X\n", (unsigned int)SPWM_CONFIG_REG);
    
    // Configure control register for SPWM mode and direction
    temp_reg_val = 0;
    temp_reg_val |= (MODE_SPWM_SINE << REG0_OP_MODE_BIT);
    temp_reg_val |= (1U << REG0_DIRECTION_BIT); // Set Direction to Clockwise
    CONTROL_REG = temp_reg_val;
    printf(" -> Set Mode to SPWM_SINE, Direction to CW. CONTROL_REG = 0x%08X\n", (unsigned int)CONTROL_REG);

    // Enable the motor
    CONTROL_REG |= (1U << REG0_ENABLE_MOTOR_BIT);
    printf(" -> Motor ENABLED in SPWM mode. Running for an extended duration...\n");
    
    // Let it run for a while to see several full sine wave rotations
    simple_delay(600000); 

    //=====================================================================
    // STAGE 3: APPLY DYNAMIC BRAKE
    //=====================================================================
    printf("\nStep 3: Applying Dynamic Brake...\n");

    // CRITICAL: Disable motor drive before enabling brake
    CONTROL_REG &= ~(1U << REG0_ENABLE_MOTOR_BIT);
    printf(" -> Motor drive disabled.\n");
    simple_delay(1000); // Tiny delay for signals to settle

    // Set brake pattern and enable the software brake override
    temp_reg_val = CONTROL_REG;
    temp_reg_val |= (BRAKE_DYNAMIC << REG0_SW_BRAKE_PATTERN_BIT);
    temp_reg_val |= (1U << REG0_SW_BRAKE_ENABLE_BIT);
    CONTROL_REG = temp_reg_val;
    
    printf(" -> Software Brake ENABLED. Holding brake...\n");
    simple_delay(200000); // Hold the brake for a short time

    //=====================================================================
    // END OF TEST
    //=====================================================================
    printf("\n--- Test Sequence Complete. Disabling all outputs. ---\n");
    CONTROL_REG = 0; // Final disable for a clean end state

    printf("--- Entering Infinite Idle Loop ---\n");
    while(1) {
        // The CPU will idle here until the simulation is terminated.
    }

    return 0;
}