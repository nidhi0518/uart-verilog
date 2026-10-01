//-----------------------------------------------------------------------------
// baud_gen.v
// Baud rate tick generator for the UART.
// Divides the system clock down to 16 ticks per bit (16x oversampling).
//
// Default: 50 MHz clock, 115200 baud
//   DIVISOR = 50_000_000 / (115200 * 16) = 27 (approx)
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps

module baud_gen #(
    parameter CLK_FREQ  = 50_000_000,   // system clock in Hz
    parameter BAUD_RATE = 115_200       // UART baud rate
) (
    input  wire clk,
    input  wire rst_n,
    output reg  tick        // one-cycle pulse, 16 ticks per bit period
);

    localparam integer DIVISOR = CLK_FREQ / (BAUD_RATE * 16);
    localparam integer CNT_W   = $clog2(DIVISOR);

    reg [CNT_W-1:0] count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= 0;
            tick  <= 1'b0;
        end else if (count == DIVISOR - 1) begin
            count <= 0;
            tick  <= 1'b1;
        end else begin
            count <= count + 1'b1;
            tick  <= 1'b0;
        end
    end

endmodule
