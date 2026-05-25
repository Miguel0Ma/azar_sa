defmodule ClienteAdmin do
  @moduledoc "Punto de entrada de la aplicación Cliente Administrador — RIO."

  def main do
    IO.puts("""
    ╔══════════════════════════════════════╗
    ║       RIO — ADMINISTRACIÓN           ║
    ╚══════════════════════════════════════╝
    """)

    case Servidor.Conexion.conectar() do
      :ok    -> login()
      :error -> IO.puts("No se pudo conectar al servidor. Saliendo.")
    end
  end

  # ── Login ────────────────────────────────────────────────────────────────

  defp login do
    IO.puts("--- INICIO DE SESIÓN ---")
    usuario  = IO.gets("Usuario: ")    |> String.trim()
    password = IO.gets("Contraseña: ") |> String.trim()

    case Servidor.ServidorAutenticacionAdmin.login(usuario, password) do
      {:ok, admin} ->
        IO.puts("\n✔  Bienvenido, #{admin["nombre"]}!\n")
        ClienteAdmin.Menu.iniciar(admin)

      {:error, msg} ->
        IO.puts("\n✘  #{msg}. Intente de nuevo.\n")
        login()
    end
  end
end
