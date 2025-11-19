USE SoftwareFactory_OLTP;
GO

-- =============================================
-- 1. Insertar Departamentos y Empleados
-- =============================================
INSERT INTO Departamentos (Nombre, Descripcion) VALUES 
('Desarrollo Backend', 'Lógica de servidor y APIs'),
('Desarrollo Frontend', 'Interfaces de usuario'),
('QA & Testing', 'Aseguramiento de calidad'),
('Gestión de Proyectos', 'Scrum Masters y PMs');

INSERT INTO Empleados (Nombre, Apellido, DepartamentoID, Puesto, FechaContratacion, SalarioHora) VALUES 
('Juan', 'Pérez', 1, 'Senior Developer', '2020-01-15', 350.00),
('Ana', 'Gómez', 2, 'Frontend Dev', '2021-03-10', 280.00),
('Carlos', 'Ruiz', 3, 'QA Engineer', '2021-05-20', 200.00),
('Sofia', 'López', 4, 'Project Manager', '2019-11-01', 400.00),
('Miguel', 'Torres', 1, 'Junior Developer', '2023-01-10', 150.00);

-- =============================================
-- 2. Insertar Proyectos (2 Históricos, 1 Activo)
-- =============================================
INSERT INTO Proyectos (NombreProyecto, Cliente, FechaInicio, FechaFinEstimada, FechaFinReal, Presupuesto, Estado) VALUES 
-- Proyecto 1: Histórico (Terminado, fue exitoso)
('Sistema E-Commerce v1', 'Retail S.A.', '2023-01-01', '2023-03-31', '2023-04-05', 150000.00, 'Completado'),
-- Proyecto 2: Histórico (Terminado, tuvo problemas y retrasos)
('App Móvil Logística', 'Transportes Rapidos', '2023-05-01', '2023-08-01', '2023-08-20', 200000.00, 'Completado'),
-- Proyecto 3: ACTUAL (En curso, para el Dashboard en tiempo real)
('Migración Cloud', 'Banco Futuro', '2023-09-01', '2023-12-15', NULL, 300000.00, 'En Progreso');

-- =============================================
-- 3. Insertar Tareas (KPI de Eficiencia y Costos)
-- =============================================
-- Tareas del Proyecto 1 (E-Commerce)
INSERT INTO Tareas (ProyectoID, EmpleadoID, NombreTarea, HorasEstimadas, HorasReales, FechaCompletado, Estado) VALUES 
(1, 1, 'Diseño de BD', 20, 18, '2023-01-10', 'Terminado'), -- Eficiente
(1, 2, 'Maquetación Home', 30, 35, '2023-01-20', 'Terminado'), -- Se tardó más
(1, 1, 'API de Pagos', 40, 40, '2023-02-15', 'Terminado'); 

-- Tareas del Proyecto 3 (Actual - Migración Cloud)
INSERT INTO Tareas (ProyectoID, EmpleadoID, NombreTarea, HorasEstimadas, HorasReales, FechaCompletado, Estado) VALUES 
(3, 1, 'Configuración AWS', 50, 45, '2023-09-10', 'Terminado'),
(3, 5, 'Scripts de Migración', 40, 60, '2023-09-25', 'Terminado'), -- Junior tardó mucho (Alerta KPI)
(3, 2, 'Dashboard Admin', 30, 10, NULL, 'Pendiente'); -- Aún no termina

-- =============================================
-- 4. Insertar Defectos (CRÍTICO para Rayleigh)
-- =============================================
-- Nota: Observa las fechas. Para el Proyecto 1 (Ene-Abr), simulamos una curva:
-- Enero: Pocos bugs. Febrero/Marzo: Muchos bugs (Testing fuerte). Abril: Casi cero.

-- Proyecto 1 (E-Commerce)
INSERT INTO Defectos (ProyectoID, ReportadoPor, FechaDeteccion, Severidad, Estado, HorasReparacion) VALUES 
(1, 3, '2023-01-20', 'Baja', 'Resuelto', 2),  -- Inicio
(1, 3, '2023-02-10', 'Media', 'Resuelto', 5),  -- Subiendo
(1, 3, '2023-02-15', 'Alta', 'Resuelto', 8),
(1, 3, '2023-02-28', 'Alta', 'Resuelto', 10), -- Pico
(1, 3, '2023-03-05', 'Media', 'Resuelto', 4),
(1, 3, '2023-03-10', 'Baja', 'Resuelto', 2),
(1, 3, '2023-03-25', 'Baja', 'Resuelto', 1);  -- Final (Bajando)

-- Proyecto 2 (App Móvil) - Este tuvo más bugs
INSERT INTO Defectos (ProyectoID, ReportadoPor, FechaDeteccion, Severidad, Estado, HorasReparacion) VALUES 
(2, 3, '2023-05-20', 'Media', 'Resuelto', 4),
(2, 3, '2023-06-15', 'Alta', 'Resuelto', 12),
(2, 3, '2023-07-01', 'Critica', 'Resuelto', 20), -- Problema grave
(2, 3, '2023-07-10', 'Alta', 'Resuelto', 8),
(2, 3, '2023-08-05', 'Baja', 'Resuelto', 3);