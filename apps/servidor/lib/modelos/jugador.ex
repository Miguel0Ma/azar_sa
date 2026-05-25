defmodule Servidor.Modelos.Jugador do
  @derive Jason.Encoder
  defstruct [:cedula, :nombre, :password, :tarjeta_credito,
             historial_compras: [], notificaciones: []]
end
