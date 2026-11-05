"""방울토마토 스마트팜 프로토타입 계산 검증 (예시 데이터, SQLite)."""
import json
import sqlite3
from pathlib import Path
from datetime import datetime, timedelta

SQL_DIR = Path(__file__).resolve().parent / "sql"
SCHEMA = (SQL_DIR / "schema_sqlite.sql").read_text(encoding="utf-8")

DAY_START, DAY_END = 6, 18  # 낮 06:00~17:59
MARGIN = {"temperature": 0.5, "ec": 0.05}


def ts(d):
    return d.strftime("%Y-%m-%d %H:%M")


def period_of(dt):
    return "day" if DAY_START <= dt.hour < DAY_END else "night"


def seed(con):
    con.executescript(SCHEMA)
    con.execute("INSERT INTO crop_cycle VALUES(1,'예시 품종','2026-08-10',500,NULL,7.00,400)")
    for i, n in enumerate(["육묘", "정식·활착", "개화·착과 초기", "수확기"], 1):
        con.execute("INSERT INTO growth_stage VALUES(?,?,?)", (i, n, i))
    for sid, d in [(1, "2026-07-01"), (2, "2026-08-10"), (3, "2026-08-31"), (4, "2026-10-01")]:
        con.execute("INSERT INTO cycle_stage VALUES(1,?,?)", (sid, d))
    std = [
        ("ec", 1, "all", "optimal", 1.0, 1.5, "dS/m"), ("ec", 2, "all", "optimal", 1.7, 2.0, "dS/m"),
        ("ec", 3, "all", "optimal", 1.9, 2.1, "dS/m"), ("ec", 4, "all", "optimal", 2.0, 2.4, "dS/m"),
        ("ph", None, "all", "optimal", 5.5, 6.5, "-"), ("ph", None, "all", "warning", 5.0, 7.0, "-"),
        ("temperature", None, "day", "optimal", 21, 28, "℃"), ("temperature", None, "night", "optimal", 13, 18, "℃"),
        ("temperature", None, "day", "warning", None, 30, "℃"), ("temperature", None, "night", "warning", 10, 20, "℃"),
        ("temperature", None, "daily_avg", "warning", None, 25, "℃"), ("humidity", None, "all", "optimal", 60, 80, "%"),
        ("drain_rate", None, "daily", "optimal", 20, 30, "%"), ("irrigation_per_plant", None, "daily", "optimal", 0.5, 1.2, "L"),
    ]
    con.executemany("INSERT INTO cultivation_standard(parameter,stage_id,period,level,min_value,max_value,unit,source)"
                    " VALUES(?,?,?,?,?,?,?,'참고 범위')", std)

    # 환경 측정: 11-05 00:00~15:30, 1분 간격, 시간 기준점 사이 선형 보간
    knots = [(0, 0, 15.2), (1, 0, 14.8), (2, 0, 14.5), (3, 0, 14.1), (4, 0, 13.9), (5, 0, 13.8),
             (6, 0, 14.6), (7, 0, 16.9), (8, 0, 19.8), (9, 0, 22.4), (10, 0, 24.9), (11, 0, 26.8),
             (12, 0, 26.8), (13, 9, 28.0), (14, 0, 29.4), (14, 30, 29.6), (15, 0, 27.8),
             (15, 4, 27.6), (15, 5, 27.4), (15, 30, 27.0)]
    base = datetime(2026, 11, 5)
    pts = [(base + timedelta(hours=h, minutes=m), t) for h, m, t in knots]
    rows = []
    for (t0, v0), (t1, v1) in zip(pts, pts[1:]):
        n = int((t1 - t0).total_seconds() // 60)
        for k in range(n):
            rows.append((t0 + timedelta(minutes=k), round(v0 + (v1 - v0) * k / n, 2)))
    rows.append(pts[-1])
    temp = {dt: v for dt, v in rows}
    # 새벽 급랭 1분 (TC-10)
    temp[base + timedelta(hours=2, minutes=59)] = 14.0
    temp[base + timedelta(hours=3)] = 9.8
    temp[base + timedelta(hours=3, minutes=1)] = 14.0
    con.executemany("INSERT INTO env_reading VALUES(?,?,70,0,400)", [(ts(d), v) for d, v in sorted(temp.items())])

    # 급액: 11-03 600 L(30 L×20), 11-04 640 L(40 L×16), 11-05 412 L(30 L×10 + 28 L×4)
    ev = []
    for i in range(20):
        ev.append(("2026-11-03", 7 + i * 0.5, 30.0, 2.2))
    for i in range(16):
        ev.append(("2026-11-04", 7 + i * 0.6, 40.0, 2.2))
    for i in range(14):
        ev.append(("2026-11-05", 7 + i * 0.6, 30.0 if i < 10 else 28.0, 2.6 if i == 6 else 2.2))
    for d, h, v, ec in ev:
        dt = datetime.fromisoformat(d) + timedelta(hours=h)
        con.execute("INSERT INTO irrigation_event(cycle_id,irrigated_at,volume_l,ec,ph) VALUES(1,?,?,?,5.9)",
                    (ts(dt), v, ec))
    # 배액: 11-05 합계 99 L (9회 × 11 L)
    for i in range(9):
        dt = datetime(2026, 11, 5, 8) + timedelta(minutes=50 * i)
        con.execute("INSERT INTO drainage_event(cycle_id,measured_at,volume_l,ec) VALUES(1,?,11,3.1)", (ts(dt),))
    # 수확(이번 주 11-02~11-05): 상품 171 kg, 비상품 15 kg
    for d, mk, um in [("2026-11-02", 40, 4), ("2026-11-03", 45, 4), ("2026-11-04", 42, 3), ("2026-11-05", 44, 4)]:
        con.execute("INSERT INTO harvest(cycle_id,zone_id,harvest_date,grade,weight_kg) VALUES(1,1,?,'marketable',?)", (d, mk))
        con.execute("INSERT INTO harvest(cycle_id,zone_id,harvest_date,grade,weight_kg) VALUES(1,1,?,'unmarketable',?)", (d, um))
    for d in ["2026-11-02", "2026-11-03", "2026-11-04", "2026-11-05"]:
        con.execute("INSERT INTO auction_price VALUES(?,'가락시장','상','방울토마토',12000,4850)", (d,))


def current_stage(con, date):
    return con.execute("""SELECT g.stage_name, cs.stage_id FROM cycle_stage cs JOIN growth_stage g USING(stage_id)
        WHERE cs.cycle_id=1 AND cs.start_date<=? ORDER BY cs.start_date DESC LIMIT 1""", (date,)).fetchone()


def standards(con, parameter, stage_id, period):
    rows = con.execute("""SELECT standard_id, level, min_value, max_value FROM cultivation_standard
        WHERE parameter=? AND (stage_id IS NULL OR stage_id=?) AND period IN (?, 'all')""",
                       (parameter, stage_id, period)).fetchall()
    return {r[1]: r for r in rows}


def evaluate(value, stds):
    """(status, 기준행, 이탈 방향)"""
    w = stds.get("warning")
    if w and ((w[2] is not None and value < w[2]) or (w[3] is not None and value > w[3])):
        return "warning", w, ("low" if w[2] is not None and value < w[2] else "high")
    o = stds.get("optimal")
    if o and ((o[2] is not None and value < o[2]) or (o[3] is not None and value > o[3])):
        return "caution", o, ("low" if o[2] is not None and value < o[2] else "high")
    return "ok", None, None


def released(value, stds, parameter):
    o = stds["optimal"]
    m = MARGIN.get(parameter, 0)
    lo = o[2] + m if o[2] is not None else -1e9
    hi = o[3] - m if o[3] is not None else 1e9
    return lo <= value <= hi


class AlertEngine:
    def __init__(self, con):
        self.con, self.open = con, {}
        self.notifications = 0

    def feed(self, parameter, dt, value, stds):
        status, row, side = evaluate(value, stds)
        cur = self.open.get(parameter)
        if cur is None:
            if status != "ok":
                thr = row[3] if side == "high" else row[2]
                cid = self.con.execute("""INSERT INTO alert_log(cycle_id,standard_id,parameter,level,threshold_value,
                    peak_value,started_at) VALUES(1,?,?,?,?,?,?)""", (row[0], parameter, status, thr, value, ts(dt))).lastrowid
                self.open[parameter] = {"id": cid, "side": side, "peak": value, "level": status}
                self.notifications += 1
            return
        # 진행 중 경고: 최고값 갱신, 등급 상향, 해제 판단
        better = value > cur["peak"] if cur["side"] == "high" else value < cur["peak"]
        if better:
            cur["peak"] = value
            self.con.execute("UPDATE alert_log SET peak_value=? WHERE alert_id=?", (value, cur["id"]))
        if status == "warning" and cur["level"] == "caution":
            cur["level"] = "warning"
            self.con.execute("UPDATE alert_log SET level='warning', standard_id=?, threshold_value=? WHERE alert_id=?",
                             (row[0], row[3] if side == "high" else row[2], cur["id"]))
        if released(value, stds, parameter):
            self.con.execute("UPDATE alert_log SET ended_at=? WHERE alert_id=?", (ts(dt), cur["id"]))
            del self.open[parameter]


def run_alerts(con):
    eng = AlertEngine(con)
    stage_id = current_stage(con, "2026-11-05")[1]
    trace = {}
    for mt, t in con.execute("SELECT measured_at, temperature FROM env_reading ORDER BY measured_at").fetchall():
        dt = datetime.fromisoformat(mt)
        eng.feed("temperature", dt, t, standards(con, "temperature", stage_id, period_of(dt)))
        if mt in ("2026-11-05 15:00", "2026-11-05 15:04", "2026-11-05 15:05"):
            trace[mt] = ("open" if "temperature" in eng.open else "closed", t)
    for at, ec in con.execute("SELECT irrigated_at, ec FROM irrigation_event WHERE irrigated_at LIKE '2026-11-05%' ORDER BY irrigated_at"):
        eng.feed("ec", datetime.fromisoformat(at), ec, standards(con, "ec", stage_id, "all"))
    return eng, trace


DAILY_SQL = (SQL_DIR / "daily_summary.sql").read_text(encoding="utf-8").rstrip().rstrip(";")


def main():
    con = sqlite3.connect(":memory:")
    seed(con)
    eng, trace = run_alerts(con)
    R = {}
    day = dict(zip([c[0] for c in con.execute(DAILY_SQL, {"day": "2026-11-05"}).description],
                   con.execute(DAILY_SQL, {"day": "2026-11-05"}).fetchone()))
    R["daily_summary_1105"] = day
    R["TC-01"] = day["total_irrigation_l"]
    R["TC-02"] = day["irrigation_per_plant_l"]
    R["TC-03"] = day["drain_rate_pct"]
    R["TC-04"] = con.execute("SELECT SUM(volume_l) FROM irrigation_event WHERE date(irrigated_at) BETWEEN '2026-08-10' AND '2026-11-05'").fetchone()[0]
    st = current_stage(con, "2026-11-05")
    ec_std = standards(con, "ec", st[1], "all")["optimal"]
    R["TC-05"] = {"stage": st[0], "ec_min": ec_std[2], "ec_max": ec_std[3]}
    R["TC-06"] = {"2.2": evaluate(2.2, standards(con, "ec", st[1], "all"))[0],
                  "2.6": evaluate(2.6, standards(con, "ec", st[1], "all"))[0]}
    alerts = [dict(zip([c[0] for c in con.execute("SELECT * FROM alert_log").description], r))
              for r in con.execute("SELECT * FROM alert_log ORDER BY started_at")]
    R["alerts"] = alerts
    day_hot = [a for a in alerts if a["parameter"] == "temperature" and a["started_at"] >= "2026-11-05 12:00"]
    R["TC-07"] = day_hot
    over28 = con.execute("SELECT COUNT(*) FROM env_reading WHERE measured_at BETWEEN '2026-11-05 13:10' AND '2026-11-05 15:05' AND temperature>28").fetchone()[0]
    R["TC-08"] = {"minutes_over_28": over28, "alerts_in_window": len(day_hot)}
    R["TC-09"] = trace
    R["TC-10"] = [a for a in alerts if a["started_at"].startswith("2026-11-05 03:00")]

    # TC-11: 낮/밤 경계 (별도 DB)
    b = sqlite3.connect(":memory:")
    seed(b)
    b.execute("DELETE FROM env_reading")
    b.executemany("INSERT INTO env_reading VALUES(?,?,70,0,400)",
                  [("2026-11-05 05:59", 30.0), ("2026-11-05 06:00", 22.0), ("2026-11-05 12:00", 27.0), ("2026-11-05 17:59", 23.0), ("2026-11-05 18:00", 31.0)])
    R["TC-11"] = b.execute(DAILY_SQL, {"day": "2026-11-05"}).fetchone()[0]

    # TC-12: 연결 끊김 (별도 시나리오)
    last = datetime.fromisoformat("2026-11-05 14:02")
    now = datetime.fromisoformat("2026-11-05 14:08")
    gap = (now - last).total_seconds() / 60
    R["TC-12"] = {"gap_min": gap, "offline": gap > 5}

    wk = con.execute("""SELECT SUM(h.weight_kg), ROUND(SUM(h.weight_kg * p.avg_price_per_kg * (1 - c.commission_rate/100.0) - h.weight_kg * c.extra_cost_per_kg))
        FROM harvest h JOIN auction_price p ON p.price_date=h.harvest_date JOIN crop_cycle c ON c.cycle_id=h.cycle_id
        WHERE h.grade='marketable' AND h.harvest_date BETWEEN '2026-11-02' AND '2026-11-05'""").fetchone()
    R["TC-13"] = {"marketable_kg": wk[0], "expected_income": wk[1]}
    con.execute("UPDATE harvest SET settled_price_per_kg=4300 WHERE grade='marketable'")
    act = con.execute("""SELECT SUM(weight_kg * settled_price_per_kg) FROM harvest
        WHERE grade='marketable' AND settled_price_per_kg IS NOT NULL AND harvest_date BETWEEN '2026-11-02' AND '2026-11-05'""").fetchone()[0]
    R["TC-14"] = {"actual_income": act, "display": "actual" if act is not None else "expected"}
    R["TC-15"] = {"alert_count_view": day["alert_count"], "alert_rows": len([a for a in alerts if a["started_at"].startswith("2026-11-05")])}
    R["notifications"] = eng.notifications
    print(json.dumps(R, ensure_ascii=False, indent=1, default=str))


if __name__ == "__main__":
    main()
