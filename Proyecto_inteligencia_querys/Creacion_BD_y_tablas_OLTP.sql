-- Creación de la base de datos transaccional
CREATE DATABASE SoftwareFactory_OLTP;
GO
USE SoftwareFactory_OLTP;
GO

-- 1. Tabla de Departamentos (Para análisis organizacional)
CREATE TABLE Departamentos (
    DepartamentoID INT PRIMARY KEY IDENTITY(1,1),
    Nombre VARCHAR(50) NOT NULL,
    Descripcion VARCHAR(200)
);

-- 2. Tabla de Empleados (Recurso humano)
CREATE TABLE Empleados (
    EmpleadoID INT PRIMARY KEY IDENTITY(1,1),
    Nombre VARCHAR(100) NOT NULL,
    Apellido VARCHAR(100) NOT NULL,
    DepartamentoID INT FOREIGN KEY REFERENCES Departamentos(DepartamentoID),
    Puesto VARCHAR(50),
    FechaContratacion DATE,
    SalarioHora DECIMAL(10, 2) -- Importante para calcular costos
);

-- 3. Tabla de Proyectos (El núcleo del negocio)
CREATE TABLE Proyectos (
    ProyectoID INT PRIMARY KEY IDENTITY(1,1),
    NombreProyecto VARCHAR(100) NOT NULL,
    Cliente VARCHAR(100),
    FechaInicio DATE,
    FechaFinEstimada DATE,
    FechaFinReal DATE, -- Si es NULL, el proyecto sigue en curso
    Presupuesto DECIMAL(15, 2),
    Estado VARCHAR(20) -- Ej: 'En Progreso', 'Completado', 'Cancelado'
);

-- 4. Tabla de Tareas (Detalle operativo para medir eficiencia)
CREATE TABLE Tareas (
    TareaID INT PRIMARY KEY IDENTITY(1,1),
    ProyectoID INT FOREIGN KEY REFERENCES Proyectos(ProyectoID),
    EmpleadoID INT FOREIGN KEY REFERENCES Empleados(EmpleadoID),
    NombreTarea VARCHAR(100),
    HorasEstimadas DECIMAL(5, 2), -- Lo que se planeó
    HorasReales DECIMAL(5, 2),    -- Lo que realmente tardó (KPI Eficiencia)
    FechaCompletado DATE,
    Estado VARCHAR(20) -- 'Pendiente', 'Testing', 'Terminado'
);

-- 5. Tabla de Defectos (Bugs para el Modelo Rayleigh y Calidad)
CREATE TABLE Defectos (
    DefectoID INT PRIMARY KEY IDENTITY(1,1),
    ProyectoID INT FOREIGN KEY REFERENCES Proyectos(ProyectoID),
    ReportadoPor INT FOREIGN KEY REFERENCES Empleados(EmpleadoID), -- Quién halló el bug
    FechaDeteccion DATE NOT NULL, -- CRÍTICO para la distribución de Rayleigh
    Severidad VARCHAR(20), -- 'Alta', 'Media', 'Baja'
    Estado VARCHAR(20), -- 'Abierto', 'Resuelto'
    HorasReparacion DECIMAL(5, 2) -- Costo de la No Calidad
);