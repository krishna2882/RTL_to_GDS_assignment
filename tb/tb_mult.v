`timescale 1ns/1ps

// Exhaustive self-checking testbench for mult_array.
//   - 10 ns clock, rst_n held low for the first 2 cycles
//   - applies all 256 (a, b) combinations
//   - inputs change on the falling edge, so they are stable at the rising
//     edge (also avoids races in the gate-level simulation of Part B)
//   - each result is checked after the 2-cycle latency
module tb_mult;

    reg        clk   = 1'b0;
    reg        rst_n = 1'b0;
    reg  [3:0] a     = 4'd0;
    reg  [3:0] b     = 4'd0;
    wire [7:0] p;

    reg  [7:0] expected;
    integer    i, j;
    integer    checked = 0;
    integer    errors  = 0;

    mult_array dut (
        .clk   (clk),
        .rst_n (rst_n),
        .a     (a),
        .b     (b),
        .p     (p)
    );

    // 10 ns period clock
    always #5 clk = ~clk;

    initial begin
        $dumpfile("mult.vcd");
        $dumpvars(0, tb_mult);
        $timeformat(-9, 0, " ns", 0);   // print %t in ns

        // Reset: hold rst_n low for the first 2 clock cycles
        rst_n = 1'b0;
        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;

        for (i = 0; i < 16; i = i + 1) begin
            for (j = 0; j < 16; j = j + 1) begin
                // Apply inputs on the falling edge
                a        = i;
                b        = j;
                expected = a * b;      // 8-bit context: full product

                @(posedge clk);        // edge 1: a, b captured into input registers
                @(posedge clk);        // edge 2: product captured into p
                @(negedge clk);        // sample p mid-cycle

                checked = checked + 1;
                if (p !== expected) begin
                    errors = errors + 1;
                    $display("MISMATCH: a=%0d b=%0d expected=%0d got=%0d (time %0t)",
                             a, b, expected, p, $time);
                end
            end
        end

        if (errors == 0)
            $display("PASS: %0d vectors checked, %0d errors", checked, errors);
        else
            $display("FAIL: %0d vectors checked, %0d errors", checked, errors);

        $finish;
    end

endmodule
