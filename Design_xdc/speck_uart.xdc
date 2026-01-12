## Basys 3 Constraints for SPECK64/128 UART Crypto System
## Target: Artix-7 XC7A35T-1CPG236C

## ============================================================================
## Clock Signal (100 MHz on-board oscillator)
## ============================================================================
set_property -dict { PACKAGE_PIN W5   IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

## ============================================================================
## Reset Button (BTNC - Center pushbutton)
## ============================================================================
set_property -dict { PACKAGE_PIN U18  IOSTANDARD LVCMOS33 } [get_ports rst]

## ============================================================================
## USB-UART Bridge (Built-in on Basys 3)
## Connected to FTDI FT2232HQ chip
## Appears as COM port on PC
## ============================================================================
# UART RX (from PC to FPGA)
set_property -dict { PACKAGE_PIN B18  IOSTANDARD LVCMOS33 } [get_ports uart_rxd]

# UART TX (from FPGA to PC)  
set_property -dict { PACKAGE_PIN A18  IOSTANDARD LVCMOS33 } [get_ports uart_txd]

## ============================================================================
## LEDs (16 total: LD0-LD15)
## Status Monitoring:
##   LED0     = busy (controller processing)
##   LED1     = keys_loaded (key schedule completed)
##   LED7:2   = state[5:0] (state machine indicator)
##   LED15:8  = unused (tied to 0 in design)
## ============================================================================
set_property -dict { PACKAGE_PIN U16  IOSTANDARD LVCMOS33 } [get_ports {led[0]}]
set_property -dict { PACKAGE_PIN E19  IOSTANDARD LVCMOS33 } [get_ports {led[1]}]
set_property -dict { PACKAGE_PIN U19  IOSTANDARD LVCMOS33 } [get_ports {led[2]}]
set_property -dict { PACKAGE_PIN V19  IOSTANDARD LVCMOS33 } [get_ports {led[3]}]
set_property -dict { PACKAGE_PIN W18  IOSTANDARD LVCMOS33 } [get_ports {led[4]}]
set_property -dict { PACKAGE_PIN U15  IOSTANDARD LVCMOS33 } [get_ports {led[5]}]
set_property -dict { PACKAGE_PIN U14  IOSTANDARD LVCMOS33 } [get_ports {led[6]}]
set_property -dict { PACKAGE_PIN V14  IOSTANDARD LVCMOS33 } [get_ports {led[7]}]
set_property -dict { PACKAGE_PIN V13  IOSTANDARD LVCMOS33 } [get_ports {led[8]}]
set_property -dict { PACKAGE_PIN V3   IOSTANDARD LVCMOS33 } [get_ports {led[9]}]
set_property -dict { PACKAGE_PIN W3   IOSTANDARD LVCMOS33 } [get_ports {led[10]}]
set_property -dict { PACKAGE_PIN U3   IOSTANDARD LVCMOS33 } [get_ports {led[11]}]
set_property -dict { PACKAGE_PIN P3   IOSTANDARD LVCMOS33 } [get_ports {led[12]}]
set_property -dict { PACKAGE_PIN N3   IOSTANDARD LVCMOS33 } [get_ports {led[13]}]
set_property -dict { PACKAGE_PIN P1   IOSTANDARD LVCMOS33 } [get_ports {led[14]}]
set_property -dict { PACKAGE_PIN L1   IOSTANDARD LVCMOS33 } [get_ports {led[15]}]

## ============================================================================
## Configuration
## Required for Artix-7 devices
## ============================================================================
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

## ============================================================================
## Bitstream Configuration
## Enable bitstream compression to reduce programming time
## ============================================================================
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]

## ============================================================================
## Timing Constraints
## ============================================================================
## UART signals are asynchronous, mark them as false paths
set_false_path -from [get_ports uart_rxd]
set_false_path -to [get_ports uart_txd]

## Reset button is asynchronous
set_false_path -from [get_ports rst]

## LED outputs don't need tight timing
set_false_path -to [get_ports {led[*]}]
