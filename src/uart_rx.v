//-----------------------------------------------------------------------------
// uart_rx.v
// UART receiver: 8 data bits, no parity, 1 stop bit (8N1).
// Uses 16x oversampling: the start bit is confirmed at its middle
// (8th tick), then every data bit is sampled at its middle (16th tick after).
//
// FSM: IDLE -> START -> DATA (8 bits, LSB first) -> STOP -> IDLE
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps

module uart_rx (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tick,       // 16x baud tick
    input  wire       rx,         // serial input line
    output reg  [7:0] rx_data,    // received byte
    output reg        rx_done,    // one-cycle pulse when a byte is ready
    output reg        rx_error    // high if stop bit was not 1 (framing error)
);

    localparam [1:0] IDLE  = 2'b00,
                     START = 2'b01,
                     DATA  = 2'b10,
                     STOP  = 2'b11;

    reg [1:0] state;
    reg [3:0] tick_cnt;
    reg [2:0] bit_idx;
    reg [7:0] shift_reg;

    // double-flop synchronizer for the async rx line
    reg rx_meta, rx_sync;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_meta <= 1'b1;
            rx_sync <= 1'b1;
        end else begin
            rx_meta <= rx;
            rx_sync <= rx_meta;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            tick_cnt  <= 4'd0;
            bit_idx   <= 3'd0;
            shift_reg <= 8'd0;
            rx_data   <= 8'd0;
            rx_done   <= 1'b0;
            rx_error  <= 1'b0;
        end else begin
            rx_done <= 1'b0;   // default: pulse only one cycle

            case (state)

                IDLE: begin
                    if (!rx_sync) begin              // falling edge = start bit
                        tick_cnt <= 4'd0;
                        state    <= START;
                    end
                end

                START: begin
                    if (tick) begin
                        if (tick_cnt == 4'd7) begin  // middle of start bit
                            if (!rx_sync) begin      // still low -> valid start
                                tick_cnt <= 4'd0;
                                bit_idx  <= 3'd0;
                                state    <= DATA;
                            end else
                                state <= IDLE;       // glitch, go back
                        end else
                            tick_cnt <= tick_cnt + 1'b1;
                    end
                end

                DATA: begin
                    if (tick) begin
                        if (tick_cnt == 4'd15) begin // middle of data bit
                            tick_cnt  <= 4'd0;
                            shift_reg <= {rx_sync, shift_reg[7:1]}; // LSB first
                            if (bit_idx == 3'd7)
                                state <= STOP;
                            else
                                bit_idx <= bit_idx + 1'b1;
                        end else
                            tick_cnt <= tick_cnt + 1'b1;
                    end
                end

                STOP: begin
                    if (tick) begin
                        if (tick_cnt == 4'd15) begin // middle of stop bit
                            tick_cnt <= 4'd0;
                            rx_data  <= shift_reg;
                            rx_done  <= 1'b1;
                            rx_error <= ~rx_sync;    // stop bit must be 1
                            state    <= IDLE;
                        end else
                            tick_cnt <= tick_cnt + 1'b1;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
