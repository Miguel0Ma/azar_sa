defmodule ClienteJugador do
  @moduledoc "Punto de entrada de la aplicación Cliente Jugador — RIO."

  def main do
    IO.puts("""
    ╔══════════════════════════════════════╗
    ║         BIENVENIDO A RIO             ║
    ╚══════════════════════════════════════╝
    """)

    case Servidor.Conexion.conectar() do
      :ok    -> ClienteJugador.MenuJugador.principal()
      :error -> IO.puts("No se pudo conectar al servidor. Saliendo.")
    end
  end
end
