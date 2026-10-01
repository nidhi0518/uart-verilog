//-----------------------------------------------------------------------------
// uart_tb.v
// Self-checking loopback testbench.
// tx is wired to rx, a set of bytes is transmitted, and the testbench
// checks that every received byte matches what was sent.
//
// Run:
//   iverilog -o uart_sim src/*.v tb/uart_tb.v
//   vvp uart_sim
//   gtkwave uart_tb.vcd   (optional, to see the waveforms)
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps

module uart_tb;

    // 50 MHz clock -> 20 ns period
    localparam CLK_PERIOD = 20;

    reg        clk;
    reg        rst_n;
    reg        tx_start;
    reg  [7:0] tx_data;
    wire       tx;
    wire       tx_busy;
    wire [7:0] rx_data;
    wire       rx_done;
    wire       rx_error;

    integer errors = 0;
    integer i;

    // test bytes: edges, patterns and a few normal values
    reg [7:0] test_bytes [0:5];

    // loopback: tx feeds rx
    uart_top #(
        .CLK_FREQ (50_000_000),
        .BAUD_RATE(115_200)
    ) dut (
        .clk     (clk),
        .rst_n   (rst_n),
        .tx_start(tx_start),
        .tx_data (tx_data),
        .tx      (tx),
        .tx_busy (tx_busy),
        .rx      (tx),        // <-- loopback connection
        .rx_data (rx_data),
        .rx_done (rx_done),
        .rx_error(rx_error)
    );

    // clock
    always #(CLK_PERIOD/2) clk = ~clk;

    // send one byte and wait for the receiver to finish
    task send_and_check(input [7:0] data);
        begin
            wait (!tx_busy);          // make sure previous frame fully ended
            @(posedge clk);
            tx_data  = data;
            tx_start = 1'b1;
            @(posedge clk);
            tx_start = 1'b0;

            // wait for the received byte
            @(posedge rx_done);
            @(posedge clk);

            if (rx_data !== data) begin
                $display("FAIL: sent %02h, received %02h", data, rx_data);
                errors = errors + 1;
            end else if (rx_error) begin
                $display("FAIL: framing error on byte %02h", data);
                errors = errors + 1;
            end else begin
                $display("PASS: sent %02h, received %02h", data, rx_data);
            end

            // small gap between frames
            repeat (500) @(posedge clk);
        end
    endtask

    // safety watchdog so the sim can never hang forever
    initial begin
        #10_000_000;   // 10 ms
        $display("TIMEOUT: simulation did not finish");
        $finish;
    end

    initial begin
        $dumpfile("uart_tb.vcd");
        $dumpvars(0, uart_tb);

        test_bytes[0] = 8'h55;  // alternating 01010101
        test_bytes[1] = 8'hAA;  // alternating 10101010
        test_bytes[2] = 8'h00;  // all zeros
        test_bytes[3] = 8'hFF;  // all ones
        test_bytes[4] = 8'h41;  // 'A'
        test_bytes[5] = 8'h5A;  // 'Z'

        clk      = 1'b0;
        rst_n    = 1'b0;
        tx_start = 1'b0;
        tx_data  = 8'd0;

        // release reset
        repeat (10) @(posedge clk);
        rst_n = 1'b1;
        repeat (10) @(posedge clk);

        for (i = 0; i < 6; i = i + 1)
            send_and_check(test_bytes[i]);

        if (errors == 0)
            $display("\nALL TESTS PASSED (6/6 bytes looped back correctly)");
        else
            $display("\nTESTS FAILED: %0d error(s)", errors);

        $finish;
    end

endmodule
