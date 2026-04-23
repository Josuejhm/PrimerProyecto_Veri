///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Ambiente: Conecta todos los componentes del testbench según la arquitectura estándar.                                    //
//                                                                                                                           //
// Componentes instanciados:                                                                                                 //
//   generator_inst  → Genera secuencias de transacciones a partir de instrucciones del Test                               //
//   agent_inst      → Recibe del Generador, envía al Driver y notifica al ScoreBoard                                      //
//   driver_inst     → Conduce las entradas del DUT (FIFO) a nivel de pines                                               //
//   monitor_inst    → Observa las señales del DUT y reporta al Checker                                                    //
//   checker_inst    → Verifica el comportamiento del DUT usando un modelo de referencia                                   //
//   scoreboard_inst → Lleva estadísticas y genera reportes de la prueba                                                   //
//                                                                                                                           //
// Mailboxes (flujo de datos):                                                                                               //
//   test_gen_mbx  : Test       → Generator   (instrucciones_agente)                                                       //
//   gen_agnt_mbx  : Generator  → Agent       (trans_fifo)                                                                 //
//   agnt_drv_mbx  : Agent      → Driver      (trans_fifo)                                                                 //
//   mon_chkr_mbx  : Monitor    → Checker     (trans_fifo)                                                                 //
//   chkr_sb_mbx   : Checker    → ScoreBoard  (trans_sb)                                                                   //
//   agnt_sb_mbx   : Agent      → ScoreBoard  (trans_sb, notificaciones)                                                   //
//   test_sb_mbx   : Test       → ScoreBoard  (solicitud_sb, órdenes de reporte)                                           //
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class ambiente #(parameter width = 16, parameter depth = 8);

  // --- Componentes del ambiente ---
  generator   #(.width(width), .depth(depth)) generator_inst;
  agent       #(.width(width), .depth(depth)) agent_inst;
  driver      #(.width(width))                driver_inst;
  monitor     #(.width(width))                monitor_inst;
  checker_c   #(.width(width), .depth(depth)) checker_inst;
  score_board #(.width(width))                scoreboard_inst;

  // --- Interface virtual hacia el DUT ---
  virtual fifo_if #(.width(width)) _if;

  // --- Mailboxes ---
  // Test → Generator: instrucciones de alto nivel
  comando_test_agent_mbx   test_gen_mbx;

  // Generator → Agent: transacciones individuales
  trans_fifo_mbx           gen_agnt_mbx;

  // Agent → Driver: estímulos para el DUT
  trans_fifo_mbx           agnt_drv_mbx;

  // Monitor → Checker: observaciones del DUT
  trans_fifo_mbx           mon_chkr_mbx;

  // Checker → ScoreBoard: resultados de verificación
  trans_sb_mbx             chkr_sb_mbx;

  // Agent → ScoreBoard: notificaciones de transacciones esperadas
  trans_sb_mbx             agnt_sb_mbx;

  // Test → ScoreBoard: órdenes de reporte
  comando_test_sb_mbx      test_sb_mbx;

  // Checker → ScoreBoard: notificaciones de error del DUT
  mailbox #(int)           error_mbx;

  // -----------------------------------------------------------------------
  // Constructor: instancia mailboxes y componentes, luego los conecta
  // -----------------------------------------------------------------------
  function new();

    // -- Instanciación de mailboxes --
    test_gen_mbx  = new();
    error_mbx     = new();
    gen_agnt_mbx  = new();
    agnt_drv_mbx  = new();
    mon_chkr_mbx  = new();
    chkr_sb_mbx   = new();
    agnt_sb_mbx   = new();
    test_sb_mbx   = new();

    // -- Instanciación de componentes --
    generator_inst  = new();
    agent_inst      = new();
    driver_inst     = new();
    monitor_inst    = new();
    checker_inst    = new();
    scoreboard_inst = new();

    // -- Conexión del Generator --
    generator_inst.test_gen_mbx  = test_gen_mbx;
    generator_inst.gen_agnt_mbx  = gen_agnt_mbx;

    // -- Conexión del Agent --
    agent_inst.gen_agnt_mbx  = gen_agnt_mbx;
    agent_inst.agnt_drv_mbx  = agnt_drv_mbx;
    agent_inst.agnt_sb_mbx   = agnt_sb_mbx;

    // -- Conexión del Driver (la interface se conecta en el test_bench) --
    driver_inst.vif           = _if;
    driver_inst.agnt_drv_mbx  = agnt_drv_mbx;

    // -- Conexión del Monitor --
    monitor_inst.vif           = _if;
    monitor_inst.mon_chkr_mbx  = mon_chkr_mbx;

    // -- Conexión del Checker --
    checker_inst.mon_chkr_mbx  = mon_chkr_mbx;
    checker_inst.chkr_sb_mbx   = chkr_sb_mbx;
    checker_inst.error_mbx     = error_mbx;

    // -- Conexión del ScoreBoard --
    scoreboard_inst.chkr_sb_mbx  = chkr_sb_mbx;
    scoreboard_inst.agnt_sb_mbx  = agnt_sb_mbx;
    scoreboard_inst.test_sb_mbx  = test_sb_mbx;
    scoreboard_inst.error_mbx    = error_mbx;

  endfunction

  // -----------------------------------------------------------------------
  // run: lanza todos los componentes en paralelo
  // -----------------------------------------------------------------------
  virtual task run();
    $display("[%g]  El ambiente fue inicializado", $time);
    fork
      generator_inst.run();
      agent_inst.run();
      driver_inst.run();
      monitor_inst.run();
      checker_inst.run();
      scoreboard_inst.run();
    join_none
  endtask

endclass