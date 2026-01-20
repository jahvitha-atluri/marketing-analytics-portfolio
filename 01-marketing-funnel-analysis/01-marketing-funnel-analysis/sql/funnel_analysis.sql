/* ============================================================
   Project: Marketing Funnel & Conversion Analysis
   Funnel: Sessions -> Inquiries -> Bookings
   Tables expected: sessions, inquiries, bookings
   Columns expected:
     sessions(session_id, user_id, session_date, channel, device, campaign, cost)
     inquiries(inquiry_id, user_id, inquiry_date, channel, device)
     bookings(booking_id, user_id, booking_date, channel, device, revenue)
   ============================================================ */

-- 0) Quick row counts (sanity check)
SELECT 'sessions'  AS table_name, COUNT(*) AS rows FROM sessions
UNION ALL
SELECT 'inquiries' AS table_name, COUNT(*) AS rows FROM inquiries
UNION ALL
SELECT 'bookings'  AS table_name, COUNT(*) AS rows FROM bookings;


-- 1) Overall funnel (unique users) + conversion rates
WITH s AS (
  SELECT DISTINCT user_id FROM sessions
),
i AS (
  SELECT DISTINCT user_id FROM inquiries
),
b AS (
  SELECT DISTINCT user_id FROM bookings
),
counts AS (
  SELECT
    (SELECT COUNT(*) FROM s) AS sessions_users,
    (SELECT COUNT(*) FROM i) AS inquiry_users,
    (SELECT COUNT(*) FROM b) AS booking_users
)
SELECT
  sessions_users,
  inquiry_users,
  booking_users,
  ROUND(inquiry_users / NULLIF(sessions_users, 0) * 100, 2) AS session_to_inquiry_rate_pct,
  ROUND(booking_users / NULLIF(inquiry_users, 0) * 100, 2) AS inquiry_to_booking_rate_pct,
  ROUND(booking_users / NULLIF(sessions_users, 0) * 100, 2) AS session_to_booking_rate_pct
FROM counts;


-- 2) Funnel by channel (which channels bring high-quality users)
WITH s AS (
  SELECT channel, COUNT(DISTINCT user_id) AS sessions_users
  FROM sessions
  GROUP BY channel
),
i AS (
  SELECT channel, COUNT(DISTINCT user_id) AS inquiry_users
  FROM inquiries
  GROUP BY channel
),
b AS (
  SELECT channel, COUNT(DISTINCT user_id) AS booking_users
  FROM bookings
  GROUP BY channel
)
SELECT
  s.channel,
  s.sessions_users,
  COALESCE(i.inquiry_users, 0) AS inquiry_users,
  COALESCE(b.booking_users, 0) AS booking_users,
  ROUND(COALESCE(i.inquiry_users, 0) / NULLIF(s.sessions_users, 0) * 100, 2) AS session_to_inquiry_rate_pct,
  ROUND(COALESCE(b.booking_users, 0) / NULLIF(COALESCE(i.inquiry_users, 0), 0) * 100, 2) AS inquiry_to_booking_rate_pct,
  ROUND(COALESCE(b.booking_users, 0) / NULLIF(s.sessions_users, 0) * 100, 2) AS session_to_booking_rate_pct
FROM s
LEFT JOIN i ON s.channel = i.channel
LEFT JOIN b ON s.channel = b.channel
ORDER BY session_to_booking_rate_pct DESC;


-- 3) Funnel by device (detect UX friction: mobile vs desktop)
WITH s AS (
  SELECT device, COUNT(DISTINCT user_id) AS sessions_users
  FROM sessions
  GROUP BY device
),
i AS (
  SELECT device, COUNT(DISTINCT user_id) AS inquiry_users
  FROM inquiries
  GROUP BY device
),
b AS (
  SELECT device, COUNT(DISTINCT user_id) AS booking_users
  FROM bookings
  GROUP BY device
)
SELECT
  s.device,
  s.sessions_users,
  COALESCE(i.inquiry_users, 0) AS inquiry_users,
  COALESCE(b.booking_users, 0) AS booking_users,
  ROUND(COALESCE(i.inquiry_users, 0) / NULLIF(s.sessions_users, 0) * 100, 2) AS session_to_inquiry_rate_pct,
  ROUND(COALESCE(b.booking_users, 0) / NULLIF(COALESCE(i.inquiry_users, 0), 0) * 100, 2) AS inquiry_to_booking_rate_pct,
  ROUND(COALESCE(b.booking_users, 0) / NULLIF(s.sessions_users, 0) * 100, 2) AS session_to_booking_rate_pct
FROM s
LEFT JOIN i ON s.device = i.device
LEFT JOIN b ON s.device = b.device
ORDER BY session_to_booking_rate_pct DESC;


-- 4) Paid efficiency (cost per inquiry / cost per booking) if cost exists
WITH spend AS (
  SELECT channel, SUM(cost) AS total_cost
  FROM sessions
  GROUP BY channel
),
i AS (
  SELECT channel, COUNT(DISTINCT user_id) AS inquiry_users
  FROM inquiries
  GROUP BY channel
),
b AS (
  SELECT channel, COUNT(DISTINCT user_id) AS booking_users
  FROM bookings
  GROUP BY channel
)
SELECT
  spend.channel,
  ROUND(spend.total_cost, 2) AS total_cost,
  COALESCE(i.inquiry_users, 0) AS inquiry_users,
  COALESCE(b.booking_users, 0) AS booking_users,
  ROUND(spend.total_cost / NULLIF(COALESCE(i.inquiry_users, 0), 0), 2) AS cost_per_inquiry,
  ROUND(spend.total_cost / NULLIF(COALESCE(b.booking_users, 0), 0), 2) AS cost_per_booking
FROM spend
LEFT JOIN i ON spend.channel = i.channel
LEFT JOIN b ON spend.channel = b.channel
ORDER BY cost_per_booking ASC;


-- 5) Revenue by channel (which channels drive most value)
SELECT
  channel,
  COUNT(*) AS bookings,
  ROUND(SUM(revenue), 2) AS total_revenue,
  ROUND(AVG(revenue), 2) AS avg_revenue_per_booking
FROM bookings
GROUP BY channel
ORDER BY total_revenue DESC;
