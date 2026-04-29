// Ambiente: instancia y conecta todos los componentes del testbench.
// El flujo de datos entre componentes es:
//   Test → Generator → Agent → Driver → DUT
//                    ↓               ↑
//                ScoreBoard ← Checker ← Monitor
//
// La interface virtual se asigna desde test_bench despues de new()
// porque _if es null en el momento de la construccion.
class ambiente #(parameter width = 16, parameter depth = 8);

  generator   #(.width(width), .depth(depth)) generator_inst;
  agent       #(.width(width), .depth(depth)) agent_inst;
  driver      #(.width(width))                driver_inst;
  monitor     #(.width(width))                monitor_inst;
  checker_c   #(.width(width), .depth(depth)) checker_inst;
  score_board #(.width(width))                scoreboard_inst;

  virtual fifo_if #(.width(width)) _if;

  // Mailboxes entre componentes
  comando_test_agent_mbx   test_gen_mbx;   // Test → Generator
  trans_fifo_mbx           gen_agnt_mbx;   // Generator → Agent
  trans_fifo_mbx           agnt_drv_mbx;   // Agent → Driver
  trans_fifo_mbx           mon_chkr_mbx;   // Monitor → Checker
  trans_sb_mbx             chkr_sb_mbx;    // Checker → ScoreBoard
  trans_sb_mbx             agnt_sb_mbx;    // Agent → ScoreBoard
  comando_test_sb_mbx      test_sb_mbx;    // Test → ScoreBoard
  mailbox #(int)           error_mbx;      // Checker → ScoreBoard (errores del DUT)

  function new();
    test_gen_mbx  = new();
    error_mbx     = new();
    gen_agnt_mbx  = new();
    agnt_drv_mbx  = new();
    mon_chkr_mbx  = new();
    chkr_sb_mbx   = new();
    agnt_sb_mbx   = new();
    test_sb_mbx   = new();

    generator_inst  = new();
    agent_inst      = new();
    driver_inst     = new();
    monitor_inst    = new();
    checker_inst    = new();
    scoreboard_inst = new();

    generator_inst.test_gen_mbx  = test_gen_mbx;
    generator_inst.gen_agnt_mbx  = gen_agnt_mbx;

    agent_inst.gen_agnt_mbx  = gen_agnt_mbx;
    agent_inst.agnt_drv_mbx  = agnt_drv_mbx;
    agent_inst.agnt_sb_mbx   = agnt_sb_mbx;

    driver_inst.agnt_drv_mbx  = agnt_drv_mbx;

    monitor_inst.mon_chkr_mbx  = mon_chkr_mbx;

    checker_inst.mon_chkr_mbx  = mon_chkr_mbx;
    checker_inst.chkr_sb_mbx   = chkr_sb_mbx;
    checker_inst.error_mbx     = error_mbx;

    scoreboard_inst.chkr_sb_mbx  = chkr_sb_mbx;
    scoreboard_inst.agnt_sb_mbx  = agnt_sb_mbx;
    scoreboard_inst.test_sb_mbx  = test_sb_mbx;
    scoreboard_inst.error_mbx    = error_mbx;
  endfunction

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
