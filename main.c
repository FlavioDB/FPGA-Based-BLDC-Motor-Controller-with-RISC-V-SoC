// File: main.c
// Description: C program to test the BLDC motor controller.
// VERSION 5 - Tests a PWM -> BRAKE sequence.
//             PWM mode runs for an extended period to check for stability.

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

    printf("\n--- BLDC Controller (PWM -> BRAKE) Test Program Start ---\n");

    // --- 1. Reset and Initialize the Motor Controller ---
    printf("\nStep 1: Initializing BLDC registers...\n");
    
    // Clear all configuration registers to a known state
    CONTROL_REG            = 0;
    CARRIER_TIMING_REG     = 0;
    COMMUTATION_TIMING_REG = 0;
    PWM_DUTY_REG           = 0;
    SPWM_CONFIG_REG        = 0;
    
    // Trigger a soft reset to ensure all internal state machines are reset
    CONTROL_REG = (1U << REG0_SOFT_RESET_BIT);
    CONTROL_REG = 0; // De-assert reset
    
    printf("Initial hardware registers cleared and soft reset triggered.\n");

    //=====================================================================
    // STAGE 2: RUN IN PWM MODE
    //=====================================================================
    printf("\nStep 2: Configuring for PWM mode...\n");
    
    // Define parameters for this mode
    uint32_t temp_reg_val = 0;
    uint16_t dead_zone_val = 5;
    uint16_t pwm_carrier_period = 1000;
    uint16_t duty_50_percent = pwm_carrier_period / 2;
    uint16_t desired_comm_period = 30000; // This controls the 6-step rotation speed

    // Configure timing registers
    CARRIER_TIMING_REG = (dead_zone_val << REG1_DEAD_ZONE_VALUE_BIT) | (pwm_carrier_period << REG1_PWM_CARRIER_PERIOD_BIT);
    printf(" -> Set Dead Zone, Carrier Period. CARRIER_TIMING_REG = 0x%08X\n", (unsigned int)CARRIER_TIMING_REG);
    
    COMMUTATION_TIMING_REG = (desired_comm_period << REG2_COMMUTATION_STEP_PERIOD_BIT);
    printf(" -> Set Commutation Period. COMMUTATION_TIMING_REG = 0x%08X\n", (unsigned int)COMMUTATION_TIMING_REG);

    PWM_DUTY_REG = (duty_50_percent << REG3_PWM_DUTY_VALUE_GENERIC_BIT);
    printf(" -> Set PWM Duty Value. PWM_DUTY_REG = 0x%08X\n", (unsigned int)PWM_DUTY_REG);
    
    // Configure control register for PWM mode and direction
    temp_reg_val = 0;
    temp_reg_val |= (MODE_PWM_6STEP << REG0_OP_MODE_BIT);
    temp_reg_val |= (1U << REG0_DIRECTION_BIT); // Set Direction to Clockwise
    CONTROL_REG = temp_reg_val;
    printf(" -> Set Mode to PWM_6STEP, Direction to CW. CONTROL_REG = 0x%08X\n", (unsigned int)CONTROL_REG);

    // Enable the motor
    CONTROL_REG |= (1U << REG0_ENABLE_MOTOR_BIT);
    printf(" -> Motor ENABLED in PWM mode. Running for an extended duration...\n");
    
    // Let it run for a while to verify stability
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