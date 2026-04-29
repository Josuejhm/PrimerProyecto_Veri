// ScoreBoard: acumula los resultados de la prueba y genera el reporte final.
// Recibe eventos del Checker (transacciones verificadas) y del Agente (transacciones esperadas).
// El flag en_reset evita contar multiples mensajes de reset como eventos separados
// cuando el FIFO tenia varios datos al momento del reset.
class score_board #(parameter width=16);

  trans_sb_mbx          chkr_sb_mbx;
  trans_sb_mbx          agnt_sb_mbx;
  comando_test_sb_mbx   test_sb_mbx;

  trans_sb #(.width(width))  scoreboard[$];
  trans_sb #(.width(width))  trans_esperadas[$];
  trans_sb #(.width(width))  auxiliar_array[$];
  trans_sb #(.width(width))  transaccion_entrante;
  trans_sb #(.width(width))  auxiliar_trans;

  shortreal retardo_promedio;
  int tamano_sb                 = 0;
  int transacciones_completadas = 0;
  int transacciones_overflow    = 0;
  int transacciones_underflow   = 0;
  int transacciones_reset       = 0;
  int retardo_total             = 0;
  int total_esperadas           = 0;
  int errores_checker           = 0;
  bit en_reset                  = 0;
  mailbox #(int) error_mbx;

  solicitud_sb orden;

  task run;
    $display("[%g] El Score Board fue inicializado", $time);

    forever begin
      #5
      if (chkr_sb_mbx.num() > 0) begin
        chkr_sb_mbx.get(transaccion_entrante);
        transaccion_entrante.print("Score Board: transacción recibida del Checker");
        if (transaccion_entrante.completado) begin
          retardo_total += transaccion_entrante.latencia;
          transacciones_completadas++;
        end
        if (transaccion_entrante.overflow)  transacciones_overflow++;
        if (transaccion_entrante.underflow) transacciones_underflow++;
        // Un reset puede generar un mensaje por cada dato en el FIFO;
        // solo se cuenta el primero como un evento de reset
        if (transaccion_entrante.reset) begin
          if (!en_reset) begin
            transacciones_reset++;
            en_reset = 1;
          end
        end else begin
          en_reset = 0;
        end
        scoreboard.push_back(transaccion_entrante);

      end else if (agnt_sb_mbx.num() > 0) begin
        agnt_sb_mbx.get(transaccion_entrante);
        total_esperadas++;
        transaccion_entrante.print("Score Board: notificación recibida del Agente");
        trans_esperadas.push_back(transaccion_entrante);

      end else if (error_mbx != null && error_mbx.num() > 0) begin
        int dummy;
        error_mbx.get(dummy);
        errores_checker++;
      end else begin
        if (test_sb_mbx.num() > 0) begin
          test_sb_mbx.get(orden);
          case (orden)

            retardo_promedio: begin
              $display("Score Board: Recibida Orden Retardo_Promedio");
              if (transacciones_completadas > 0) begin
                retardo_promedio = real'(retardo_total) / real'(transacciones_completadas);
                $display("[%g] Score Board: retardo promedio = %0.3f ciclos", $time, retardo_promedio);
              end else begin
                $display("[%g] Score Board: sin transacciones completadas para calcular retardo", $time);
              end
            end

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
    end
  endtask

endclass
