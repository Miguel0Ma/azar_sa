defmodule Servidor.Conexion do
  @moduledoc """
  Gestiona la conexión entre nodos BEAM del sistema RIO.

  El servidor corre en un nodo con nombre (ej: server@DESKTOP-ABC).
  Los clientes se conectan a ese nodo; al hacerlo, el registro :global
  se comparte automáticamente y todos los GenServer.call/2 se enrutan
  al nodo correcto sin cambiar nada de la lógica de negocio.
  """

  @doc """
  Solicita el nombre del nodo servidor y establece la conexión.
  Si el nodo no tiene nombre (modo local), omite la conexión.
  Retorna :ok o :error.
  """
  def conectar do
    if Node.alive?() do
      IO.puts("  Nodo actual : #{Node.self()}")

      nodo_str =
        IO.gets("  Nodo servidor (Enter para modo local): ")
        |> String.trim()

      if nodo_str == "" do
        IO.puts("  Modo local activado.\n")
        :ok
      else
        intentar_conectar(String.to_atom(nodo_str))
      end
    else
      # Nodo sin nombre → modo local, sin red
      IO.puts("  Modo local (inicia con --sname para modo distribuido).\n")
      :ok
    end
  end

  @doc "Retorna true si este nodo está conectado a al menos otro nodo."
  def conectado?, do: Node.list() != []

  # ── Privado ──────────────────────────────────────────────────────────────

  defp intentar_conectar(nodo) do
    IO.puts("  Conectando a #{nodo}...")

    case Node.connect(nodo) do
      true ->
        IO.puts("  ✔  Conectado correctamente.\n")
        :ok

      false ->
        IO.puts("  ✘  No se pudo conectar. Verifique que:")
        IO.puts("     • El servidor esté corriendo con: iex --sname server -S mix")
        IO.puts("     • Ambos equipos estén en la misma red")
        IO.puts("     • El nombre del nodo sea correcto\n")
        conectar()

      :ignored ->
        IO.puts("  ✘  Distribuición desactivada. Inicia con: iex --sname <nombre> -S mix\n")
        :error
    end
  end
end
