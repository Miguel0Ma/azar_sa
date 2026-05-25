defmodule Servidor.Bitacora do
  def registrar_operacion(solicitud, resultado) do
    # 1. Obtener la fecha y hora actual del sistema en formato legible
    {:ok, fecha_hora} = DateTime.now("Etc/UTC")
    fecha_hora_str = Calendar.strftime(fecha_hora, "%Y-%m-%d %H:%M:%S")

    # 2. Formatear la línea según lo exige el PDF: (fecha - hora - solicitud y resultado)
    linea_log = "[#{fecha_hora_str}] - Solicitud: #{solicitud} - Resultado: #{resultado}\n"

    # 3. Mostrar en pantalla (Consola del Servidor)
    IO.write(linea_log)

    # 4. Guardar en el archivo de texto físico (bitacora.txt) modo 'append' (añadir al final)
    File.write("bitacora.txt", linea_log, [:append])
  end
end
