// Test: lanza prueba_base y espera el reporte final.
// Los plusargs pasados al ejecutable controlan el escenario de prueba.
// Sin plusargs se ejecuta la prueba general con valores por defecto.
// Ver comando.sh para los plusargs de cada caso de esquina.
class test #(parameter width = 16, parameter depth = 8);

  comando_test_sb_mbx    test_sb_mbx;
  comando_test_agent_mbx test_gen_mbx;

  parameter max_retardo = 8;
  int tiempo_limite;

  instrucciones_agente instr_gen;
  solicitud_sb         instr_sb;

  ambiente #(.depth(depth), .width(width)) ambiente_inst;
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
    // Calcular el tiempo limite leyendo los mismos plusargs que usa el generador
    int n_trans_max_arg;
    int retardo_max_arg;
    int prefijo_arg;
    int alternancia_arg;

    n_trans_max_arg = 32; void'($value$plusargs("n_trans_max=%d",  n_trans_max_arg));
    retardo_max_arg = 7;  void'($value$plusargs("retardo_max=%d",  retardo_max_arg));
    prefijo_arg     = 0;  void'($value$plusargs("prefijo=%d",       prefijo_arg));
    alternancia_arg = 0;  void'($value$plusargs("alternancia=%d",   alternancia_arg));

    if (alternancia_arg)
      tiempo_limite = (depth + n_trans_max_arg + prefijo_arg) * retardo_max_arg * 20 + 1000;
    else
      tiempo_limite = (n_trans_max_arg + prefijo_arg) * retardo_max_arg * 20 + 1000;

    $display("[%g]  El Test fue inicializado", $time);
    $display("[%g]  Test: FIFO depth=%0d width=%0d max_retardo=%0d tiempo_limite=%0d",
             $time, depth, width, max_retardo, tiempo_limite);

    fork
      ambiente_inst.run();
    join_none

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
