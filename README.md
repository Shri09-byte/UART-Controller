# UART-Controller
UART Transmitter and Receiver Implementaion in SystemVerilog

# UART Controller in SystemVerilog

A from-scratch UART implementation — TX and RX — written in SystemVerilog. Built for 100 MHz FPGAs, 115200 baud, 8N1. The TX side is simple. The RX side has more thought put into it: 16x oversampling, mid-bit sampling, and a 2-FF synchronizer on the input pin.

---

## Why?

UART is one of those things that looks trivial until you actually implement an RX that works reliably on hardware. Getting the baud timing right is easy. Getting the receiver to not randomly corrupt bytes due to metastability or sampling at the wrong point in the bit — that's where the real work is. This project focuses on getting that right.

---

## How it works

![Architecture ](<doc/UART Architectural Diagram.png>)

Both modules share a baud rate generator that derives timing from the 100 MHz system clock. TX uses a baud tick every 868 cycles. RX runs an oversampling tick every 54 cycles (16x faster than baud).

### TX

Pretty standard FSM: `IDLE → START → DATA → STOP → IDLE`

Loads the byte into a shift register, clocks it out LSB-first, one bit per baud tick. A `tx_busy` flag prevents new data from being loaded mid-frame. Nothing clever here — it doesn't need to be.

### RX

This is where It gets complex.

The raw `rx_in` pin can't be fed directly into logic. It's asynchronous — it comes from outside the FPGA clock domain and can violate setup/hold times on any given clock edge. If a flip-flop catches it mid-transition, you get metastability: the output floats at an indeterminate voltage and can propagate garbage through your design. The fix is a 2-stage synchronizer — two back-to-back flip-flops on the input. The first one might go metastable, but it gets a full 10 ns clock period to resolve before the second one samples it. At 100 MHz with 115200 baud input, MTBF from metastability is effectively infinite.

After synchronization, the oversampler watches for a falling edge (start bit). When it sees one, instead of immediately treating that as bit-time zero, it waits 8 oversampling ticks — half a baud period — before the first sample. This puts every subsequent sample at the center of its bit cell, not the edge. That's important because the falling edge could arrive anywhere within a 54-clock window depending on when it crosses the clock boundary. Sampling at the center gives you the most margin against noise and timing mismatch.

The data bits come in through a shift register, LSB first. After the stop bit is validated, `rx_done` pulses for one clock and `rx_data` holds the received byte.

---

## Baud rate math

```
CLK = 100 MHz, BAUD = 115200

Baud divider  = floor(100_000_000 / 115_200) = 868 cycles/bit
OS divider    = floor(868 / 16)               = 54 cycles/tick

Actual baud   = 100_000_000 / 868             = 115,207 bps
```

---

## Ports

**uart_tx**

| Port | Dir | Description |
|---|---|---|
| `clk` | in | 100 MHz system clock |
| `rst` | in | Synchronous reset, active-high |
| `tx_data[7:0]` | in | Byte to send |
| `tx_start` | in | Pulse high for one cycle to start |
| `tx` | out | Serial output line |
| `tx_busy` | out | High during active transmission |

**uart_rx**

| Port | Dir | Description |
|---|---|---|
| `clk` | in | 100 MHz system clock |
| `rst` | in | Synchronous reset, active-high |
| `rx_in` | in | Async serial input (goes through 2-FF sync) |
| `rx_data[7:0]` | out | Received byte — valid when `rx_done` is high |
| `rx_done` | out | One-cycle pulse after a valid frame |


## Testbench

The testbench loops `tx` directly into `rx_in` and checks that what comes out matches what went in. Three bytes tested: `0xAB`, `0x55`, `0xFF`. `0x55` (alternating bits, max transitions) is the useful one for catching oversampling bugs — every bit edge exercises the phase tracking.

Each test case checks `rx_data === expected` after `rx_done` pulses and calls `$error` on mismatch, so it'll fail loudly in any simulator or CI run.

Frame timing checks out at ~86.8 µs per byte (10 bits × 868 cycles / 100 MHz).

---

## FPGA notes

Reset is synchronous throughout. No async resets — cleaner for FPGA synthesis, avoids glitch issues at power-up, and makes timing analysis simpler.

If you're targeting Xilinx, add this to your `.xdc`:

```tcl
set_false_path -from [get_ports rx_in]
set_property ASYNC_REG TRUE [get_cells {<your_hier>/sync_ff1_reg <your_hier>/sync_ff2_reg}]
```

The `ASYNC_REG` constraint is not optional. Without it, the synthesizer is allowed to merge or retime the synchronizer flip-flops, which silently removes the metastability protection. The `set_false_path` tells the timing engine not to apply setup/hold checks to the async input pin — there are none, by design.
