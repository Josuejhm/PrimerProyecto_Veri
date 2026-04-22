//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ScoreBoard: Lleva el estado completo del comportamiento de la prueba y genera reportes.                             //
//                                                                                                                      //
// Fuentes de información:                                                                                              //
//   - chkr_sb_mbx   : Recibe transacciones VERIFICADAS del Checker (completado, overflow, underflow, reset)          //
//   - agnt_sb_mbx   : Recibe NOTIFICACIONES del Agente de cada transacción enviada al DUT                           //
//   - test_sb_mbx   : Recibe órdenes del Test (retardo_promedio, reporte)                                            //
//                                                                                                                      //
// El SB mantiene estadísticas separadas:                                                                               //
//   scoreboard[]      → cola de todas las transacciones verificadas por el Checker                                    //
//   trans_esperadas[] → cola de notificaciones del Agente (lo que se esperaba)                                       //
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class score_board #(parameter width=16);

  // --- Mailboxes ---
  trans_sb_mbx          chkr_sb_mbx;   // Del Checker al ScoreBoard (transacciones verificadas)
  trans_sb_mbx          agnt_sb_mbx;   // Del Agente al ScoreBoard  (notificaciones esperadas)
  comando_test_sb_mbx   test_sb_mbx;   // Del Test al ScoreBoard    (órdenes de reporte)

  // --- Colas internas ---
  trans_sb #(.width(width))  scoreboard[$];        // Transacciones procesadas/verificadas
  trans_sb #(.width(width))  trans_esperadas[$];   // Transacciones esperadas (del Agente)
  trans_sb #(.width(width))  auxiliar_array[$];    // Auxiliar para reporte sin destruir la cola
  trans_sb #(.width(width))  transaccion_entrante; // Temporal para lectura de mailbox
  trans_sb #(.width(width))  auxiliar_trans;

  // --- Estadísticas ---
  shortreal retardo_promedio;
  int tamano_sb             = 0;
  int transacciones_completadas = 0;  // Transacciones con completado=1 (verificadas por Checker)
  int transacciones_overflow    = 0;  // Overflows detectados
  int transacciones_underflow   = 0;  // Underflows detectados
  int transacciones_reset       = 0;  // Resets detectados
  int retardo_total             = 0;
  int total_esperadas           = 0;  // Notificaciones recibidas del Agente

  solicitud_sb orden;

  // -----------------------------------------------------------------------
  // run: procesa los tres mailboxes en cada ciclo de evaluación
  // -----------------------------------------------------------------------
  task run;
    $display("[%g] El Score Board fue inicializado", $time);

    forever begin
      #5  // Período de evaluación del ScoreBoard

      // --------------------------------------------------------------------
      // Prioridad 1: Procesar transacciones verificadas del Checker
      // --------------------------------------------------------------------
      if (chkr_sb_mbx.num() > 0) begin
        chkr_sb_mbx.get(transaccion_entrante);
        transaccion_entrante.print("Score Board: transacción recibida del Checker");

        // Actualizar estadísticas según el tipo de resultado
        if (transaccion_entrante.completado) begin
          retardo_total += transaccion_entrante.latencia;
          transacciones_completadas++;
        end
        if (transaccion_entrante.overflow)   transacciones_overflow++;
        if (transaccion_entrante.underflow)  transacciones_underflow++;
        if (transaccion_entrante.reset)      transacciones_reset++;

        scoreboard.push_back(transaccion_entrante);

      // --------------------------------------------------------------------
      // Prioridad 2: Procesar notificaciones del Agente
      // --------------------------------------------------------------------
      end else if (agnt_sb_mbx.num() > 0) begin
        agnt_sb_mbx.get(transaccion_entrante);
        total_esperadas++;
        transaccion_entrante.print("Score Board: notificación recibida del Agente");
        trans_esperadas.push_back(transaccion_entrante);

      // --------------------------------------------------------------------
      // Prioridad 3: Procesar órdenes del Test
      // --------------------------------------------------------------------
      end else begin
        if (test_sb_mbx.num() > 0) begin
          test_sb_mbx.get(orden);

          case (orden)

            // ----------------------------------------------------------------
            // Calcula el retardo promedio de transacciones completadas
            // ----------------------------------------------------------------
            retardo_promedio: begin
              $display("Score Board: Recibida Orden Retardo_Promedio");
              if (transacciones_completadas > 0) begin
                retardo_promedio = real'(retardo_total) / real'(transacciones_completadas);
                $display("[%g] Score Board: retardo promedio = %0.3f ciclos", $time, retardo_promedio);
              end else begin
                $display("[%g] Score Board: sin transacciones completadas para calcular retardo", $time);
              end
            end

            // ----------------------------------------------------------------
            // Genera un reporte completo del estado de la prueba
            // ----------------------------------------------------------------
            reporte: begin
              $display("Score Board: Recibida Orden Reporte");
              $display("============================================================");
              $display("   REPORTE DEL SCOREBOARD  [%g]", $time);
              $display("============================================================");
              $display("  Notificaciones del Agente  (esperadas) : %0d", total_esperadas);
              $display("  Transacciones completadas  (Checker)   : %0d", transacciones_completadas);
              $display("  Overflows detectados                   : %0d", transacciones_overflow);
              $display("  Underflows detectados                  : %0d", transacciones_underflow);
              $display("  Resets detectados                      : %0d", transacciones_reset);
              $display("------------------------------------------------------------");
              $display("  Detalle de transacciones verificadas:");

              tamano_sb = this.scoreboard.size();
              for (int i = 0; i < tamano_sb; i++) begin
                auxiliar_trans = scoreboard.pop_front;
                auxiliar_trans.print("  SB_Verificado:");
                auxiliar_array.push_back(auxiliar_trans);
              end
              scoreboard    = auxiliar_array;
              auxiliar_array = {};

              $display("------------------------------------------------------------");
              $display("  Detalle de notificaciones del Agente:");
              tamano_sb = this.trans_esperadas.size();
              for (int i = 0; i < tamano_sb; i++) begin
                auxiliar_trans = trans_esperadas.pop_front;
                auxiliar_trans.print("  SB_Esperado:");
                auxiliar_array.push_back(auxiliar_trans);
              end
              trans_esperadas = auxiliar_array;
              auxiliar_array  = {};

              $display("============================================================");
            end

          endcase
        end
      end

    end // forever
  endtask

endclass
