defmodule Servidor.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Servidor.SupervisorSorteos,
      Servidor.ServidorAutenticacion,
      Servidor.ServidorAutenticacionAdmin
    ]

    opts = [strategy: :one_for_one, name: Servidor.Supervisor]

    # Guardamos el resultado del arranque en una variable
    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        Servidor.Almacenamiento.revivir_sorteos_existentes()

        IO.puts("""
        ╔══════════════════════════════════════════╗
        ║         SERVIDOR RIO — EN LÍNEA          ║
        ╠══════════════════════════════════════════╣
        ║  Nodo: #{String.pad_trailing("#{Node.self()}", 34)}║
        ║                                          ║
        ║  Comparte este nombre con los clientes   ║
        ║  para conectarse en modo distribuido.    ║
        ╚══════════════════════════════════════════╝
        """)

        {:ok, pid}

      error ->
        error
    end
  end
end
