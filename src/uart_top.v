//-----------------------------------------------------------------------------
// uart_top.v
// Top module: ties together the baud generator, transmitter and receiver.
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps

module uart_top #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 115_200
) (
    input  wire       clk,
    input  wire       rst_n,
    // transmit side
    input  wire       tx_start,
    input  wire [7:0] tx_data,
    output wire       tx,
    output wire       tx_busy,
    // receive side
    input  wire       rx,
    output wire [7:0] rx_data,
    output wire       rx_done,
    output wire       rx_error
);

    wire tick;

    baud_gen #(
        .CLK_FREQ (CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) u_baud_gen (
        .clk  (clk),
        .rst_n(rst_n),
        .tick (tick)
    );

    uart_tx u_tx (
        .clk     (clk),
        .rst_n   (rst_n),
        .tick    (tick),
        .tx_start(tx_start),
        .tx_data (tx_data),
        .tx      (tx),
        .tx_busy (tx_busy)
    );

    uart_rx u_rx (
        .clk     (clk),
        .rst_n   (rst_n),
        .tick    (tick),
        .rx      (rx),
        .rx_data (rx_data),
        .rx_done (rx_done),
        .rx_error(rx_error)
    );

endmodule
