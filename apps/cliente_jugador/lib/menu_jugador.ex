defmodule ClienteJugador.MenuJugador do

  # ── Pantalla de bienvenida / login ────────────────────────────────────────
  def principal do
    IO.puts("""

    ╔══════════════════════════════════════╗
    ║         BIENVENIDO A RIO             ║
    ║     Juegos y Sorteos Oficiales       ║
    ╠══════════════════════════════════════╣
    ║  1. Iniciar sesión                   ║
    ║  2. Registrarse                      ║
    ║  0. Salir                            ║
    ╚══════════════════════════════════════╝
    """)

    case IO.gets("Seleccione una opción: ") |> String.trim() do
      "1" -> iniciar_sesion()
      "2" -> registrarse()
      "0" -> IO.puts("¡Hasta pronto!")
      _   -> IO.puts("Opción inválida."); principal()
    end
  end

  # ── Registro ──────────────────────────────────────────────────────────────
  defp registrarse do
    IO.puts("\n--- REGISTRO DE NUEVO JUGADOR ---")
    nombre  = IO.gets("Nombre completo: ")                          |> String.trim()
    cedula  = IO.gets("Cédula o documento: ")                       |> String.trim()
    pass    = IO.gets("Contraseña: ")                               |> String.trim()
    tarjeta = IO.gets("Número de tarjeta de crédito (simulada): ")  |> String.trim()

    case Servidor.ServidorAutenticacion.registrar(nombre, cedula, pass, tarjeta) do
      :ok           -> IO.puts("\n✔  Registro exitoso. Ya puedes iniciar sesión.")
      {:error, msg} -> IO.puts("\n✘  #{msg}")
    end

    principal()
  end

  # ── Login ─────────────────────────────────────────────────────────────────
  defp iniciar_sesion do
    IO.puts("\n--- INICIAR SESIÓN ---")
    cedula = IO.gets("Cédula: ")    |> String.trim()
    pass   = IO.gets("Contraseña: ") |> String.trim()

    case Servidor.ServidorAutenticacion.login(cedula, pass) do
      {:ok, jugador} ->
        IO.puts("\n✔  Bienvenido, #{jugador.nombre}!")
        menu_jugador(jugador)
      {:error, msg} ->
        IO.puts("\n✘  #{msg}")
        principal()
    end
  end

  # ── Menú principal del jugador (loop) ────────────────────────────────────
  defp menu_jugador(jugador) do
    IO.puts("""


      RIO — Hola, #{String.pad_trailing(jugador.nombre, 22)}
    ╠══════════════════════════════════════╣
    ║  SORTEOS                             ║
    ║   1. Ver sorteos disponibles         ║
    ║   2. Ver números disponibles         ║
    ╠══════════════════════════════════════╣
    ║  COMPRAS                             ║
    ║   3. Comprar billete / fracciones    ║
    ║   4. Historial de compras            ║
    ║   5. Devolver compra                 ║
    ╠══════════════════════════════════════╣
    ║  MI CUENTA                           ║
    ║   6. Premios obtenidos               ║
    ║   7. Balance personal                ║
    ║   8. Notificaciones                  ║
    ╠══════════════════════════════════════╣
    ║   0. Cerrar sesión                   ║
    ╚══════════════════════════════════════╝
    """)

    case IO.gets("Seleccione una opción: ") |> String.trim() do
      "1" -> ver_sorteos_disponibles(jugador)
      "2" -> ver_numeros_disponibles(jugador)
      "3" -> comprar(jugador)
      "4" -> historial(jugador)
      "5" -> devolver(jugador)
      "6" -> premios_obtenidos(jugador)
      "7" -> balance_personal(jugador)
      "8" -> notificaciones(jugador)
      "0" -> IO.puts("Sesión cerrada."); principal()
      _   -> IO.puts("Opción inválida."); menu_jugador(jugador)
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # SORTEOS
  # ══════════════════════════════════════════════════════════════════════════

  defp ver_sorteos_disponibles(jugador) do
    IO.puts("\n--- SORTEOS DISPONIBLES ---")

    disponibles =
      Servidor.Almacenamiento.listar_sorteos()
      |> Enum.filter(&(&1.estado == "pendiente"))

    if Enum.empty?(disponibles) do
      IO.puts("No hay sorteos disponibles en este momento.")
    else
      Enum.each(disponibles, fn s ->
        precio_frac = div(s.valor_billete, s.cant_fracciones)
        IO.puts("\n  ID: #{s.id} | #{s.nombre} | Fecha: #{s.fecha}")
        IO.puts("  Billete completo: $#{s.valor_billete} | Fracción: $#{precio_frac} | Total billetes: #{s.cant_billetes}")
        premios = Map.get(s, :premios, [])
        unless Enum.empty?(premios) do
          IO.puts("  Premios:")
          Enum.each(premios, fn p ->
            IO.puts("    • #{p.nombre}: $#{p.valor}")
          end)
        end
      end)
    end

    menu_jugador(jugador)
  end

  defp ver_numeros_disponibles(jugador) do
    IO.puts("\n--- NÚMEROS DISPONIBLES ---")
    id = IO.gets("ID del sorteo: ") |> String.trim()

    case Servidor.Almacenamiento.cargar_sorteo(id) do
      {:ok, sorteo} ->
        if sorteo.estado == "jugado" do
          IO.puts("Este sorteo ya fue jugado.")
        else
          billetes        = Map.get(sorteo, :billetes_vendidos, %{})
          cant_fracciones = sorteo.cant_fracciones

          IO.puts("\n  Sorteo: #{sorteo.nombre} | Billetes totales: #{sorteo.cant_billetes}")
          IO.puts("  Precio fracción: $#{div(sorteo.valor_billete, cant_fracciones)}\n")

          {completos, con_fracs} =
            Enum.reduce(0..(sorteo.cant_billetes - 1), {[], []}, fn i, {comp, frac} ->
              num_str = String.pad_leading("#{i}", 4, "0")
              fracs   = Map.get(billetes, num_str, %{})
              ocupadas = map_size(fracs)

              cond do
                ocupadas == 0 ->
                  {[num_str | comp], frac}
                ocupadas < cant_fracciones ->
                  libres = cant_fracciones - ocupadas
                  {comp, [{num_str, libres} | frac]}
                true ->
                  {comp, frac}
              end
            end)

          IO.puts("  Billetes completos disponibles (#{length(completos)}):")
          if Enum.empty?(completos) do
            IO.puts("    (ninguno)")
          else
            completos |> Enum.reverse() |> Enum.each(&IO.puts("    • ##{&1}"))
          end

          IO.puts("\n  Billetes con fracciones libres (#{length(con_fracs)}):")
          if Enum.empty?(con_fracs) do
            IO.puts("    (ninguno)")
          else
            con_fracs |> Enum.reverse() |> Enum.each(fn {num, libres} ->
              IO.puts("    • ##{num} — #{libres} fracción(es) disponible(s)")
            end)
          end
        end

      {:error, msg} -> IO.puts("\n✘  #{msg}")
    end

    menu_jugador(jugador)
  end

  # ══════════════════════════════════════════════════════════════════════════
  # COMPRAS
  # ══════════════════════════════════════════════════════════════════════════

  defp comprar(jugador) do
    IO.puts("\n--- COMPRAR BILLETE / FRACCIONES ---")
    id_sorteo  = IO.gets("ID del sorteo: ")             |> String.trim()
    num_billete = IO.gets("Número de billete (ej: 0042): ") |> String.trim()
    fracciones  = IO.gets("Cantidad de fracciones a comprar: ") |> String.trim() |> String.to_integer()

    case Servidor.ServidorSorteo.comprar_billete(id_sorteo, num_billete, jugador.cedula, fracciones) do
      :ok ->
        IO.puts("\n✔  Compra exitosa: #{fracciones} fracción(es) del billete ##{num_billete}.")
      {:error, msg} ->
        IO.puts("\n✘  #{msg}")
    end

    # Recargar jugador para tener historial actualizado
    jugador_actualizado = recargar_jugador(jugador)
    menu_jugador(jugador_actualizado)
  end

  defp historial(jugador) do
    IO.puts("\n--- HISTORIAL DE COMPRAS ---")
    # Recargar del disco para tener datos frescos
    jugador_fresco = recargar_jugador(jugador)
    compras = jugador_fresco.historial_compras

    if Enum.empty?(compras) do
      IO.puts("No tienes compras registradas.")
    else
      total = Enum.reduce(compras, 0, fn c, acc ->
        monto = c["monto_pagado"] || 0
        IO.puts("  • #{c["nombre_sorteo"]} | Billete ##{c["numero_billete"]} | #{c["fracciones"]} fracción(es) | $#{monto}")
        acc + monto
      end)
      IO.puts("\n  Total gastado: $#{total}")
    end

    menu_jugador(jugador_fresco)
  end

  defp devolver(jugador) do
    IO.puts("\n--- DEVOLVER COMPRA ---")
    IO.puts("⚠  Solo puedes devolver si el sorteo aún no se ha jugado.")
    id_sorteo   = IO.gets("ID del sorteo: ")             |> String.trim()
    num_billete = IO.gets("Número de billete a devolver: ") |> String.trim()

    case Servidor.ServidorSorteo.devolver_compra(id_sorteo, num_billete, jugador.cedula) do
      {:ok, cant} ->
        IO.puts("\n✔  Devueltas #{cant} fracción(es) del billete ##{num_billete}.")
      {:error, msg} ->
        IO.puts("\n✘  #{msg}")
    end

    jugador_actualizado = recargar_jugador(jugador)
    menu_jugador(jugador_actualizado)
  end

  # ══════════════════════════════════════════════════════════════════════════
  # MI CUENTA
  # ══════════════════════════════════════════════════════════════════════════

  defp premios_obtenidos(jugador) do
    IO.puts("\n--- MIS PREMIOS OBTENIDOS ---")

    ganados =
      Servidor.Almacenamiento.listar_sorteos()
      |> Enum.filter(&(&1.estado == "jugado"))
      |> Enum.flat_map(fn s ->
        premios  = Map.get(s, :premios, [])
        billetes = Map.get(s, :billetes_vendidos, %{})

        Enum.flat_map(premios, fn p ->
          ganador_num  = Map.get(p, :numero_ganador) || Map.get(p, "numero_ganador")
          fracs_billete = Map.get(billetes, ganador_num, %{})
          cedulas       = Map.values(fracs_billete)

          if jugador.cedula in cedulas do
            cant_frac   = Enum.count(cedulas, &(&1 == jugador.cedula))
            total_frac  = map_size(fracs_billete)
            valor_total = Map.get(p, :valor) || Map.get(p, "valor") || 0
            mi_parte    = div(valor_total * cant_frac, total_frac)
            nombre_p    = Map.get(p, :nombre) || Map.get(p, "nombre")
            [%{sorteo: s.nombre, premio: nombre_p, billete: ganador_num, monto: mi_parte}]
          else
            []
          end
        end)
      end)

    if Enum.empty?(ganados) do
      IO.puts("Aún no has ganado ningún premio.")
    else
      Enum.each(ganados, fn g ->
        IO.puts("  🏆 #{g.sorteo} | #{g.premio} | Billete ##{g.billete} | $#{g.monto}")
      end)
    end

    menu_jugador(jugador)
  end

  defp balance_personal(jugador) do
    IO.puts("\n--- BALANCE PERSONAL ---")
    jugador_fresco = recargar_jugador(jugador)

    total_gastado =
      Enum.reduce(jugador_fresco.historial_compras, 0, fn c, acc ->
        acc + (c["monto_pagado"] || 0)
      end)

    total_ganado =
      Servidor.Almacenamiento.listar_sorteos()
      |> Enum.filter(&(&1.estado == "jugado"))
      |> Enum.reduce(0, fn s, acc ->
        premios  = Map.get(s, :premios, [])
        billetes = Map.get(s, :billetes_vendidos, %{})

        ganancia_sorteo = Enum.reduce(premios, 0, fn p, inner ->
          ganador_num   = Map.get(p, :numero_ganador) || Map.get(p, "numero_ganador")
          fracs_billete = Map.get(billetes, ganador_num, %{})
          cedulas       = Map.values(fracs_billete)

          if jugador.cedula in cedulas do
            cant_frac  = Enum.count(cedulas, &(&1 == jugador.cedula))
            total_frac = map_size(fracs_billete)
            valor      = Map.get(p, :valor) || Map.get(p, "valor") || 0
            inner + div(valor * cant_frac, total_frac)
          else
            inner
          end
        end)

        acc + ganancia_sorteo
      end)

    diferencia = total_ganado - total_gastado

    IO.puts("\n  Total gastado en compras: $#{total_gastado}")
    IO.puts("  Total ganado en premios:  $#{total_ganado}")
    IO.puts("  ─────────────────────────────")
    if diferencia >= 0 do
      IO.puts("  GANANCIA NETA: $#{diferencia} 🎉")
    else
      IO.puts("  PÉRDIDA NETA:  $#{abs(diferencia)}")
    end

    menu_jugador(jugador_fresco)
  end

  defp notificaciones(jugador) do
    IO.puts("\n--- MIS NOTIFICACIONES ---")
    jugador_fresco = recargar_jugador(jugador)

    if Enum.empty?(jugador_fresco.notificaciones) do
      IO.puts("No tienes notificaciones.")
    else
      jugador_fresco.notificaciones
      |> Enum.with_index(1)
      |> Enum.each(fn {msg, i} -> IO.puts("  #{i}. #{msg}") end)
    end

    menu_jugador(jugador_fresco)
  end

  # ══════════════════════════════════════════════════════════════════════════
  # HELPER
  # ══════════════════════════════════════════════════════════════════════════

  defp recargar_jugador(jugador) do
    case Servidor.Almacenamiento.cargar_jugador(jugador.cedula) do
      {:ok, fresco} -> fresco
      _             -> jugador
    end
  end
end
