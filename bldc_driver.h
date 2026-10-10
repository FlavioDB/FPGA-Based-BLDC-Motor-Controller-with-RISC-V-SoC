//=====================================================================
// Designer: Flavio, Alex, Francesco 
// File: bldc_driver.h
// Description:
//   Header file for the custom 6-register BLDC Motor Controller peripheral.
//   Defines register offsets, final register macros, and bitfield masks
//   for communication between the E203 CPU and the FPGA hardware.
//=====================================================================

#ifndef _BLDC_DRIVER_H
#define _BLDC_DRIVER_H

#include "bsp/hbird-e200/env/platform.h" // Must be included for base address and access macros

//=====================================================================
// 1. REGISTER OFFSETS & DEFINITIONS
//=====================================================================
// These offsets are added to BLDC_CTRL_ADDR (defined in platform.h)
#define REG_CONTROL_OFFSET              0x00
#define REG_CARRIER_TIMING_OFFSET       0x04
#define REG_COMMUTATION_TIMING_OFFSET   0x08
#define REG_PWM_DUTY_OFFSET             0x0C
#define REG_SPWM_CONFIG_OFFSET          0x10
#define REG_STATUS_OFFSET               0x14

// Final, easy-to-use macros for accessing the registers from C code
#define CONTROL_REG              BLDC_REG(REG_CONTROL_OFFSET)
#define CARRIER_TIMING_REG       BLDC_REG(REG_CARRIER_TIMING_OFFSET)
#define COMMUTATION_TIMING_REG   BLDC_REG(REG_COMMUTATION_TIMING_OFFSET)
#define PWM_DUTY_REG             BLDC_REG(REG_PWM_DUTY_OFFSET)
#define SPWM_CONFIG_REG          BLDC_REG(REG_SPWM_CONFIG_OFFSET)
#define STATUS_REG               BLDC_REG(REG_STATUS_OFFSET)


//=====================================================================
// 2. BITFIELD DEFINITIONS
//=====================================================================

//----------- Register 0: CONTROL_REG (0x00) -----------//
#define REG0_OP_MODE_BIT                0   // [1:0]
#define REG0_OP_MODE_MASK               0x3 // 2 bits

#define REG0_DIRECTION_BIT              2   // [2]
#define REG0_DIRECTION_MASK             0x1 // 1 bit

#define REG0_ENABLE_MOTOR_BIT           3   // [3]
#define REG0_ENABLE_MOTOR_MASK          0x1 // 1 bit

#define REG0_SOFT_RESET_BIT             4   // [4]
#define REG0_SOFT_RESET_MASK            0x1 // 1 bit (Write 1 to pulse)

#define REG0_SW_BRAKE_ENABLE_BIT        5   // [5]
#define REG0_SW_BRAKE_ENABLE_MASK       0x1 // 1 bit

#define REG0_SW_BRAKE_PATTERN_BIT       6   // [7:6]
#define REG0_SW_BRAKE_PATTERN_MASK      0x3 // 2 bits

#define REG0_HW_BRAKE_PIN_ENABLE_BIT    8   // [8]
#define REG0_HW_BRAKE_PIN_ENABLE_MASK   0x1 // 1 bit

//the rest are reserved bits

//----------- Register 1: CARRIER_TIMING_REG (0x04) -----------//
#define REG1_PWM_CARRIER_PERIOD_BIT     0   // [15:0]
#define REG1_PWM_CARRIER_PERIOD_MASK    0xFFFFU // 16 bits, the U indicates unsigned

#define REG1_DEAD_ZONE_VALUE_BIT        16  // [19:16]
#define REG1_DEAD_ZONE_VALUE_MASK       0xF // 4 bits

//the rest are reserved bits

//----------- Register 2: COMMUTATION_TIMING_REG (0x08) -----------//
#define REG2_COMMUTATION_STEP_PERIOD_BIT    0   // [15:0]
#define REG2_COMMUTATION_STEP_PERIOD_MASK   0xFFFF // 16 bits

//the rest are reserved bits

//----------- Register 3: PWM_DUTY_REG (0x0C) -----------//
#define REG3_PWM_DUTY_VALUE_GENERIC_BIT     0   // [15:0]
#define REG3_PWM_DUTY_VALUE_GENERIC_MASK    0xFFFF // 16 bits

//the rest are reserved bits

//----------- Register 4: SPWM_CONFIG_REG (0x10) -----------//
#define REG4_SPWM_PHASE_INCREMENT_BIT       0   // [15:0]
#define REG4_SPWM_PHASE_INCREMENT_MASK      0xFFFF // 16 bits

#define REG4_SPWM_AMPLITUDE_GLOBAL_BIT      24  // [31:24]
#define REG4_SPWM_AMPLITUDE_GLOBAL_MASK     0xFF // 8 bits

//the rest are reserved bits

//----------- Register 5: STATUS_REG (0x14) - Read Only -----------//
#define REG5_BRAKE_ACTIVE_HWSTATUS_BIT      0   // [0]
#define REG5_BRAKE_ACTIVE_HWSTATUS_MASK     0x1 // 1 bit

#define REG5_MOTOR_ENABLED_HWSTATUS_BIT     1   // [1]
#define REG5_MOTOR_ENABLED_HWSTATUS_MASK    0x1 // 1 bit

#define REG5_OP_MODE_HWSTATUS_BIT           5   // [6:5]
#define REG5_OP_MODE_HWSTATUS_MASK          0x3 // 2 bits

#define REG5_COMM_STATE_6STEP_HWSTATUS_BIT  7   // [9:7]
#define REG5_COMM_STATE_6STEP_HWSTATUS_MASK 0x7 // 3 bits

#define REG5_SPWM_PHASE_U_HWSTATUS_BIT      16  // [31:16]
#define REG5_SPWM_PHASE_U_HWSTATUS_MASK     0xFFFF // 16 bits


//=====================================================================
// 3. ENUMERATIONS AND TYPEDEFS
//=====================================================================

// --- Operating Modes (for op_mode field) ---
typedef enum {
    MODE_STATIC = 0,
    MODE_PWM_6STEP = 1,
    MODE_SPWM_SINE = 2,
    MODE_RESERVED = 3
} bldc_op_mode_t;

// --- Brake Patterns (for sw_brake_pattern field) ---
typedef enum {
    BRAKE_COAST = 0,    // All FETs OFF
    BRAKE_DYNAMIC = 1,  // All Low-Side ON
    BRAKE_RESERVED_2 = 2,
    BRAKE_RESERVED_3 = 3
} bldc_brake_pattern_t;


//=====================================================================
// 4. FUNCTION PROTOTYPES
//=====================================================================
// You would declare your new C driver functions here, for example:
void bldc_set_mode(bldc_op_mode_t mode);
void bldc_set_direction(int direction);
void bldc_enable_motor(int enable);
// We must continue adding some more functions for other commands, or we can simply create them directly in the main.c...

#endif // _BLDC_DRIVER_H