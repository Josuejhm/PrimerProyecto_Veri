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

///////////////////////////////////////////////////////////////
// test_bench: Módulo raíz para correr la prueba            //
//                                                           //
// Parámetros por defecto:                                   //
//   depth = 8   (puede cambiarse con +define+DEPTH=N       //
//               y recompilando con -pvalue+depth=N         //
//               o simplemente editando el parámetro aqui)  //
//   width = 16  (idem con +define+WIDTH=N)                 //
//                                                           //
// Uso típico (VCS):                                         //
//   # Prueba base aleatoria                                 //
//   ./salida +ntb_random_seed_automatic                     //
//                                                           //
//   # Caso de esquina overflow                              //
//   ./salida +OVERFLOW                                      //
//                                                           //
//   # Patrón alternado comenzando en 0xAAAA                //
//   ./salida +PATRON=2                                      //
//                                                           //
//   # Cambiar profundidad en compilacion (VCS)             //
//   vcs ... -pvalue+test_bench.depth=16 ...               //
///////////////////////////////////////////////////////////////
module test_bench;

  // --------------------------------------------------------------------------
  // Parámetros del DUT: pueden sobreescribirse en compilación con
  //   -pvalue+test_bench.depth=<N>  -pvalue+test_bench.width=<N>
  // --------------------------------------------------------------------------
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
    clk = 0;
    t0  = new();
    t0._if = _if;
    t0.ambiente_inst.driver_inst.vif  = _if;
    t0.ambiente_inst.monitor_inst.vif = _if;
    fork
      t0.run();
    join_none
  end

  // Guardián de tiempo absoluto en el test_bench
  always @(posedge clk) begin
    if ($time > 100000) begin
      $display("Test_bench: Tiempo limite absoluto alcanzado");
      $finish;
    end
  end

endmodule
