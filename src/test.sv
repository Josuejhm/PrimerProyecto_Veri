///////////////////////////////////
// Módulo para correr la prueba  //
///////////////////////////////////

// El Test controla el flujo de la simulación:
//   - Envía instrucciones de escenario al Generador via test_gen_mbx
//   - Envía órdenes de reporte al ScoreBoard via test_sb_mbx
//
// Las instrucciones son del tipo instrucciones_agente:
//   llenado_aleatorio, trans_aleatoria, trans_especifica, sec_trans_aleatorias

class test #(parameter width = 16, parameter depth = 8);

  // --- Mailboxes propios del Test ---
  comando_test_sb_mbx    test_sb_mbx;   // Test → ScoreBoard
  comando_test_agent_mbx test_gen_mbx;  // Test → Generator (antes: test_agent_mbx)

  // --- Parámetros de la prueba ---
  parameter num_transacciones = depth;  // Por defecto igual a la profundidad del FIFO
  parameter max_retardo       = 4;

  // --- Variables auxiliares ---
  instrucciones_agente instr_gen;   // Instrucción para el Generador
  solicitud_sb         instr_sb;    // Orden para el ScoreBoard

  // --- Ambiente ---
  ambiente #(.depth(depth), .width(width)) ambiente_inst;

  // --- Interface al DUT ---
  virtual fifo_if #(.width(width)) _if;

  // -----------------------------------------------------------------------
  // Constructor: inicializa mailboxes, ambiente y conecta referencias
  // -----------------------------------------------------------------------
  function new;
    // Crear mailboxes del Test
    test_sb_mbx  = new();
    test_gen_mbx = new();

    // Crear e inicializar el ambiente
    ambiente_inst = new();
    ambiente_inst._if = _if;

    // Compartir mailboxes del Test con el ambiente
    ambiente_inst.test_gen_mbx              = test_gen_mbx;
    ambiente_inst.generator_inst.test_gen_mbx = test_gen_mbx;
    ambiente_inst.test_sb_mbx               = test_sb_mbx;
    ambiente_inst.scoreboard_inst.test_sb_mbx = test_sb_mbx;

    // Configurar parámetros del Generador
    ambiente_inst.generator_inst.num_transacciones = num_transacciones;
    ambiente_inst.generator_inst.max_retardo       = max_retardo;
  endfunction

  // -----------------------------------------------------------------------
  // run: secuencia de prueba principal
  // -----------------------------------------------------------------------
  task run;
    $display("[%g]  El Test fue inicializado", $time);

    // Lanzar el ambiente (todos los componentes en paralelo)
    fork
      ambiente_inst.run();
    join_none

    // ------------------------------------------------------------------
    // Instrucción 1: Llenar y vaciar el FIFO
    // Verifica el comportamiento con FIFO lleno → vacío
    // ------------------------------------------------------------------
    instr_gen = llenado_aleatorio;
    test_gen_mbx.put(instr_gen);
    $display("[%g]  Test: Enviada instruccion 1 (llenado_aleatorio, %0d transacciones)", $time, num_transacciones);

    // ------------------------------------------------------------------
    // Instrucción 2: Transacción completamente aleatoria
    // Cubre un caso general aleatorio
    // ------------------------------------------------------------------
    instr_gen = trans_aleatoria;
    test_gen_mbx.put(instr_gen);
    $display("[%g]  Test: Enviada instruccion 2 (trans_aleatoria)", $time);

    // ------------------------------------------------------------------
    // Instrucción 3: Transacción específica (caso esquina)
    // Se configura el Generador antes de enviar la instrucción
    // ------------------------------------------------------------------
    ambiente_inst.generator_inst.ret_spec  = 3;
    ambiente_inst.generator_inst.tpo_spec  = escritura;
    ambiente_inst.generator_inst.dto_spec  = {width/4{4'h5}};  // Patrón: 0x5555
    instr_gen = trans_especifica;
    test_gen_mbx.put(instr_gen);
    $display("[%g]  Test: Enviada instruccion 3 (trans_especifica, dato=0x%0h)", $time, {width/4{4'h5}});

    // ------------------------------------------------------------------
    // Instrucción 4: Secuencia de transacciones aleatorias
    // Cubre casos mixtos de lecturas y escrituras
    // ------------------------------------------------------------------
    instr_gen = sec_trans_aleatorias;
    test_gen_mbx.put(instr_gen);
    $display("[%g]  Test: Enviada instruccion 4 (sec_trans_aleatorias, %0d transacciones)", $time, num_transacciones);

    // ------------------------------------------------------------------
    // Esperar que se procesen todas las transacciones
    // ------------------------------------------------------------------
    #10000
    $display("[%g]  Test: Se alcanza el tiempo límite de la prueba", $time);

    // ------------------------------------------------------------------
    // Solicitar reporte final al ScoreBoard
    // ------------------------------------------------------------------
    instr_sb = retardo_promedio;
    test_sb_mbx.put(instr_sb);

    instr_sb = reporte;
    test_sb_mbx.put(instr_sb);

    #20
    $finish;
  endtask

endclass
