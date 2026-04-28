////////////////////////////////////////////////////////////////////////////////////////////////////
// Test: Siempre lanza prueba_base. Los plusargs controlan el escenario.                         //
//                                                                                                //
// Sin plusargs → prueba general aleatoria (defaults internos del generador).                    //
//                                                                                                //
// Ver comando.sh para los plusargs de cada caso de esquina.                                     //
////////////////////////////////////////////////////////////////////////////////////////////////////

class test #(parameter width = 16, parameter depth = 8);

  // --- Mailboxes ---
  comando_test_sb_mbx    test_sb_mbx;
  comando_test_agent_mbx test_gen_mbx;

  // --- Parámetros ---
  parameter max_retardo = 8;

  // Tiempo limite conservador: cubre prefijo=depth + n_trans_max=40 con retardo_max=8
  // (depth + 40) * max_retardo * 20 + margen
  parameter tiempo_limite = (depth + 40) * max_retardo * 20 + 5000;

  // --- Variables ---
  instrucciones_agente instr_gen;
  solicitud_sb         instr_sb;

  // --- Ambiente ---
  ambiente #(.depth(depth), .width(width)) ambiente_inst;

  // --- Interface ---
  virtual fifo_if #(.width(width)) _if;

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

  task run;
    $display("[%g]  El Test fue inicializado", $time);
    $display("[%g]  Test: FIFO depth=%0d width=%0d max_retardo=%0d tiempo_limite=%0d",
             $time, depth, width, max_retardo, tiempo_limite);

    fork
      ambiente_inst.run();
    join_none

    // Siempre prueba_base — los plusargs ajustan los constraints internamente
    instr_gen = prueba_base;
    test_gen_mbx.put(instr_gen);
    $display("[%g]  Test: prueba_base lanzada", $time);

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