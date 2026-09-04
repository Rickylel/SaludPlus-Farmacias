# SaludPlus-Farmacias
Caso Retail 5

# SaludPlus Farmacias

Este repositorio contiene el script SQL comentado para crear un Data Mart de ventas de SaludPlus Farmacias en PostgreSQL.

## Objetivo

Organizar la información para analizar cantidades vendidas, ingresos, descuentos, costos y margen por producto, sucursal, canal y fecha.

## Contenido del script

El modelo utiliza un esquema estrella con siete dimensiones y una tabla de hechos llamada `fact_venta`. Cada fila representa una combinación de venta, producto y lote.

El script incluye:

- Creación de las tablas y sus atributos.
- Claves primarias y foráneas.
- Restricciones para validar datos y evitar duplicados.
- Cálculos automáticos de monto total, costo total y margen.
- Índices para apoyar las consultas.
- Comentarios que explican cada sección.

## Ejecución

1. Crear una base de datos vacía en PostgreSQL 15 o superior.
2. Abrir **Query Tool** desde pgAdmin.
3. Cargar el archivo `.sql` y ejecutarlo completo.
4. Verificar las ocho tablas en **Schemas → saludplus_dm → Tables**.

**Importante:** no ejecutar nuevamente el script si las tablas ya existen. El archivo crea la estructura, pero no incluye ventas de ejemplo.

## Integrantes

- Kenner Shahid López Ramírez - 2142291
- Mariana Flores Rosales - 2143017
- Luis Ricardo Salinas De la Peña - 2142924
