USE SoftwareFactory_DW;
GO

CREATE OR ALTER PROCEDURE SP_Ejecutar_ETL
AS
BEGIN
    SET NOCOUNT ON;
    PRINT 'Iniciando proceso ETL...';

    -- =============================================
    -- 1. LIMPIEZA INICIAL (TRUNCATE)
    -- =============================================
    -- Borramos primero las tablas de Hechos (tienen Foreign Keys)
    DELETE FROM Fact_Desempeno;
    DELETE FROM Fact_Calidad;
    
    -- Borramos las Dimensiones
    DELETE FROM Dim_Proyecto;
    DELETE FROM Dim_Empleado;
    DELETE FROM Dim_Severidad;
    DELETE FROM Dim_Tiempo;

    -- Reiniciamos los contadores de ID (para que empiecen en 1 siempre)
    DBCC CHECKIDENT ('Dim_Proyecto', RESEED, 0);
    DBCC CHECKIDENT ('Dim_Empleado', RESEED, 0);
    DBCC CHECKIDENT ('Dim_Severidad', RESEED, 0);

    PRINT 'Limpieza completada.';

    -- =============================================
    -- 2. CARGA DE DIMENSIONES ESTATICAS Y PROCEDURALES
    -- =============================================
    
    -- A) Dimensión Severidad (Valores fijos)
    INSERT INTO Dim_Severidad (Nivel, Descripcion) VALUES 
    ('Baja', 'Defecto cosmético o menor'),
    ('Media', 'Funcionalidad afectada parcialmente'),
    ('Alta', 'Funcionalidad crítica bloqueada'),
    ('Critica', 'Sistema caído o pérdida de datos');

    -- B) Dimensión Tiempo (Generamos fechas desde 2023 hasta 2025)
    DECLARE @FechaInicio DATE = '2023-01-01';
    DECLARE @FechaFin DATE = '2025-12-31';

    WHILE @FechaInicio <= @FechaFin
    BEGIN
        INSERT INTO Dim_Tiempo (TiempoKey, Fecha, Anio, Mes, NombreMes, Trimestre, Semestre)
        VALUES (
            YEAR(@FechaInicio) * 10000 + MONTH(@FechaInicio) * 100 + DAY(@FechaInicio), -- Key: 20230101
            @FechaInicio,
            YEAR(@FechaInicio),
            MONTH(@FechaInicio),
            DATENAME(MONTH, @FechaInicio),
            DATEPART(QUARTER, @FechaInicio),
            CASE WHEN MONTH(@FechaInicio) <= 6 THEN 1 ELSE 2 END
        );
        SET @FechaInicio = DATEADD(DAY, 1, @FechaInicio);
    END

    PRINT 'Dimensiones estáticas cargadas.';

    -- =============================================
    -- 3. CARGA DE DIMENSIONES DESDE OLTP (EXTRACT & LOAD)
    -- =============================================

    -- C) Dimensión Proyecto
    INSERT INTO Dim_Proyecto (ProyectoID_OLTP, NombreProyecto, Cliente, EstadoActual, PresupuestoTotal)
    SELECT ProyectoID, NombreProyecto, Cliente, Estado, Presupuesto
    FROM SoftwareFactory_OLTP.dbo.Proyectos;

    -- D) Dimensión Empleado (Con JOIN a Departamentos para desnormalizar)
    INSERT INTO Dim_Empleado (EmpleadoID_OLTP, NombreCompleto, Puesto, Departamento, SalarioHora)
    SELECT 
        e.EmpleadoID,
        CONCAT(e.Nombre, ' ', e.Apellido),
        e.Puesto,
        d.Nombre, -- Traemos el nombre del depto, no el ID
        e.SalarioHora
    FROM SoftwareFactory_OLTP.dbo.Empleados e
    INNER JOIN SoftwareFactory_OLTP.dbo.Departamentos d ON e.DepartamentoID = d.DepartamentoID;

    PRINT 'Dimensiones dinámicas cargadas.';

    -- =============================================
    -- 4. CARGA DE TABLAS DE HECHOS (TRANSFORM & LOAD)
    -- =============================================

    -- E) Fact_Desempeno
    -- Transformación: Calculamos costos y desviaciones al vuelo
    INSERT INTO Fact_Desempeno (TiempoKey, EmpleadoKey, ProyectoKey, HorasEstimadas, HorasReales, CostoManoObra, DesviacionHoras)
    SELECT 
        -- Generamos el TiempoKey basado en la fecha de completado
        YEAR(t.FechaCompletado) * 10000 + MONTH(t.FechaCompletado) * 100 + DAY(t.FechaCompletado),
        de.EmpleadoKey,
        dp.ProyectoKey,
        t.HorasEstimadas,
        t.HorasReales,
        (t.HorasReales * de.SalarioHora), -- Cálculo de Costo ($)
        (t.HorasReales - t.HorasEstimadas) -- Cálculo de Desviación
    FROM SoftwareFactory_OLTP.dbo.Tareas t
    -- Hacemos JOINS con las DIMENSIONES del DW para obtener las llaves nuevas
    INNER JOIN Dim_Empleado de ON t.EmpleadoID = de.EmpleadoID_OLTP
    INNER JOIN Dim_Proyecto dp ON t.ProyectoID = dp.ProyectoID_OLTP
    WHERE t.FechaCompletado IS NOT NULL; -- Solo cargamos tareas terminadas

    -- F) Fact_Calidad
    INSERT INTO Fact_Calidad (TiempoKey, ProyectoKey, ReportadoPorEmpleadoKey, SeveridadKey, CantidadDefectos, HorasReparacion)
    SELECT 
        YEAR(d.FechaDeteccion) * 10000 + MONTH(d.FechaDeteccion) * 100 + DAY(d.FechaDeteccion),
        dp.ProyectoKey,
        de.EmpleadoKey,
        ds.SeveridadKey,
        1, -- Cantidad siempre es 1 por fila
        d.HorasReparacion
    FROM SoftwareFactory_OLTP.dbo.Defectos d
    INNER JOIN Dim_Proyecto dp ON d.ProyectoID = dp.ProyectoID_OLTP
    INNER JOIN Dim_Empleado de ON d.ReportadoPor = de.EmpleadoID_OLTP
    INNER JOIN Dim_Severidad ds ON d.Severidad = ds.Nivel;

    PRINT 'ETL Finalizado con Éxito.';
END;
GO

-- =============================================
-- 5. EJECUTAR EL PROCEDIMIENTO (PRUEBA)
-- =============================================
EXEC SP_Ejecutar_ETL;

-- Verificamos que haya datos
SELECT TOP 5 * FROM Fact_Desempeno;
SELECT TOP 5 * FROM Fact_Calidad;