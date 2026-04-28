////////////////////////////////////////////////////////////////////////////////////////////////////
// Test: Prueba base completamente aleatoria para la FIFO                                         //
//                                                                                                //
// La prueba base lanza una unica instruccion (prueba_base) al generador.                        //
// Con cada semilla distinta se produce una secuencia completamente diferente que                 //
// aleatoriza: numero de transacciones, tipos, retardos y datos de entrada.                      //
//                                                                                                //
// Corriendo suficientes semillas se cubre el 100% del espacio de pruebas:                       //
//   - Eventos de reset, lectura, escritura y lectura/escritura                                   //
//   - Tiempos de espera entre eventos                                                            //
//   - Datos de entrada aleatorios                                                                //
//   - Cantidad variable de eventos (depth a depth*4)                                            //
//                                                                                                //
// Uso:                                                                                           //
//   Semilla especifica:   +ntb_random_seed=12345                                                //
//   Semilla automatica:   +ntb_random_seed_automatic                                            //
////////////////////////////////////////////////////////////////////////////////////////////////////

class test #(parameter width = 16, parameter depth = 8);

  // --- Mailboxes ---
  comando_test_sb_mbx    test_sb_mbx;
  comando_test_agent_mbx test_gen_mbx;

  // --- Parámetros ---
  parameter max_retardo   = 8;
  // Tiempo limite: 32 trans maximo * max_retardo * 20 clk por ciclo + margen
  parameter tiempo_limite = 32 * max_retardo * 20 + 2000;

  // --- Variables ---
  instrucciones_agente instr_gen;
  solicitud_sb         instr_sb;

  // --- Ambiente ---
  ambiente #(.depth(depth), .width(width)) ambiente_inst;

  // --- Interface ---
  virtual fifo_if #(.width(width)) _if;

  // -----------------------------------------------------------------------
  // Constructor
  // -----------------------------------------------------------------------
  function new;
    test_sb_mbx  = new();
    test_gen_mbx = new();

    ambiente_inst     = new();
    ambiente_inst._if = _if;

    ambiente_inst.test_gen_mbx                = test_gen_mbx;
    ambiente_inst.generator_inst.test_gen_mbx = test_gen_mbx;
    ambiente_inst.test_sb_mbx                 = test_sb_mbx;
    ambiente_inst.scoreboard_inst.test_sb_mbx = test_sb_mbx;

    ambiente_inst.generator_inst.max_retardo = max_retardo;
  endfunction

  // -----------------------------------------------------------------------
  // run
  // -----------------------------------------------------------------------
  task run;
    $display("[%g]  El Test fue inicializado", $time);
    $display("[%g]  Test: FIFO depth=%0d width=%0d max_retardo=%0d tiempo_limite=%0d",
             $time, depth, width, max_retardo, tiempo_limite);

    fork
      ambiente_inst.run();
    join_none

    // Prueba base: una instruccion, la semilla controla todo
    instr_gen = prueba_base;
    test_gen_mbx.put(instr_gen);
    $display("[%g]  Test: Lanzada prueba_base", $time);

    #(tiempo_limite)
    $display("[%g]  Test: Tiempo limite alcanzado", $time);

    instr_sb = retardo_promedio;
    test_sb_mbx.put(instr_sb);

    instr_sb = reporte;
    test_sb_mbx.put(instr_sb);

    #20
    $finish;
  endtask

endclass