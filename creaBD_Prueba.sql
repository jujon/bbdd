-- Usuario para pruebas. User =  role + login privilege. User y group están desfasados se hace con role que puede ser un user o un grupo de user. Se mantienen por compatibilidad pertenece a SQL3.
create user prueba;
create group TAI with user prueba; -- Creo grupo de trabajo (No SQL). No propaga los permisos de TAI a prueba (no lo entiendo no parece funcionar como oracle)
-- Oracle crea un esquema privado a cada usuario creado con nombre del usuario, postgres ubica a todos los usuarios en el esquema público. 
-- para conseguir el mismo efecto en postgres hay que hacer:
create schema tai_pruebas authorization tai; -- esquema para rol/grupo/user TAI. El dueño es el que se especifica, si no, quien lo crea
-- La instruccion anterior no parece hacer nada, sigo teniendo que especificar el esquema para acceder a las tablas.
grant usage on schema tai_pruebas to tai;  -- No es necesario, pues es el propietario especificado antes, si, si fuese del superusuario
alter role tai set search_path = 'tai_pruebas'; -- "ata" al rol tai al esquema tai_pruebas
GRANT SELECT, INSERT, DELETE, UPDATE, TRUNCATE ON ALL TABLES IN SCHEMA tai_pruebas TO tai;
-- grant select, insert, delete, update on puestos to tai;
-- En postgreSQL los nombres de los objetos de la BD son case sensitive, si pones la tabla entre comillas, el gestor respeta mayúsculas y minúsculas, si al nombre del objeto no se le ponen comillas, el gestor lo tomará como si estuviese en minúsculas.

---Crear tabla “PUESTOS”:
CREATE TABLE  tai_pruebas.PUESTOS 
(
    ID SERIAL, 
    NOMBRE_PUESTO  character varying,  -- ANSI SQL3 equivalente a los VARCHAR
    SUELDO  integer,
    PRIMARY KEY ( ID )
);

--Crear tabla “DEPARTAMENTOS”:
CREATE TABLE  tai_pruebas.DEPARTAMENTOS 
(
    ID_DEPARTAMENTO  SERIAL, 
    NOMBRE_DEPARTAMENTO VARCHAR(30), 
    PRIMARY KEY ( ID_DEPARTAMENTO )
);

--Crear tabla “EMPLEADOS”:
CREATE TABLE  tai_pruebas.EMPLEADOS 
(
    ID_EMPLEADO  SERIAL, 
    NOMBRE  varchar(20),
    APELLIDOS varchar(40),
    DNI  varchar(11), 
    ID_DEPARTAMENTO  integer,
    ID_PUESTO  integer,
    FECHA_INGRESO date,
   PRIMARY KEY ( ID_EMPLEADO ),
   FOREIGN KEY ( ID_PUESTO ) REFERENCES tai_pruebas.PUESTOS  ( ID),
   CONSTRAINT CHECK_DNI CHECK ( DNI ~* '^[0-9]{2}\.[0-9]{3}\.[0-9]{3}[A-Z]$' )
);
-- PostgreSQL Has Three Regular Expression Flavors:
-- a) traditional SQL 'LIKE / ILIKE(case insensitive)' operator,
-- b) SQL:1999 'SIMILAR TO' operator. (SIMILAR TO expressions are rewritten into regular expressions internally. SOLO POSTGRES NO ANSI SQL)
-- c)The tilde infix operator returns true or false depending on whether a regular expression can match part of a string, or not.i: 
-- ~	Matches regular expression, case sensitive	'thomas' ~ '.*thomas.*'
-- ~*	Matches regular expression, case insensitive	'thomas' ~* '.*Thomas.*'
-- !~	Does not match regular expression, case sensitive	
-- !~*	Does not match regular expression, case insensitive
-- select columna from tabla where columna ~* 'regular_expresion';
-- Reglas para crear tablas particionadas:
-- 1.- Crear tabla vacia sin indices ni check constrains salvo que se apliquen a todas las particiones.
-- 2.- Crear tablas hijas una por particion que heredan a la madre.
-- 3.- Añadir resrticciones que3 definan cada particion sin solaparse.
--CREATE TABLE  EMPLEADOS_2000 ( check(fecha_ingreso < (to_date('2000-01-01','YYYY-MM-DD'))) ) inherits (empleados); -- Contratados antes del 2000
CREATE TABLE  tai_pruebas.EMPLEADOS_2000 ( check(fecha_ingreso < DATE '2000-01-01') ) inherits (tai_pruebas.empleados); -- Contratados antes del 2000
--CREATE TABLE  EMPLEADOS_2010 ( check((fecha_ingreso,fecha_ingreso) overlaps ('2000-01-01'::date, '2010-12-31'::date)) ) inherits (empleados); -- Contratados entre 2000 y 2010 incluido
CREATE TABLE  tai_pruebas.EMPLEADOS_2010 ( check(fecha_ingreso >= DATE '2000-01-01' and fecha_ingreso <= DATE '2010-12-31') ) inherits (tai_pruebas.empleados); -- Contratados entre 2000 y 2010 incluido
--CREATE TABLE  EMPLEADOS_2020 ( check(fecha_ingreo >(to_date('2010-12-31','YYYY-MM-DD'))) ) inherits (empleados); -- Contratados despues de 2010 
CREATE TABLE  tai_pruebas.EMPLEADOS_2020 ( check(fecha_ingreso > DATE'2010-12-31') ) inherits (tai_pruebas.empleados); -- Contratados despues de 2010 
-- 4.- Crear indices sobre el criterio de particion si procede
CREATE index empleados_2000_fecha on tai_pruebas.empleados_2000 (fecha_ingreso); 
CREATE index empleados_2010_fecha on tai_pruebas.empleados_2010 (fecha_ingreso); 
CREATE index empleados_2020_fecha on tai_pruebas.empleados_2020 (fecha_ingreso); 
-- Definir una función que determine en que partición debe efectuarse el insert de manera automática
CREATE OR REPLACE FUNCTION empleados_insert_trigger()
  RETURNS TRIGGER AS $$
  BEGIN
	if (NEW.fecha_ingreso < DATE '2000-01-01') THEN 
	   insert into tai_pruebas.empleados_2000 values (NEW.*);
	elsif (NEW.fecha_ingreso >= DATE '2000-01-01' and NEW.fecha_ingreso < DATE '2010-12-31') THEN
	   insert into tai_pruebas.empleados_2010 values (NEW.*);
	elsif (NEW.fecha_ingreso > DATE '2010-12-31') THEN
	   insert into tai_pruebas.empleados_2020 values (NEW.*);
	else
	   raise exception 'Fecha fuera de rango. Adecue la funcion empleados_insert_trigger()';
	end if;
	return null; 
  END;
  $$
  LANGUAGE plpgsql;
-- La definicion del trigger es identica a la de la check constraint que define las tablas particiones
-- Crear el trigger que llame a la función
CREATE TRIGGER insert_empleados_trigger
    BEFORE INSERT ON tai_pruebas.empleados
    FOR EACH ROW EXECUTE PROCEDURE empleados_insert_trigger();

--INSERTAR VALORES EN LA TABLA PUESTOS:
INSERT INTO  tai_pruebas.PUESTOS  ( NOMBRE_PUESTO ,  SUELDO ) VALUES ('DIRECTOR', 4000), ('SUBDIRECTOR', 3500), ('EJECUTIVO', 2500),
('DIRECTIVO', 2000), ('ADMINISTRATIVO', 1000), ('ESCAQUEO',100), ('SUBCONTRATA',500);

--INSERTAR VALORES EN LA TABLA DEPARTAMENTOS:
INSERT INTO  tai_pruebas.DEPARTAMENTOS  ( NOMBRE_DEPARTAMENTO )
VALUES ('INFORMATICA'), ('CONTABILIDAD'), ('COMERCIAL'), ('RECURSOS HUMANOS'),('FORMACION'),('DIRECCION');

--INSERTAR VALORES EN LA TABLA EMPLEADOS:
INSERT INTO tai_pruebas.EMPLEADOS(NOMBRE, APELLIDOS, DNI, ID_PUESTO, ID_DEPARTAMENTO, FECHA_INGRESO) VALUES ('JOSÉ', 'LÓPEZ PÉREZ', '40.123.456M',  1, 6,'1995-05-31'), 
('JUAN', 'SUÁREZ DE LA MORENA', '02.451.036J',  4, 6,'1998-10-25'), ('SARA', 'SÁNCHEZ GARCÍA', '34.452.198T', 5, 3,'1999-12-31'), 
('JAVIER', 'MORENO MONTERO', '07.894.368S',  2, 6,'2000-01-01'), ('CATALINA', 'ROMERO DE LA SERNA', '50.421.369J',  3, 6,'2005-06-15'), 
('BELÉN', 'CASTILLO MARTÍNEZ', '09.456.879F',  4, 6,'2010-12-12'), ('JUAN JOSE', 'GARCIA SOTO', '52.459.603V',  5, 3,'2010-01-01'), 
('JOSÉ', 'LÓPEZ PÉREZ', '36.123.784K',  5, 3,'2011-01-01'), ('SILVIA', 'GARCÍA MARTÍN', '02.451.123S',  5, 3,'2012-04-04'), 
('ARACELI', 'MONTERO MUÑOZ', '30.259.788U',  5, 3,'2017-01-05');

-- Consultas con joins

--INNER JOIN : cuando se hace referencia a las mismas columnas, se llamen igual ó con el uso de WHERE si no es así.
-- Consulta natural join sin epecificar (join implicito)
Select E.DNI, E.Nombre, E.Apellidos, P.Nombre_puesto, E.Id_departamento
FROM tai_pruebas.Empleados E, tai_pruebas.Puestos P
  where E.id_puesto = P.id
ORDER BY E.ID_PUESTO;
-- Idéntica consulta con uso del JOIN (no es necesario especificar INNER, es el default)
Select E.DNI, E.Nombre, E.Apellidos, P.Nombre_puesto, E.Id_departamento
FROM tai_pruebas.Empleados E JOIN tai_pruebas.Puestos P
  ON E.id_puesto = P.id
ORDER BY E.ID_PUESTO;
--Si hay comparaciones dentro del predicado JOIN se le llama theta-join. Se pueden hacer comparaciones de <, <=, =, <>, >= y >.
-- Equi-Join: Es una variedad del theta-join que usa comparaciones de igualdad en el predicado JOIN.
-- Si no se llaman igual y no se usa where se efectua un producto cartesiano, es necesria la llamada explícita a cross join.
Select E.DNI, E.Nombre, E.Apellidos, P.Nombre_puesto, E.Id_departamento
FROM tai_pruebas.Empleados E CROSS JOIN tai_pruebas.Puestos P;
--NATURAL JOIN cuando se comparan todas las columnas que tengan el mismo nombre en ambas tablas. La resultante contiene sólo una columna por cada par de columnas con el mismo nombre
 SELECT * FROM tai_pruebas.empleados NATURAL JOIN tai_pruebas.puestos; -- En este caso no se puede hay campos iguales 2 a 2
-- OUTER JOIN El termino OUTER va implicto y no es necesario especificarlo en la sentencia
-- LEFT JOIN retorna la pareja de todos los valores de la tabla izquierda con los valores de la tabla de la derecha correspondientes, si los hay, o retorna un valor nulo NULL
SELECT * FROM tai_pruebas.empleados E LEFT JOIN tai_pruebas.puestos P on E.id_puesto = P.id; 
-- RIGHT JOIN  retorna todos los valores de la tabla derecha con los valores de la tabla de la izquierda correspondientes, si los hay, o retorna un valor nulo NULL
SELECT * FROM tai_pruebas.empleados E RIGHT JOIN tai_pruebas.puestos P on E.id_puesto = P.id;

-- FULL JOIN retorna los valores no presentes en ambas tablas completando con null los campos respectivos ausentes
SELECT * FROM tai_pruebas.empleados E FULL JOIN tai_pruebas.puestos P on E.id_puesto = P.id;
-- En este caso una de las tablas presenta FK y nunca tendrá registros en el que aparezca un identificador no contemplado en la otra tabla

-- FUNCIONES VENTANA
-- Función base
Select E.DNI, E.Nombre, E.Apellidos, E.Id_departamento, EXTRACT(YEAR FROM age(timestamp 'now()',date(fecha_ingreso) ) ) as antiguedad 
FROM tai_pruebas.Empleados E 
ORDER BY E.ID_departamento;
-- Modo estándar
Select E.DNI, E.Nombre, E.Apellidos, E.Id_departamento, EXTRACT(YEAR FROM age(timestamp 'now()',date(fecha_ingreso) ) ) as antiguedad, 
		avg(EXTRACT(YEAR FROM age(timestamp 'now()',date(fecha_ingreso) ) )) over (partition by Id_departamento) as media_edad
FROM tai_pruebas.Empleados E 
ORDER BY E.ID_departamento;
-- Implementando ventana
Select E.DNI, E.Nombre, E.Apellidos, E.Id_departamento, EXTRACT(YEAR FROM age(timestamp 'now()',date(fecha_ingreso) ) ) as antiguedad, 
		avg(EXTRACT(YEAR FROM age(timestamp 'now()',date(fecha_ingreso) ) )) OVER VENTANA_DEPARTAMENTO as media_edad
FROM tai_pruebas.Empleados E
WINDOW ventana_departamento as (partition by Id_departamento)
ORDER BY E.ID_departamento;

--Funciones LATERALES
-- Consulta base
Select E.DNI, E.Nombre, E.Apellidos, E.Id_departamento, 
        CAST(EXTRACT(YEAR FROM age(timestamp 'now()',date(fecha_ingreso))) as int) as antiguedad,
        P.sueldo
FROM tai_pruebas.Empleados E, tai_pruebas.Puestos P 
WHERE E.id_puesto = P.id
ORDER BY E.ID_departamento;

-- Implementando funciones laterales
Select E.DNI, E.Nombre, E.Apellidos, E.Id_departamento, S.antiguedad, P.sueldo as sueldo_base, 
        CAST((P.sueldo + CAST( (antiguedad/100)as decimal(4,2)) * P.sueldo ) as decimal(6,2))as ACTUAL
FROM tai_pruebas.Empleados E, tai_pruebas.Puestos P, 
        LATERAL (select CAST( EXTRACT(YEAR FROM age(timestamp 'now()',date(fecha_ingreso))) as decimal(5,0)) ) as S(antiguedad)
WHERE E.id_puesto = P.id
ORDER BY E.ID_departamento;

