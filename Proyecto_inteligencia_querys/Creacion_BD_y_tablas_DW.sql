-- Crear la base de datos para el almacén de datos
CREATE DATABASE SoftwareFactory_DW;
GO
USE SoftwareFactory_DW;
GO

-- =============================================
-- 1. CREACIÓN DE DIMENSIONES
-- =============================================

-- Dimensión Tiempo: Permitirá filtrar por Año, Mes, Trimestre, Semestre
CREATE TABLE Dim_Tiempo (
    TiempoKey INT PRIMARY KEY, -- Formato YYYYMMDD (ej: 20230101)
    Fecha DATE,
    Anio INT,
    Mes INT,
    NombreMes VARCHAR(20),
    Trimestre INT,
    Semestre INT
);

-- Dimensión Empleado: Contiene datos del empleado Y su departamento (Desnormalizado)
CREATE TABLE Dim_Empleado (
    EmpleadoKey INT PRIMARY KEY IDENTITY(1,1),
    EmpleadoID_OLTP INT, -- Referencia al ID original del sistema transaccional
    NombreCompleto VARCHAR(200),
    Puesto VARCHAR(50),
    Departamento VARCHAR(50), -- Aquí traemos el nombre, no el ID
    SalarioHora DECIMAL(10,2)
);

-- Dimensión Proyecto: Datos descriptivos del proyecto
CREATE TABLE Dim_Proyecto (
    ProyectoKey INT PRIMARY KEY IDENTITY(1,1),
    ProyectoID_OLTP INT, -- Referencia al ID original
    NombreProyecto VARCHAR(100),
    Cliente VARCHAR(100),
    EstadoActual VARCHAR(20),
    PresupuestoTotal DECIMAL(15,2)
);

-- Dimensión Severidad (Específica para clasificar defectos)
CREATE TABLE Dim_Severidad (
    SeveridadKey INT PRIMARY KEY IDENTITY(1,1),
    Nivel VARCHAR(20), -- Baja, Media, Alta, Crítica
    Descripcion VARCHAR(100)
);

-- =============================================
-- 2. CREACIÓN DE TABLAS DE HECHOS
-- =============================================

-- Hecho: Desempeño de Tareas (Para KPIs de Eficiencia y Costos)
CREATE TABLE Fact_Desempeno (
    DesempenoKey INT PRIMARY KEY IDENTITY(1,1),
    -- Llaves Foráneas a las Dimensiones
    TiempoKey INT FOREIGN KEY REFERENCES Dim_Tiempo(TiempoKey),
    EmpleadoKey INT FOREIGN KEY REFERENCES Dim_Empleado(EmpleadoKey),
    ProyectoKey INT FOREIGN KEY REFERENCES Dim_Proyecto(ProyectoKey),
    
    -- Métricas (Lo que vamos a sumar o promediar)
    HorasEstimadas DECIMAL(5,2),
    HorasReales DECIMAL(5,2),
    CostoManoObra DECIMAL(10,2), -- Calculado (HorasReales * SalarioHora)
    DesviacionHoras DECIMAL(5,2) -- Calculado (Reales - Estimadas)
);

-- Hecho: Calidad y Defectos (Para KPIs de Calidad y Modelo Rayleigh)
CREATE TABLE Fact_Calidad (
    CalidadKey INT PRIMARY KEY IDENTITY(1,1),
    -- Llaves Foráneas
    TiempoKey INT FOREIGN KEY REFERENCES Dim_Tiempo(TiempoKey), -- Fecha de detección
    ProyectoKey INT FOREIGN KEY REFERENCES Dim_Proyecto(ProyectoKey),
    ReportadoPorEmpleadoKey INT FOREIGN KEY REFERENCES Dim_Empleado(EmpleadoKey),
    SeveridadKey INT FOREIGN KEY REFERENCES Dim_Severidad(SeveridadKey),
    
    -- Métricas
    CantidadDefectos INT, -- Siempre será 1 por fila, útil para hacer COUNT
    HorasReparacion DECIMAL(5,2)
);