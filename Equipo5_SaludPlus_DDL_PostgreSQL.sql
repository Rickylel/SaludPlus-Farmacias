/*
  SaludPlus Farmacias
  Data Mart de Ventas - Etapa 4
  Motor: PostgreSQL 15 o superior

  Grano de fact_venta:
  Una fila por combinación de venta, producto y lote después de consolidar
  líneas duplicadas de la misma transacción.
*/

CREATE SCHEMA IF NOT EXISTS saludplus_dm;
SET search_path TO saludplus_dm;

/* Dimensión de producto */
CREATE TABLE dim_producto (
    producto_key        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    producto_id_origen  BIGINT NOT NULL UNIQUE,
    nombre              VARCHAR(150) NOT NULL,
    marca               VARCHAR(100) NOT NULL,
    categoria           VARCHAR(100) NOT NULL,
    subcategoria        VARCHAR(100),
    unidad              VARCHAR(40) NOT NULL
);

/* Dimensión de lote. producto_id_origen conserva trazabilidad con la fuente. */
CREATE TABLE dim_lote (
    lote_key            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    lote_id_origen      BIGINT NOT NULL UNIQUE,
    producto_id_origen  BIGINT NOT NULL,
    fecha_caducidad     DATE NOT NULL,
    costo_lote          NUMERIC(12,2) NOT NULL CHECK (costo_lote >= 0)
);

/* El cliente puede ser nulo en la tabla de hechos cuando la venta es anónima. */
CREATE TABLE dim_cliente (
    cliente_key         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    cliente_id_origen   BIGINT NOT NULL UNIQUE,
    nivel_beneficios    VARCHAR(50),
    ciudad              VARCHAR(100),
    fecha_alta          DATE
);

CREATE TABLE dim_sucursal (
    sucursal_key        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sucursal_id_origen  BIGINT NOT NULL UNIQUE,
    nombre              VARCHAR(120) NOT NULL,
    ciudad              VARCHAR(100) NOT NULL,
    region              VARCHAR(100) NOT NULL
);

/* sucursal_id_origen permite auditar la adscripción operativa del empleado. */
CREATE TABLE dim_empleado (
    empleado_key        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    empleado_id_origen  BIGINT NOT NULL UNIQUE,
    sucursal_id_origen  BIGINT NOT NULL,
    nombre              VARCHAR(150) NOT NULL,
    puesto              VARCHAR(80) NOT NULL
);

CREATE TABLE dim_canal (
    canal_key           SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre_canal        VARCHAR(30) NOT NULL UNIQUE,
    CHECK (nombre_canal IN ('Mostrador', 'App', 'Domicilio'))
);

/* Una fila representa un instante de venta con atributos para agrupación. */
CREATE TABLE dim_fecha (
    fecha_hora_key      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fecha_hora          TIMESTAMP NOT NULL UNIQUE,
    fecha               DATE NOT NULL,
    hora                SMALLINT NOT NULL CHECK (hora BETWEEN 0 AND 23),
    rango_horario       VARCHAR(30) NOT NULL,
    dia_semana          VARCHAR(15) NOT NULL,
    mes                 SMALLINT NOT NULL CHECK (mes BETWEEN 1 AND 12),
    trimestre           SMALLINT NOT NULL CHECK (trimestre BETWEEN 1 AND 4),
    anio                SMALLINT NOT NULL CHECK (anio BETWEEN 2000 AND 2100),
    CHECK (fecha = fecha_hora::DATE),
    CHECK (hora = EXTRACT(HOUR FROM fecha_hora))
);

/*
  Tabla de hechos de ventas.
  Los importes calculados se generan a partir de las medidas atómicas para
  evitar diferencias entre el detalle y los totales almacenados.
*/
CREATE TABLE fact_venta (
    fact_venta_key      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    venta_id_origen     BIGINT NOT NULL,
    producto_key        BIGINT NOT NULL,
    lote_key            BIGINT NOT NULL,
    cliente_key         BIGINT,
    empleado_key        BIGINT NOT NULL,
    sucursal_key        BIGINT NOT NULL,
    canal_key           SMALLINT NOT NULL,
    fecha_hora_key      BIGINT NOT NULL,
    cantidad            INTEGER NOT NULL CHECK (cantidad > 0),
    precio_unitario     NUMERIC(12,2) NOT NULL CHECK (precio_unitario >= 0),
    descuento           NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (descuento >= 0),
    costo_unitario      NUMERIC(12,2) NOT NULL CHECK (costo_unitario >= 0),
    monto_total         NUMERIC(14,2) GENERATED ALWAYS AS
                        ((cantidad * precio_unitario) - descuento) STORED,
    costo_total         NUMERIC(14,2) GENERATED ALWAYS AS
                        (cantidad * costo_unitario) STORED,
    margen              NUMERIC(14,2) GENERATED ALWAYS AS
                        (((cantidad * precio_unitario) - descuento)
                         - (cantidad * costo_unitario)) STORED,

    CONSTRAINT fk_fact_producto
        FOREIGN KEY (producto_key) REFERENCES dim_producto (producto_key),
    CONSTRAINT fk_fact_lote
        FOREIGN KEY (lote_key) REFERENCES dim_lote (lote_key),
    CONSTRAINT fk_fact_cliente
        FOREIGN KEY (cliente_key) REFERENCES dim_cliente (cliente_key),
    CONSTRAINT fk_fact_empleado
        FOREIGN KEY (empleado_key) REFERENCES dim_empleado (empleado_key),
    CONSTRAINT fk_fact_sucursal
        FOREIGN KEY (sucursal_key) REFERENCES dim_sucursal (sucursal_key),
    CONSTRAINT fk_fact_canal
        FOREIGN KEY (canal_key) REFERENCES dim_canal (canal_key),
    CONSTRAINT fk_fact_fecha
        FOREIGN KEY (fecha_hora_key) REFERENCES dim_fecha (fecha_hora_key),
    CONSTRAINT uq_fact_grano
        UNIQUE (venta_id_origen, producto_key, lote_key),
    CONSTRAINT ck_fact_descuento_valido
        CHECK (descuento <= cantidad * precio_unitario)
);

/* Índices para filtros y agrupaciones frecuentes del Data Mart. */
CREATE INDEX idx_fact_venta_fecha
    ON fact_venta (fecha_hora_key);

CREATE INDEX idx_fact_venta_producto
    ON fact_venta (producto_key);

CREATE INDEX idx_fact_venta_sucursal
    ON fact_venta (sucursal_key);

CREATE INDEX idx_fact_venta_canal
    ON fact_venta (canal_key);

CREATE INDEX idx_fact_venta_cliente
    ON fact_venta (cliente_key)
    WHERE cliente_key IS NOT NULL;

CREATE INDEX idx_dim_producto_categoria
    ON dim_producto (categoria, marca);

CREATE INDEX idx_dim_lote_caducidad
    ON dim_lote (fecha_caducidad);

/* Catálogo inicial de canales previstos por el caso. */
INSERT INTO dim_canal (nombre_canal)
VALUES ('Mostrador'), ('App'), ('Domicilio')
ON CONFLICT (nombre_canal) DO NOTHING;

COMMENT ON TABLE fact_venta IS
'Una fila por venta, producto y lote consolidado; contiene medidas de ingreso, costo y margen.';
COMMENT ON COLUMN fact_venta.cliente_key IS
'Nulo cuando la fuente registra una venta sin cliente identificado.';
COMMENT ON COLUMN fact_venta.monto_total IS
'cantidad * precio_unitario - descuento';
COMMENT ON COLUMN fact_venta.costo_total IS
'cantidad * costo_unitario';
COMMENT ON COLUMN fact_venta.margen IS
'monto_total - costo_total';
