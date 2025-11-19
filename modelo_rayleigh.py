import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from scipy.optimize import curve_fit
import pyodbc
import warnings

# Ignorar advertencias de compatibilidad de pandas/SQLAlchemy para limpiar la salida
warnings.filterwarnings("ignore")

# 1. CONFIGURACIÓN DE CONEXIÓN A SQL SERVER
server = "LUIS"
database = "SoftwareFactory_DW"
driver = "{ODBC Driver 17 for SQL Server}"  # O 'SQL Server' si es antiguo

conn_str = (
    f"DRIVER={driver};SERVER={server};DATABASE={database};Trusted_Connection=yes;"
)

print("Conectando a la base de datos...")

try:
    conn = pyodbc.connect(conn_str)

    # 2. EXTRAER DATOS
    query_simple = """
    SELECT 
        dp.NombreProyecto,
        dt.Fecha
    FROM Fact_Calidad fc
    JOIN Dim_Proyecto dp ON fc.ProyectoKey = dp.ProyectoKey
    JOIN Dim_Tiempo dt ON fc.TiempoKey = dt.TiempoKey
    WHERE dp.EstadoActual = 'Completado' OR dp.EstadoActual = 'Terminado'
    """

    df = pd.read_sql(query_simple, conn)
    print(f"Datos cargados: {len(df)} defectos históricos encontrados.\n")

    if len(df) == 0:
        print(
            "ADVERTENCIA: No se encontraron defectos históricos. Revisa que hayas ejecutado el script de Seed Data en SQL."
        )
    else:
        # 3. PROCESAMIENTO DE DATOS (CORREGIDO)
        df["Fecha"] = pd.to_datetime(df["Fecha"])

        # Agrupamos por proyecto para encontrar la fecha de inicio de cada uno
        project_starts = df.groupby("NombreProyecto")["Fecha"].min().reset_index()
        project_starts.rename(columns={"Fecha": "FechaInicio"}, inplace=True)

        df = df.merge(project_starts, on="NombreProyecto")

        # --- CORRECCIÓN AQUÍ ---
        # En lugar de dividir por 'M' (Meses), calculamos la diferencia matemática
        df["MesRelativo"] = (
            (df["Fecha"].dt.year - df["FechaInicio"].dt.year) * 12
            + (df["Fecha"].dt.month - df["FechaInicio"].dt.month)
        ) + 1
        # -----------------------

        # Contamos cuántos defectos hubo por mes (Frecuencia real)
        datos_agrupados = (
            df.groupby("MesRelativo").size().reset_index(name="DefectosReales")
        )

        # Rellenar meses vacíos con 0
        max_mes = datos_agrupados["MesRelativo"].max()
        todos_los_meses = pd.DataFrame({"MesRelativo": range(1, max_mes + 1)})
        datos_final = todos_los_meses.merge(
            datos_agrupados, on="MesRelativo", how="left"
        ).fillna(0)

        X_data = datos_final["MesRelativo"].values
        Y_data = datos_final["DefectosReales"].values

        # 4. DEFINICIÓN DEL MODELO RAYLEIGH
        def distribucion_rayleigh(t, sigma, escala):
            return escala * (t / (sigma**2)) * np.exp(-(t**2) / (2 * (sigma**2)))

        # 5. AJUSTE DEL MODELO
        # Usamos bounds para evitar errores matemáticos si sigma intenta ser 0
        try:
            params, _ = curve_fit(
                distribucion_rayleigh, X_data, Y_data, bounds=(0.1, [50, 1000])
            )
            sigma_optimo, escala_optima = params

            print(f"--- RESULTADOS DEL MODELO ---")
            print(f"Sigma calculado: {sigma_optimo:.2f}")
            print(f"Defectos Totales Estimados (K): {int(escala_optima)}")

            # 6. VISUALIZACIÓN
            plt.figure(figsize=(10, 6))
            plt.bar(X_data, Y_data, color="skyblue", label="Defectos Históricos Reales")

            x_pred = np.linspace(0, max_mes + 2, 100)
            y_pred = distribucion_rayleigh(x_pred, sigma_optimo, escala_optima)

            plt.plot(
                x_pred,
                y_pred,
                "r-",
                linewidth=3,
                label=f"Predicción Rayleigh (σ={sigma_optimo:.2f})",
            )

            plt.title("Modelo de Predicción de Defectos (Rayleigh)", fontsize=14)
            plt.xlabel("Mes del Proyecto")
            plt.ylabel("Cantidad de Defectos")
            plt.legend()
            plt.grid(True, alpha=0.3)

            nombre_archivo = "Prediccion_Rayleigh.png"
            plt.savefig(nombre_archivo)
            print(f"\n¡ÉXITO! Gráfica guardada como '{nombre_archivo}' en tu carpeta.")
            plt.show()

        except Exception as e_fit:
            print(f"Error al ajustar la curva (pocos datos): {e_fit}")

except Exception as e:
    print("Error General:", e)
