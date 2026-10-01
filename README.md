# UART Transmitter and Receiver in Verilog

A complete UART (Universal Asynchronous Receiver Transmitter) designed in Verilog HDL, with a self-checking loopback testbench. Frame format is **8N1** (8 data bits, no parity, 1 stop bit) with **16x oversampling** on the receive side.

## Block Diagram

```
                 +-----------------------------+
                 |          uart_top           |
                 |                             |
   clk, rst_n -->|  +-----------+              |
                 |  | baud_gen  |--- tick ---+ |
                 |  +-----------+            | |
                 |                           v |
   tx_start   -->|  +-----------+         +-----------+
   tx_data[7:0]->|  |  uart_tx  |-- tx -->|  (serial) |
                 |  +-----------+         +-----------+
                 |                           ^ |
                 |  +-----------+            | |
   rx         -->|  |  uart_rx  |<-- tick --+ |
                 |  +-----------+              |
                 |   | rx_data[7:0]            |
                 |   | rx_done, rx_error       |
                 +-----------------------------+
```

## Modules

| File | Description |
|------|-------------|
| `src/baud_gen.v` | Divides the system clock into a tick that fires 16 times per bit period. Default: 50 MHz clock, 115200 baud. |
| `src/uart_tx.v`  | Transmit FSM (`IDLE -> START -> DATA -> STOP`). Shifts the byte out LSB first, holds the line high when idle. |
| `src/uart_rx.v`  | Receive FSM with a double-flop synchronizer on the async `rx` line. Confirms the start bit at its middle (8th tick), then samples every data bit at its middle. Flags a framing error if the stop bit is not high. |
| `src/uart_top.v` | Connects the three blocks. |
| `tb/uart_tb.v`   | Self-checking loopback testbench: `tx` is wired back into `rx`, six bytes (0x55, 0xAA, 0x00, 0xFF, 'A', 'Z') are sent, and every received byte is compared against what was sent. |

## How to Run

With [Icarus Verilog](http://iverilog.icarus.com/) installed:

```bash
iverilog -o uart_sim src/*.v tb/uart_tb.v
vvp uart_sim
```

Expected output:

```
PASS: sent 55, received 55
PASS: sent aa, received aa
PASS: sent 00, received 00
PASS: sent ff, received ff
PASS: sent 41, received 41
PASS: sent 5a, received 5a

ALL TESTS PASSED (6/6 bytes looped back correctly)
```

To view the waveforms:

```bash
gtkwave uart_tb.vcd
```

You can also paste the files into [EDA Playground](https://www.edaplayground.com/) (tool: Icarus Verilog) and run it in the browser.

## Design Notes

- **Why 16x oversampling?** The receiver has no shared clock with the transmitter. Sampling 16 times per bit lets it find the middle of each bit, which gives the best tolerance to small baud rate mismatches between the two ends.
- **Double-flop synchronizer:** `rx` is an asynchronous input, so it passes through two flip-flops before the FSM looks at it. This avoids metastability problems.
- **Glitch rejection:** the start bit is re-checked at its middle. If the line went back high, it was noise, and the receiver returns to idle instead of reading a false frame.
- **Framing error:** if the stop bit samples as 0, `rx_error` goes high along with `rx_done`, so the system above can discard the byte.

## Parameters

Both the clock frequency and baud rate are parameters of `uart_top`:

```verilog
uart_top #(
    .CLK_FREQ (50_000_000),  // your board clock in Hz
    .BAUD_RATE(115_200)
) uart_inst ( ... );
```
