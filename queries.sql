select round(sum(ed.value),2)
from Entry_detail ed
inner join Entry e on ed.entry_number = e.number
inner join Account a on e.account_number = a.number
inner join Person p on a.dni = p.dni
where ed.type_id in (4,5, 6)
    and e.period_id = 1

select e.account_number, p.names, p.surnames, e.number, round(sum(ed.value),2), e.date
from Entry_detail ed
inner join Entry e on ed.entry_number = e.number
inner join Account a on e.account_number = a.number
inner join Person p on a.dni = p.dni
where ed.type_id in (4,5, 6)
    and e.number >= 1646
group by e.number;

select e.account_number, p.names, p.surnames, e.number, round(sum(ed.value),2), e.date
from Entry_detail ed
inner join Entry e on ed.entry_number = e.number
inner join Account a on e.account_number = a.number
inner join Person p on a.dni = p.dni
where ed.type_id in (8)
    and e.number >= 1170
    and a.number = 3
group by e.number;


-- FECHA DE CORTE INFORME
  SET @date = '2026-01-12';

-- DINERO DISPONIBLE A ESA FECHA
select (
(select sum(e.amount) from Entry e where E.number>0 AND date <=@date)
-
(select sum(d.amount) from Discharge d where D.number>0 AND  date <=@date)
);
-- DINERO ADEUDADO DE CREDITOS A ESA FECHA
  SELECT
      ROUND(SUM(CASE WHEN ld.payment_date <= @date - INTERVAL 3 MONTH
                     THEN ld.fee_value ELSE 0 END), 2) AS doubtful_capital,
      ROUND(SUM(CASE WHEN ld.payment_date <= @date
                      AND ld.payment_date > @date - INTERVAL 3 MONTH
                     THEN ld.fee_value ELSE 0 END), 2) AS overdue_capital,
      ROUND(SUM(CASE WHEN ld.payment_date > @date
                     THEN ld.fee_value ELSE 0 END), 2) AS current_capital,
      ROUND(SUM(ld.fee_value), 2)                      AS total_receivable
  FROM Loan_detail ld
  JOIN Loan l       ON l.number = ld.loan_number
  LEFT JOIN Entry e ON e.number = ld.entry_number
  WHERE l.enabled = 1
    AND l.date <= @date
    AND ld.is_disabled = 0
    AND (ld.is_paid = 0 OR e.date > @date);

-- AHORRO DE SOCIOS A ESA FECHA

  SELECT ROUND(SUM(ed.value), 2) AS total_savings
  FROM Entry_detail ed
  JOIN Entry e ON e.number = ed.entry_number
  WHERE ed.type_id IN (8, 11)
    AND e.date <= @date;

-- FONDO DEGRAVAMEN A ESA FECHA

  SELECT ROUND(SUM(ed.value), 2) AS total_desgravamen
  FROM Entry_detail ed
  JOIN Entry e ON e.number = ed.entry_number
  WHERE ed.type_id = 2
    AND e.date <= @date;

-- FONDO ACTIVIDADES A ESA FECHA

  SELECT ROUND(SUM(ed.value), 2) AS total_actividades
  FROM Entry_detail ed
  JOIN Entry e ON e.number = ed.entry_number
  WHERE ed.type_id = 9
    AND e.date <= @date;

-- FONDO ADMINISTRACION A ESA FECHA

  SELECT ROUND(SUM(ed.value), 2) AS total_actividades
  FROM Entry_detail ed
  JOIN Entry e ON e.number = ed.entry_number
  WHERE ed.type_id = 1
    AND e.date <= @date;

-- INTERESES A ESA FECHA

  SELECT ROUND(SUM(ed.value), 2) AS total_actividades
  FROM Entry_detail ed
  JOIN Entry e ON e.number = ed.entry_number
  WHERE ed.type_id = 4
    AND e.date <= @date;

-- MORA A ESA FECHA

  SELECT ROUND(SUM(ed.value), 2) AS total_actividades
  FROM Entry_detail ed
  JOIN Entry e ON e.number = ed.entry_number
  WHERE ed.type_id = 5
    AND e.date <= @date;

-- MULTAS A ESA FECHA

  SELECT ROUND(SUM(ed.value), 2) AS total_actividades
  FROM Entry_detail ed
  JOIN Entry e ON e.number = ed.entry_number
  WHERE ed.type_id in(6,7)
    AND e.date <= @date;

  -- Total collected per entry type up to cutoff date
  SELECT et.id,
         et.description,
         ROUND(SUM(ed.value), 2) AS total_collected
  FROM Entry_detail ed
  JOIN Entry e ON e.number = ed.entry_number
  JOIN Entry_type et ON et.id = ed.type_id
  WHERE e.date <=  @date
  GROUP BY et.id, et.description
  ORDER BY et.id;
