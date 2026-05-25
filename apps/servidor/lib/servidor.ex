defmodule Servidor do
  @moduledoc """
  Núcleo del sistema RIO.

  Este módulo actúa como fachada del servidor: agrupa los componentes
  principales que forman la aplicación servidor del sistema distribuido.

  Componentes activos al iniciar:
    - Servidor.SupervisorSorteos       → DynamicSupervisor que gestiona un
                                         GenServer por cada sorteo activo.
    - Servidor.ServidorSorteo          → GenServer especializado por sorteo
                                         (compras, premios, ejecución).
    - Servidor.ServidorAutenticacion   → Registro y login de jugadores.
    - Servidor.ServidorAutenticacionAdmin → Login de administradores.
    - Servidor.Almacenamiento          → Persistencia en archivos JSON.
    - Servidor.Bitacora                → Log en pantalla y en bitacora.txt.
  """
end
