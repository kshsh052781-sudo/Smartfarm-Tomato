-- 방울토마토 스마트팜 프로토타입 스키마 (SQLite, 검증용)
CREATE TABLE crop_cycle(cycle_id INTEGER PRIMARY KEY, variety TEXT, planting_date TEXT,
  plant_count INT, end_date TEXT, commission_rate REAL, extra_cost_per_kg INT);
CREATE TABLE growth_stage(stage_id INTEGER PRIMARY KEY, stage_name TEXT, stage_order INT);
CREATE TABLE cycle_stage(cycle_id INT, stage_id INT, start_date TEXT, PRIMARY KEY(cycle_id, stage_id));
CREATE TABLE cultivation_standard(standard_id INTEGER PRIMARY KEY, parameter TEXT, stage_id INT,
  period TEXT, level TEXT, min_value REAL, max_value REAL, unit TEXT, source TEXT);
CREATE TABLE env_reading(measured_at TEXT PRIMARY KEY, temperature REAL, humidity REAL,
  solar_radiation REAL, co2 INT);
CREATE TABLE irrigation_event(irrigation_id INTEGER PRIMARY KEY, cycle_id INT, irrigated_at TEXT,
  volume_l REAL, ec REAL, ph REAL);
CREATE TABLE drainage_event(drainage_id INTEGER PRIMARY KEY, cycle_id INT, measured_at TEXT,
  volume_l REAL, ec REAL);
CREATE TABLE harvest(harvest_id INTEGER PRIMARY KEY, cycle_id INT, zone_id INT, harvest_date TEXT,
  grade TEXT, weight_kg REAL, settled_price_per_kg INT);
CREATE TABLE auction_price(price_date TEXT, market TEXT, grade TEXT, item TEXT, volume_kg REAL,
  avg_price_per_kg INT, PRIMARY KEY(price_date, market, grade));
CREATE TABLE alert_log(alert_id INTEGER PRIMARY KEY, cycle_id INT, standard_id INT, parameter TEXT,
  level TEXT, threshold_value REAL, peak_value REAL, started_at TEXT, ended_at TEXT,
  acknowledged_at TEXT, memo TEXT);
