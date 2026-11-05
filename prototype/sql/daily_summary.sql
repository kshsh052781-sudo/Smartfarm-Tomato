-- 일별 요약(daily_summary) 집계 쿼리. :day 에 'YYYY-MM-DD' 를 바인딩
WITH d AS (SELECT :day AS day),
env AS (SELECT
  MAX(CASE WHEN CAST(strftime('%H', measured_at) AS INT) BETWEEN 6 AND 17 THEN temperature END) AS max_day_temp,
  ROUND(AVG(CASE WHEN CAST(strftime('%H', measured_at) AS INT) NOT BETWEEN 6 AND 17 THEN temperature END), 1) AS avg_night_temp
  FROM env_reading WHERE date(measured_at)=:day),
irr AS (SELECT SUM(volume_l) AS total_irrigation_l FROM irrigation_event WHERE date(irrigated_at)=:day),
dr AS (SELECT SUM(volume_l) AS total_drainage_l FROM drainage_event WHERE date(measured_at)=:day),
hv AS (SELECT SUM(weight_kg) AS harvest_kg, SUM(CASE WHEN grade='marketable' THEN weight_kg END) AS marketable_kg
  FROM harvest WHERE harvest_date=:day),
pr AS (SELECT avg_price_per_kg AS market_avg_price FROM auction_price WHERE price_date=:day),
al AS (SELECT COUNT(*) AS alert_count FROM alert_log WHERE date(started_at)=:day)
SELECT env.max_day_temp, env.avg_night_temp, irr.total_irrigation_l,
  ROUND(irr.total_irrigation_l * 1.0 / c.plant_count, 3) AS irrigation_per_plant_l,
  dr.total_drainage_l, ROUND(dr.total_drainage_l * 100.0 / irr.total_irrigation_l, 2) AS drain_rate_pct,
  hv.harvest_kg, hv.marketable_kg, pr.market_avg_price,
  ROUND(hv.marketable_kg * pr.market_avg_price * (1 - c.commission_rate / 100.0) - hv.marketable_kg * c.extra_cost_per_kg) AS expected_income,
  al.alert_count
FROM env, irr, dr, hv, pr, al, crop_cycle c WHERE c.cycle_id=1;
