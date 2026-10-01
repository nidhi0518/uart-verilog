//-----------------------------------------------------------------------------
// uart_tx.v
// UART transmitter: 8 data bits, no parity, 1 stop bit (8N1).
// Driven by the 16x baud tick from baud_gen. Each bit lasts 16 ticks.
//
// FSM: IDLE -> START -> DATA (8 bits, LSB first) -> STOP -> IDLE
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps

module uart_tx (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tick,       // 16x baud tick
    input  wire       tx_start,   // pulse high with tx_data valid
    input  wire [7:0] tx_data,    // byte to send
    output reg        tx,         // serial output line
    output reg        tx_busy     // high while a frame is being sent
);

    // FSM state encoding
    localparam [1:0] IDLE  = 2'b00,
                     START = 2'b01,
                     DATA  = 2'b10,
                     STOP  = 2'b11;

    reg [1:0] state;
    reg [3:0] tick_cnt;   // counts 0..15 ticks inside one bit
    reg [2:0] bit_idx;    // which data bit is on the line
    reg [7:0] shift_reg;  // byte being shifted out

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            tick_cnt  <= 4'd0;
            bit_idx   <= 3'd0;
            shift_reg <= 8'd0;
            tx        <= 1'b1;   // line idles high
            tx_busy   <= 1'b0;
        end else begin
            case (state)

                IDLE: begin
                    tx      <= 1'b1;
                    tx_busy <= 1'b0;
                    if (tx_start) begin
                        shift_reg <= tx_data;
                        tick_cnt  <= 4'd0;
                        tx_busy   <= 1'b1;
                        state     <= START;
                    end
                end

                START: begin
                    tx <= 1'b0;                      // start bit
                    if (tick) begin
                        if (tick_cnt == 4'd15) begin
                            tick_cnt <= 4'd0;
                            bit_idx  <= 3'd0;
                            state    <= DATA;
                        end else
                            tick_cnt <= tick_cnt + 1'b1;
                    end
                end

                DATA: begin
                    tx <= shift_reg[0];              // LSB first
                    if (tick) begin
                        if (tick_cnt == 4'd15) begin
                            tick_cnt  <= 4'd0;
                            shift_reg <= shift_reg >> 1;
                            if (bit_idx == 3'd7)
                                state <= STOP;
                            else
                                bit_idx <= bit_idx + 1'b1;
                        end else
                            tick_cnt <= tick_cnt + 1'b1;
                    end
                end

                STOP: begin
                    tx <= 1'b1;                      // stop bit
                    if (tick) begin
                        if (tick_cnt == 4'd15) begin
                            tick_cnt <= 4'd0;
                            tx_busy  <= 1'b0;
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
