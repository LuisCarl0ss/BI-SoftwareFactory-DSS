USE SoftwareFactory_DW;
GO

CREATE OR ALTER PROCEDURE SP_Ejecutar_ETL
AS
BEGIN
    SET NOCOUNT ON;
    PRINT 'Iniciando proceso ETL (Solo Proyectos Cerrados)...';

    -- =============================================
    -- 1. LIMPIEZA INICIAL
    -- =============================================
    DELETE FROM Fact_Desempeno;
    DELETE FROM Fact_Calidad;
    DELETE FROM Dim_Proyecto;
    DELETE FROM Dim_Empleado;
    DELETE FROM Dim_Severidad;
    DELETE FROM Dim_Tiempo;

    -- Reiniciamos contadores
    DBCC CHECKIDENT ('Dim_Proyecto', RESEED, 0);
    DBCC CHECKIDENT ('Dim_Empleado', RESEED, 0);
    DBCC CHECKIDENT ('Dim_Severidad', RESEED, 0);

    -- =============================================
    -- 2. CARGA DE DIMENSIONES ESTATICAS
    -- =============================================
    INSERT INTO Dim_Severidad (Nivel, Descripcion) VALUES 
    ('Baja', 'Defecto cosmético o menor'),
    ('Media', 'Funcionalidad afectada parcialmente'),
    ('Alta', 'Funcionalidad crítica bloqueada'),
    ('Critica', 'Sistema caído o pérdida de datos');

    -- Carga de Tiempo
    DECLARE @FechaInicio DATE = '2023-01-01';
    DECLARE @FechaFin DATE = '2025-12-31';
    WHILE @FechaInicio <= @FechaFin
    BEGIN
        INSERT INTO Dim_Tiempo (TiempoKey, Fecha, Anio, Mes, NombreMes, Trimestre, Semestre)
        VALUES (
            YEAR(@FechaInicio) * 10000 + MONTH(@FechaInicio) * 100 + DAY(@FechaInicio),
            @FechaInicio,
            YEAR(@FechaInicio),
            MONTH(@FechaInicio),
            DATENAME(MONTH, @FechaInicio),
            DATEPART(QUARTER, @FechaInicio),
            CASE WHEN MONTH(@FechaInicio) <= 6 THEN 1 ELSE 2 END
        );
        SET @FechaInicio = DATEADD(DAY, 1, @FechaInicio);
    END

    -- =============================================
    -- 3. CARGA DE DIMENSIONES (CON FILTRO NUEVO)
    -- =============================================

    -- C) Dimensión Proyecto (SOLO TERMINADOS O CANCELADOS)
    -- *** AQUÍ ESTÁ EL CAMBIO QUE TE PIDIERON ***
    INSERT INTO Dim_Proyecto (ProyectoID_OLTP, NombreProyecto, Cliente, EstadoActual, PresupuestoTotal)
    SELECT ProyectoID, NombreProyecto, Cliente, Estado, Presupuesto
    FROM SoftwareFactory_OLTP.dbo.Proyectos
    WHERE Estado IN ('Completado', 'Cancelado', 'Terminado'); 
    -- Excluimos 'En Progreso'

    -- D) Dimensión Empleado
    INSERT INTO Dim_Empleado (EmpleadoID_OLTP, NombreCompleto, Puesto, Departamento, SalarioHora)
    SELECT e.EmpleadoID, CONCAT(e.Nombre, ' ', e.Apellido), e.Puesto, d.Nombre, e.SalarioHora
    FROM SoftwareFactory_OLTP.dbo.Empleados e
    INNER JOIN SoftwareFactory_OLTP.dbo.Departamentos d ON e.DepartamentoID = d.DepartamentoID;

    -- =============================================
    -- 4. CARGA DE HECHOS
    -- =============================================

    -- E) Fact_Desempeno
    -- Al hacer INNER JOIN con Dim_Proyecto, las tareas de proyectos activos 
    -- se descartarán automáticamente porque el proyecto ya no existe en la Dimensión.
    INSERT INTO Fact_Desempeno (TiempoKey, EmpleadoKey, ProyectoKey, HorasEstimadas, HorasReales, CostoManoObra, DesviacionHoras)
    SELECT 
        YEAR(t.FechaCompletado) * 10000 + MONTH(t.FechaCompletado) * 100 + DAY(t.FechaCompletado),
        de.EmpleadoKey,
        dp.ProyectoKey,
        t.HorasEstimadas,
        t.HorasReales,
        (t.HorasReales * de.SalarioHora),
        (t.HorasReales - t.HorasEstimadas)
    FROM SoftwareFactory_OLTP.dbo.Tareas t
    INNER JOIN Dim_Empleado de ON t.EmpleadoID = de.EmpleadoID_OLTP
    INNER JOIN Dim_Proyecto dp ON t.ProyectoID = dp.ProyectoID_OLTP -- Filtro automático aquí
    WHERE t.FechaCompletado IS NOT NULL;

    -- F) Fact_Calidad
    INSERT INTO Fact_Calidad (TiempoKey, ProyectoKey, ReportadoPorEmpleadoKey, SeveridadKey, CantidadDefectos, HorasReparacion)
    SELECT 
        YEAR(d.FechaDeteccion) * 10000 + MONTH(d.FechaDeteccion) * 100 + DAY(d.FechaDeteccion),
        dp.ProyectoKey,
        de.EmpleadoKey,
        ds.SeveridadKey,
        1,
        d.HorasReparacion
    FROM SoftwareFactory_OLTP.dbo.Defectos d
    INNER JOIN Dim_Proyecto dp ON d.ProyectoID = dp.ProyectoID_OLTP -- Filtro automático aquí
    INNER JOIN Dim_Empleado de ON d.ReportadoPor = de.EmpleadoID_OLTP
    INNER JOIN Dim_Severidad ds ON d.Severidad = ds.Nivel;

    PRINT 'ETL Finalizado (Filtrado por terminados).';
END;
GO

-- Ejecutar para aplicar cambios
EXEC SP_Ejecutar_ETL;