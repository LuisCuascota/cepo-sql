# Caja de Ahorro "Cepo de Oro" — Contexto, Modelo e Informe Económico

Documento de trabajo. Describe la situación actual del análisis sobre el dump
`cepo_de_oro.sql`, el modelo de fondos de la caja y el informe económico a construir.
Las queries desarrolladas se acumulan en `queries.sql`.

---

## 1. Situación actual

- Se analiza el dump `cepo_de_oro.sql` (MariaDB 10.4, export de phpMyAdmin) de una
  caja de ahorro y crédito comunitaria: ~57 cuentas de socios, ~1.900 entradas de
  recaudación, ~141 préstamos, 3 períodos.
- Objetivo: construir un **informe económico anual** (estado de situación + excedentes)
  a una fecha de corte, con queries SQL reproducibles.
- Los **ingresos** están tipificados en la base (`Entry_type`). Los **egresos NO están
  clasificados a nivel de base** — la clasificación E1–E7 se lleva fuera del sistema
  (la tabla `Discharge` tiene `type_id`, pero no se usa como fuente de clasificación).

## 2. Esquema de la base (16 tablas InnoDB)

### Socios y cuentas
| Tabla | Rol |
|---|---|
| `Person` | Datos personales del socio |
| `Account` | Cuenta del socio. `current_saving` acumula **solo tipo 8** por diseño: alimenta la regla de aporte mensual obligatorio (no es el ahorro total) |

### Ingresos (recaudación)
| Tabla | Rol |
|---|---|
| `Entry` | Evento de recaudación (recibo) por socio y fecha. Clave: `number`; FK `account_number`; la fecha real de cobro es `Entry.date` |
| `Entry_detail` | Desglose del recibo: `entry_number`, `type_id`, `value` |
| `Entry_type` | Catálogo de tipos de ingreso (ver mapeo I1–I11) |
| `Entry_bill_detail` | Forma de pago del recibo: `transfer` / `cash` |

### Egresos
| Tabla | Rol |
|---|---|
| `Discharge` | Egreso: `number`, `date`, `beneficiary`, `amount`, `type_id` (no se usa para clasificar), `period_id` |
| `Discharge_detail` | Descripción libre del egreso |
| `Discharge_bill_detail` | Forma de pago del egreso: `transfer` / `cash` |

### Préstamos
| Tabla | Rol |
|---|---|
| `Loan` | Préstamo otorgado. 4 préstamos deshabilitados (`enabled=0`), todos con valor 0 |
| `Loan_detail` | **Tabla de amortización completa creada al otorgar** el préstamo: una fila por cuota (`fee_value`=capital, `interest`, `fee_total`, `balance_after_pay`). Al cobrarse una cuota: `is_paid=1` y `entry_number` apunta al recibo (`Entry`) que la pagó. Varias cuotas pueden compartir un mismo recibo |
| `Loan_payment` | Abonos extraordinarios a capital (12 filas): reducen la deuda pero **no marcan cuotas como pagadas** — el aging puede sobrestimar mora en esos préstamos |

### Períodos
| Tabla | Rol |
|---|---|
| `Period` | Períodos contables (3) |
| `Period_account` | Cuentas por período |
| `Period_account_balance` | Saldos iniciales por cuenta/período |
| `Period_entry_type` | Tipos de ingreso habilitados por período |

### Advertencias del esquema
- Todas las columnas de dinero son `FLOAT` → **redondear en reportes** (`ROUND(x, 2)`).
- `Loan_detail.payment_date` es la fecha **programada**, no la de pago real. La fecha
  real es `Entry.date` vía `entry_number` (verificado: el recibo 995 del 2024-09-07
  pagó cuotas programadas hasta 2025-04).
- Cancelación anticipada condona intereses: `Loan_detail` conserva intereses
  programados nunca cobrados; el interés realmente cobrado vive en `Entry_detail`
  tipo 4.

## 3. Mapeo de ingresos (I) — `Entry_type`

| Código | `type_id` | Descripción |
|---|---|---|
| I1 | 1 | Aporte para gastos de administración |
| I2 | 2 | Fondo desgravamen |
| I3 | 3 | Cuota capital préstamo |
| I4 | 4 | Intereses préstamo |
| I5 | 5 | Intereses mora |
| I6 | 6 | Multas atrasos de aportes |
| I7 | 7 | Multa inasistencias |
| I8 | 8 | Aportes de capital |
| I9 | 9 | Aportes fondo estratégico |
| I10 | 10 | Depósitos a plazo fijo |
| I11 | 11 | Depósito ahorros |

## 4. Mapeo de egresos (E) — clasificación externa a la base

| Código | Tipo de egreso | Fondo que lo financia |
|---|---|---|
| E1 | Gastos administrativos | I1 |
| E2 | Alquileres | I1 |
| E3 | Devolución de excedentes | I4, I5, I6, I7 |
| E4 | Eventos | I9 |
| E5 | Retiros de socios | I3, I8, I11 (operativo; contablemente reduce I11 e I8 del socio) |
| E6 | Préstamos otorgados | I3, I8, I11 (operativo; contablemente convierte caja en cartera) |
| E7 | Compra de equipos | I1 |

## 5. Reglas del negocio (modelo de fondos)

1. **Ganancias = únicamente I4 + I5 + I6 + I7.** A fin de año se reparte el total
   acumulado como E3, de modo que esos fondos consolidan en **cero** tras el reparto.
2. **I1 es un fondo administrativo separado** (no repartible): financia E1, E2 y E7.
3. **Un porcentaje de E3 reingresa como I11** (ahorro obligatorio sobre las ganancias
   repartidas), lo que asegura liquidez al inicio del año siguiente.
4. **Caja única con fondos internos**: la liquidez se maneja por el total
   (Σ ingresos − Σ egresos). Un fondo puede quedar temporalmente negativo
   (préstamo entre fondos) y se repone con la recaudación siguiente.
5. **Control de fin de año**: se reduce la colocación de créditos hacia el cierre para
   que Fondos disponibles ≥ Σ(I4..I7) y el reparto de excedentes sea pagable en efectivo.
6. Los ahorros de socios a una fecha = Σ `Entry_detail.value` con `type_id IN (8, 11)`
   y `Entry.date <= corte`. `Account.current_saving` (solo tipo 8) es un acumulador de
   aporte obligatorio, no el ahorro total — no "corregirlo".

## 6. Informe económico a construir

Todas las sumatorias se evalúan con `Entry.date <= @fecha_corte` (ingresos) y
fecha de egreso `<= @fecha_corte` (egresos).

### A. Excedentes del período

| Ítem | Fórmula |
|---|---|
| Intereses de préstamos | Σ I4 |
| Intereses de mora | Σ I5 |
| Multas atrasos de aportes | Σ I6 |
| Multas inasistencias | Σ I7 |
| **Excedentes generados** | I4 + I5 + I6 + I7 |
| (−) Excedentes repartidos | Σ E3 |
| **Excedentes por repartir** | generados − repartidos |

Control: tras el reparto de fin de año esta línea debe ser **0**.

### B. Fondo administrativo

| Ítem | Fórmula |
|---|---|
| Aportes administración | Σ I1 |
| (−) Gastos administrativos | Σ E1 |
| (−) Alquileres | Σ E2 |
| (−) Compra de equipos | Σ E7 |
| **Saldo fondo administrativo** | I1 − E1 − E2 − E7 |

Control: si es negativo, los gastos están consumiendo otros fondos.

### C. Estado de situación

**Activo**
| Ítem | Fórmula |
|---|---|
| Fondos disponibles | Σ(I1…I11) − Σ(E1…E7) |
| Cartera de créditos | Σ E6 − Σ I3 |
| Propiedades y equipos | Σ E7 |

**Pasivo**
| Ítem | Fórmula |
|---|---|
| Ahorros socios | Σ I11 − (parte de E5 que devolvió ahorros) |
| Aportes socios | Σ I8 − (parte de E5 que devolvió aportes) |
| Depósitos a plazo fijo | Σ I10 |
| Fondo desgravamen | Σ I2 |
| Fondo estratégico | Σ I9 − Σ E4 |
| Excedentes por repartir | sección A |

**Patrimonio**
| Ítem | Fórmula |
|---|---|
| Fondo administrativo | sección B |
| Bienes de la caja | Σ E7 |

**Control global: TOTAL ACTIVO = TOTAL PASIVO + TOTAL PATRIMONIO** (cierra por
construcción si cada I/E se asigna a un solo lugar).

Notas:
- Los equipos aparecen dos veces a propósito: como activo (Bienes) y restando del
  fondo administrativo (el fondo "invirtió" su liquidez en un bien).
- Indicador de liquidez sugerido: Fondos disponibles ÷ (Ahorros + Aportes retirables).
- La cartera puede desglosarse en al día / vencida / dudosa (>3 meses) con la query
  de arrastre ya desarrollada en `queries.sql`, agregando una provisión por
  incobrables en negativo.

## 7. Queries ya desarrolladas (`queries.sql`)

- Capital prestado pendiente a fecha X = otorgado − cuotas pagadas (por `Entry.date`)
  − abonos de `Loan_payment`.
- Cartera por cobrar por cuota en baldes: al día / vencida / dudosa (>3 meses), con
  variante de **arrastre** (todo el saldo de un préstamo moroso va a dudoso) —
  recomendada para el balance.
- Ahorros de socios a fecha (tipos 8 + 11), por socio y total.
- Acumulado fondo desgravamen (tipo 2), por socio y total.
- Recaudación total por `Entry_type` hasta `@date`.

## 8. Pendientes

1. Traducir cada línea del informe (secciones A, B, C) a su query SQL. Las líneas de
   ingreso salen de `Entry_detail` por `type_id`; las de egreso requieren la
   clasificación externa E1–E7 como insumo.
2. Desglose efectivo vs transferencia (`Entry_bill_detail` / `Discharge_bill_detail`).
3. Saldos iniciales por período (`Period_account_balance`).
4. Sanity check: correr las queries de cartera contra un período conciliado a mano.
