-- 방울토마토 양액재배 스마트팜 DB 스키마 (MySQL 8 기준)
-- DB 테이블 설계서의 테이블 12개 + 일별 요약 뷰. 모든 시각은 KST.

CREATE TABLE crop_cycle (
  cycle_id          INT AUTO_INCREMENT PRIMARY KEY COMMENT '작기 번호',
  variety           VARCHAR(50)   NOT NULL COMMENT '품종명',
  planting_date     DATE          NOT NULL COMMENT '정식일',
  plant_count       INT           NOT NULL COMMENT '하우스 전체 포기 수',
  end_date          DATE          NULL     COMMENT '재배 종료일, 진행 중이면 NULL',
  commission_rate   DECIMAL(4,2)  NOT NULL COMMENT '도매시장 위탁수수료율 (%)',
  extra_cost_per_kg INT           NOT NULL COMMENT 'kg당 부대비용 (원/kg)'
) COMMENT '작기';

CREATE TABLE zone (
  zone_id     INT AUTO_INCREMENT PRIMARY KEY COMMENT '구역 번호',
  zone_name   VARCHAR(50) NOT NULL COMMENT '구역 이름 (예: A동 3번 줄)',
  plant_count INT         NOT NULL COMMENT '구역 포기 수'
) COMMENT '구역';

CREATE TABLE growth_stage (
  stage_id    INT AUTO_INCREMENT PRIMARY KEY COMMENT '단계 번호',
  stage_name  VARCHAR(30) NOT NULL COMMENT '단계 이름',
  stage_order INT         NOT NULL COMMENT '진행 순서'
) COMMENT '생육 단계';

CREATE TABLE cycle_stage (
  cycle_id   INT  NOT NULL COMMENT '작기 번호',
  stage_id   INT  NOT NULL COMMENT '단계 번호',
  start_date DATE NOT NULL COMMENT '해당 단계 시작일',
  PRIMARY KEY (cycle_id, stage_id),
  FOREIGN KEY (cycle_id) REFERENCES crop_cycle (cycle_id),
  FOREIGN KEY (stage_id) REFERENCES growth_stage (stage_id)
) COMMENT '작기별 생육 단계 이력';

CREATE TABLE cultivation_standard (
  standard_id INT AUTO_INCREMENT PRIMARY KEY COMMENT '기준 번호',
  parameter   VARCHAR(30)  NOT NULL COMMENT 'temperature, humidity, ec, ph, drain_rate, irrigation_per_plant',
  stage_id    INT          NULL     COMMENT '적용 단계, NULL이면 전 단계 공통',
  period      VARCHAR(10)  NOT NULL COMMENT 'day, night, daily_avg, daily, all',
  level       VARCHAR(10)  NOT NULL COMMENT 'optimal(적정), warning(경고)',
  min_value   DECIMAL(8,2) NULL     COMMENT '하한값',
  max_value   DECIMAL(8,2) NULL     COMMENT '상한값',
  unit        VARCHAR(20)  NOT NULL COMMENT '단위',
  source      VARCHAR(200) NULL     COMMENT '기준값 출처',
  FOREIGN KEY (stage_id) REFERENCES growth_stage (stage_id)
) COMMENT '재배 기준';

CREATE TABLE env_reading (
  measured_at     DATETIME     PRIMARY KEY COMMENT '측정 시각 (1분 단위)',
  temperature     DECIMAL(4,1) NULL COMMENT '내부 온도 (℃)',
  humidity        DECIMAL(4,1) NULL COMMENT '상대습도 (%)',
  solar_radiation DECIMAL(7,1) NULL COMMENT '순간 일사량 (W/m²)',
  co2             INT          NULL COMMENT 'CO₂ 농도 (ppm), 표시 전용'
) COMMENT '환경 측정';

CREATE TABLE irrigation_event (
  irrigation_id BIGINT AUTO_INCREMENT PRIMARY KEY COMMENT '급액 번호',
  cycle_id      INT          NOT NULL COMMENT '작기 번호',
  irrigated_at  DATETIME     NOT NULL COMMENT '급액 시각',
  volume_l      DECIMAL(8,2) NOT NULL COMMENT '1회 급액량, 하우스 전체 (L)',
  ec            DECIMAL(4,2) NULL     COMMENT '공급 EC (dS/m)',
  ph            DECIMAL(3,1) NULL     COMMENT '공급 pH',
  FOREIGN KEY (cycle_id) REFERENCES crop_cycle (cycle_id),
  INDEX idx_irrigation_time (irrigated_at)
) COMMENT '급액 기록';

CREATE TABLE drainage_event (
  drainage_id BIGINT AUTO_INCREMENT PRIMARY KEY COMMENT '배액 번호',
  cycle_id    INT          NOT NULL COMMENT '작기 번호',
  measured_at DATETIME     NOT NULL COMMENT '측정 시각',
  volume_l    DECIMAL(8,2) NOT NULL COMMENT '배액량 (L)',
  ec          DECIMAL(4,2) NULL     COMMENT '배액 EC (dS/m)',
  FOREIGN KEY (cycle_id) REFERENCES crop_cycle (cycle_id),
  INDEX idx_drainage_time (measured_at)
) COMMENT '배액 기록';

CREATE TABLE harvest (
  harvest_id           INT AUTO_INCREMENT PRIMARY KEY COMMENT '수확 번호',
  cycle_id             INT          NOT NULL COMMENT '작기 번호',
  zone_id              INT          NOT NULL COMMENT '수확 구역',
  harvest_date         DATE         NOT NULL COMMENT '수확일',
  grade                VARCHAR(15)  NOT NULL COMMENT 'marketable(상품), unmarketable(비상품)',
  weight_kg            DECIMAL(7,2) NOT NULL COMMENT '수확량 (kg)',
  settled_price_per_kg INT          NULL     COMMENT '정산 단가 (원/kg), 수수료·부대비용을 뗀 실수령 기준',
  FOREIGN KEY (cycle_id) REFERENCES crop_cycle (cycle_id),
  FOREIGN KEY (zone_id) REFERENCES zone (zone_id)
) COMMENT '수확 기록';

CREATE TABLE note (
  note_id    INT AUTO_INCREMENT PRIMARY KEY COMMENT '메모 번호',
  cycle_id   INT         NOT NULL COMMENT '작기 번호',
  written_at DATETIME    NOT NULL COMMENT '작성 시각',
  category   VARCHAR(20) NOT NULL COMMENT 'pesticide(농약), pest_disease(병해충), etc(기타)',
  content    TEXT        NOT NULL COMMENT '내용',
  FOREIGN KEY (cycle_id) REFERENCES crop_cycle (cycle_id)
) COMMENT '특이사항 메모';

CREATE TABLE auction_price (
  price_date       DATE          NOT NULL COMMENT '정산일자',
  market           VARCHAR(50)   NOT NULL COMMENT '도매시장',
  grade            VARCHAR(20)   NOT NULL COMMENT '등급 (API 등급 코드 기준)',
  item             VARCHAR(30)   NOT NULL COMMENT '품목',
  volume_kg        DECIMAL(10,1) NULL     COMMENT '거래량 (kg)',
  avg_price_per_kg INT           NOT NULL COMMENT '평균 가격 (원/kg)',
  PRIMARY KEY (price_date, market, grade)
) COMMENT '경매 가격';

CREATE TABLE alert_log (
  alert_id        BIGINT AUTO_INCREMENT PRIMARY KEY COMMENT '경고 번호',
  cycle_id        INT          NOT NULL COMMENT '작기 번호',
  standard_id     INT          NOT NULL COMMENT '벗어난 기준',
  parameter       VARCHAR(30)  NOT NULL COMMENT '항목 코드',
  level           VARCHAR(10)  NOT NULL COMMENT 'caution(적정 이탈), warning(경고 기준 초과)',
  threshold_value DECIMAL(8,2) NOT NULL COMMENT '발생 당시 기준값 (복사 저장)',
  peak_value      DECIMAL(8,2) NOT NULL COMMENT '경고 중 가장 심했던 값',
  started_at      DATETIME     NOT NULL COMMENT '시작 시각',
  ended_at        DATETIME     NULL     COMMENT '해제 시각, 진행 중이면 NULL',
  acknowledged_at DATETIME     NULL     COMMENT '확인 시각, 미확인이면 NULL',
  memo            VARCHAR(200) NULL     COMMENT '조치 내용',
  FOREIGN KEY (cycle_id) REFERENCES crop_cycle (cycle_id),
  FOREIGN KEY (standard_id) REFERENCES cultivation_standard (standard_id),
  INDEX idx_alert_started (started_at)
) COMMENT '경고 기록';

-- 일별 요약 뷰: 낮 06:00~17:59, 그 외 밤
CREATE VIEW daily_summary AS
SELECT
  d.summary_date,
  c.cycle_id,
  e.max_day_temp,
  e.avg_night_temp,
  e.avg_daily_temp,
  e.avg_humidity,
  e.total_solar_mj,
  e.avg_day_co2,
  i.total_irrigation_l,
  ROUND(i.total_irrigation_l / c.plant_count, 3)            AS irrigation_per_plant_l,
  dr.total_drainage_l,
  ROUND(dr.total_drainage_l / i.total_irrigation_l * 100, 1) AS drain_rate_pct,
  dr.avg_drain_ec,
  h.harvest_kg,
  h.marketable_kg,
  p.market_avg_price,
  ROUND(h.marketable_kg * p.market_avg_price * (1 - c.commission_rate / 100)
        - h.marketable_kg * c.extra_cost_per_kg)              AS expected_income,
  h.actual_income,
  COALESCE(a.alert_count, 0)                                  AS alert_count
FROM (
  SELECT DATE(measured_at) AS summary_date FROM env_reading GROUP BY DATE(measured_at)
) d
JOIN crop_cycle c
  ON d.summary_date BETWEEN c.planting_date AND COALESCE(c.end_date, '9999-12-31')
LEFT JOIN (
  SELECT DATE(measured_at) AS day,
    MAX(CASE WHEN HOUR(measured_at) BETWEEN 6 AND 17 THEN temperature END)       AS max_day_temp,
    ROUND(AVG(CASE WHEN HOUR(measured_at) NOT BETWEEN 6 AND 17 THEN temperature END), 1) AS avg_night_temp,
    ROUND(AVG(temperature), 1)                                                   AS avg_daily_temp,
    ROUND(AVG(humidity), 1)                                                      AS avg_humidity,
    ROUND(SUM(solar_radiation) * 60 / 1000000, 2)                                AS total_solar_mj,
    ROUND(AVG(CASE WHEN HOUR(measured_at) BETWEEN 6 AND 17 THEN co2 END))        AS avg_day_co2
  FROM env_reading GROUP BY DATE(measured_at)
) e ON e.day = d.summary_date
LEFT JOIN (
  SELECT cycle_id, DATE(irrigated_at) AS day, SUM(volume_l) AS total_irrigation_l
  FROM irrigation_event GROUP BY cycle_id, DATE(irrigated_at)
) i ON i.day = d.summary_date AND i.cycle_id = c.cycle_id
LEFT JOIN (
  SELECT cycle_id, DATE(measured_at) AS day, SUM(volume_l) AS total_drainage_l, ROUND(AVG(ec), 2) AS avg_drain_ec
  FROM drainage_event GROUP BY cycle_id, DATE(measured_at)
) dr ON dr.day = d.summary_date AND dr.cycle_id = c.cycle_id
LEFT JOIN (
  SELECT cycle_id, harvest_date AS day,
    SUM(weight_kg)                                                      AS harvest_kg,
    SUM(CASE WHEN grade = 'marketable' THEN weight_kg END)              AS marketable_kg,
    SUM(CASE WHEN settled_price_per_kg IS NOT NULL THEN weight_kg * settled_price_per_kg END) AS actual_income
  FROM harvest GROUP BY cycle_id, harvest_date
) h ON h.day = d.summary_date AND h.cycle_id = c.cycle_id
LEFT JOIN (
  SELECT price_date AS day, ROUND(AVG(avg_price_per_kg)) AS market_avg_price
  FROM auction_price GROUP BY price_date
) p ON p.day = d.summary_date
LEFT JOIN (
  SELECT cycle_id, DATE(started_at) AS day, COUNT(*) AS alert_count
  FROM alert_log GROUP BY cycle_id, DATE(started_at)
) a ON a.day = d.summary_date AND a.cycle_id = c.cycle_id;

-- 초기 데이터: 생육 단계와 재배 기준 (연구·일반 자료의 참고 범위, 농가 실제값으로 교체 권장)
INSERT INTO growth_stage (stage_name, stage_order) VALUES
  ('육묘', 1), ('정식·활착', 2), ('개화·착과 초기', 3), ('수확기', 4);

INSERT INTO cultivation_standard (parameter, stage_id, period, level, min_value, max_value, unit, source) VALUES
  ('ec', 1, 'all', 'optimal', 1.0, 1.5, 'dS/m', '참고 범위'),
  ('ec', 2, 'all', 'optimal', 1.7, 2.0, 'dS/m', '참고 범위'),
  ('ec', 3, 'all', 'optimal', 1.9, 2.1, 'dS/m', '참고 범위'),
  ('ec', 4, 'all', 'optimal', 2.0, 2.4, 'dS/m', '참고 범위'),
  ('ph', NULL, 'all', 'optimal', 5.5, 6.5, '-', '참고 범위'),
  ('ph', NULL, 'all', 'warning', 5.0, 7.0, '-', '참고 범위'),
  ('temperature', NULL, 'day', 'optimal', 21, 28, '℃', '참고 범위'),
  ('temperature', NULL, 'night', 'optimal', 13, 18, '℃', '참고 범위'),
  ('temperature', NULL, 'day', 'warning', NULL, 30, '℃', '참고 범위'),
  ('temperature', NULL, 'night', 'warning', 10, 20, '℃', '참고 범위'),
  ('temperature', NULL, 'daily_avg', 'warning', NULL, 25, '℃', '참고 범위'),
  ('humidity', NULL, 'all', 'optimal', 60, 80, '%', '참고 범위'),
  ('drain_rate', NULL, 'daily', 'optimal', 20, 30, '%', '참고 범위'),
  ('irrigation_per_plant', NULL, 'daily', 'optimal', 0.5, 1.2, 'L', '참고 범위');
