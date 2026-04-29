`timescale 1ns/1ps
`include "fifo.sv"
`include "interface_transactions.sv"
`include "driver.sv"
`include "monitor.sv"
`include "checker.sv"
`include "score_board.sv"
`include "generator.sv"
`include "agent.sv"
`include "ambiente.sv"
`include "test.sv"

// Modulo raiz del testbench.
// depth y width se pasan en compilacion con:
//   -pvalue+test_bench.depth=N
//   -pvalue+test_bench.width=N
// La semilla de aleatorizacion se controla con +semilla=N en ejecucion.
// Ver comando.sh para la forma de compilar y ejecutar.
module test_bench;

  parameter depth = 8;
  parameter width = 16;

  reg clk;
  test #(.depth(depth), .width(width)) t0;

  fifo_if #(.width(width)) _if(.clk(clk));
  always #5 clk = ~clk;

  fifo_generic #(.Depth(depth), .DataWidth(width)) uut(
    .writeData(_if.dato_in),
    .readData(_if.dato_out),
    .writeEn(_if.push),
    .readEn(_if.pop),
    .clk(_if.clk),
    .full(_if.full),
    .pndng(_if.pndng),
    .rst(_if.rst)
  );

  initial begin
    begin
      int semilla;
      semilla = 0;
      if ($value$plusargs("semilla=%d", semilla)) begin
        $srandom(semilla);
        $display("[0] Test_bench: depth=%0d width=%0d semilla=%0d", depth, width, semilla);
      end else begin
        $display("[0] Test_bench: depth=%0d width=%0d semilla=automatica", depth, width);
      end
    end
    clk = 0;
    t0  = new();
    t0._if = _if;
    t0.ambiente_inst.driver_inst.vif  = _if;
    t0.ambiente_inst.monitor_inst.vif = _if;
    fork
      t0.run();
    join_none
  end

  // Limite de tiempo absoluto como respaldo al limite calculado por el Test
  always @(posedge clk) begin
    if ($time > 300000) begin
      $display("Test_bench: Tiempo limite absoluto alcanzado");
      $finish;
    end
  end

endmodule
