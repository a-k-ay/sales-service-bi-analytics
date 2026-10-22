"""
Synthetic ERP-style dataset for a BI practice project: a global maker of injection
molding machines, molds, hot runners and aftermarket services.

ALL DATA IS FAKE. Companies, products and figures are invented.

Run:  python scripts/generate_data.py
Output: data/*.csv

Deliberate data-quality issues are planted (see DQ_NOTES at bottom) so you
can practise data profiling and quality checks.
"""
import os
import random
from datetime import date, timedelta

import numpy as np
import pandas as pd

SEED = 42
random.seed(SEED)
np.random.seed(SEED)

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "data")
os.makedirs(OUT, exist_ok=True)

START = date(2024, 1, 1)
END = date(2026, 9, 30)
PERF_START = date(2025, 1, 1)  # machine telemetry window

# ------------------------------------------------------------------ regions
regions = pd.DataFrame([
    ("NA",   "North America",          "Americas", "America/Toronto"),
    ("LATAM","Latin America",          "Americas", "America/Sao_Paulo"),
    ("EU",   "Europe",                 "EMEA",     "Europe/Luxembourg"),
    ("MEA",  "Middle East & Africa",   "EMEA",     "Asia/Dubai"),
    ("IND",  "India & SAARC",          "APAC",     "Asia/Kolkata"),
    ("SEA",  "Southeast Asia",         "APAC",     "Asia/Singapore"),
    ("CNA",  "China & North Asia",     "APAC",     "Asia/Shanghai"),
], columns=["region_code", "region_name", "super_region", "service_center_tz"])

countries = {
    "NA":   ["Canada", "United States", "Mexico"],
    "LATAM":["Brazil", "Argentina", "Colombia", "Chile"],
    "EU":   ["Germany", "France", "Italy", "Poland", "Spain", "United Kingdom"],
    "MEA":  ["United Arab Emirates", "Saudi Arabia", "Egypt", "South Africa", "Nigeria"],
    "IND":  ["India", "Bangladesh", "Sri Lanka", "Pakistan"],
    "SEA":  ["Thailand", "Vietnam", "Indonesia", "Philippines"],
    "CNA":  ["China", "Japan", "South Korea"],
}
region_weight = {"NA": .16, "LATAM": .12, "EU": .20, "MEA": .14, "IND": .14, "SEA": .12, "CNA": .12}

# ------------------------------------------------------------------ products
# product_type: System (machine), Mold, HotRunner, Controller, Part, Service
products = [
    # code, name, family, type, industry, list_price_usd, std_cost_ratio
    ("SYS-PET-300",  "PET Preform System 300", "PET Systems", "System",     "Beverage",  1850000, .62),
    ("SYS-PET-400",  "PET Preform System 400", "PET Systems", "System",     "Beverage",  2300000, .61),
    ("SYS-PET-225",  "PET Preform System 225", "PET Systems", "System",     "Beverage",  1250000, .63),
    ("SYS-PET-CMP",  "PET Compact System",   "PET Systems", "System",     "Beverage",  1450000, .64),
    ("SYS-CLS-4",    "Closure System 4",     "Closure Systems", "System",     "Beverage",  1650000, .62),
    ("SYS-CLS-PRO",  "Closure System Pro",   "Closure Systems", "System",     "Beverage",  1900000, .60),
    ("SYS-PKG-TW",   "Thinwall Packaging System", "Packaging Systems", "System",     "Food & Consumer", 1550000, .63),
    ("SYS-PKG-EL",   "Electric Packaging System", "Packaging Systems", "System",     "Food & Consumer",  980000, .65),
    ("SYS-MED",      "Medical Molding System", "Medical Systems", "System",     "Medical",   1350000, .58),
    ("MLD-PET-96",   "PET Preform Mold 96-cav","PET Tooling","Mold",     "Beverage",   420000, .55),
    ("MLD-PET-144",  "PET Preform Mold 144-cav","PET Tooling","Mold",    "Beverage",   590000, .55),
    ("MLD-CAP-72",   "Closure Mold 72-cav",   "Closure Molds","Mold",      "Beverage",   310000, .56),
    ("MLD-MED",      "Medical Precision Mold", "Medical Molds", "Mold",       "Medical",    360000, .52),
    ("HR-STD",       "Hot Runner Standard",     "Hot Runners","HotRunner", "Multi",       85000, .50),
    ("HR-ADV",       "Hot Runner Advanced",     "Hot Runners","HotRunner", "Multi",      110000, .49),
    ("HR-MOD",       "Hot Runner Modular",      "Hot Runners","HotRunner", "Multi",       64000, .52),
    ("HR-CMP",       "Hot Runner Compact",      "Hot Runners","HotRunner", "Multi",       38000, .55),
    ("CTL-BASIC",    "Hot Runner Controller Basic", "Controllers","Controller","Multi",       42000, .45),
    ("CTL-MULTI",    "Hot Runner Controller Multi", "Controllers","Controller","Multi",       56000, .47),
    ("PRT-NOZTIP",   "Nozzle Tip Kit",        "Spare Parts","Part",      "Multi",        1200, .35),
    ("PRT-HEATER",   "Heater Band",           "Spare Parts","Part",      "Multi",         450, .30),
    ("PRT-SCREW",    "Injection Screw",       "Spare Parts","Part",      "Multi",       18500, .40),
    ("PRT-SEALKIT",  "Seal Kit",              "Spare Parts","Part",      "Multi",         780, .28),
    ("PRT-THERMO",   "Thermocouple Set",      "Spare Parts","Part",      "Multi",         620, .30),
    ("PRT-VALVE",    "Hydraulic Valve",       "Spare Parts","Part",      "Multi",        3400, .38),
    ("PRT-COREINS",  "Core Insert",           "Spare Parts","Part",      "Multi",        2600, .36),
    ("SVC-RM-BRZ",   "Remote Monitoring Bronze (annual)","Remote Monitoring","Service","Multi",  18000, .40),
    ("SVC-RM-SLV",   "Remote Monitoring Silver (annual)","Remote Monitoring","Service","Multi",  32000, .38),
    ("SVC-RM-GLD",   "Remote Monitoring Gold (annual)","Remote Monitoring","Service","Multi",  48000, .36),
    ("SVC-RM-PLT",   "Remote Monitoring Platinum (annual)","Remote Monitoring","Service","Multi",  72000, .34),
    ("SVC-REFURB",   "Hot Runner Refurbishment",      "Lifecycle", "Service","Multi",  22000, .55),
    ("SVC-TRAIN",    "Training Course",       "Lifecycle", "Service","Multi",   4500, .30),
]
dim_product = pd.DataFrame(products, columns=[
    "product_code", "product_name", "product_family", "product_type",
    "industry", "list_price_usd", "std_cost_ratio"])
dim_product.insert(0, "product_id", range(1, len(dim_product) + 1))
dim_product["std_cost_usd"] = (dim_product.list_price_usd * dim_product.std_cost_ratio).round(2)
dim_product = dim_product.drop(columns="std_cost_ratio")
dim_product["is_active"] = 1

# ------------------------------------------------------------------ customers
seg_by_industry = {"Beverage": .5, "Food & Consumer": .3, "Medical": .2}
name_a = ["Aqua", "Blue", "Crystal", "Delta", "Evergreen", "Falcon", "Golden", "Horizon",
          "Indus", "Jade", "Kestrel", "Lotus", "Meridian", "Nova", "Orion", "Pacific",
          "Quantum", "River", "Summit", "Terra", "Unity", "Vertex", "Willow", "Zenith"]
name_b = ["Packaging", "Beverages", "Plastics", "Polymers", "Bottling", "Closures",
          "MedTech", "Containers", "Industries", "Pack Solutions", "Foods", "Healthcare"]
suffix = ["Ltd", "Inc", "GmbH", "S.A.", "Pvt Ltd", "LLC", "Co.", "SpA", "PLC"]

N_CUST = 320
cust_rows = []
used = set()
for i in range(1, N_CUST + 1):
    rc = np.random.choice(list(region_weight), p=list(region_weight.values()))
    country = random.choice(countries[rc])
    ind = np.random.choice(list(seg_by_industry), p=list(seg_by_industry.values()))
    while True:
        nm = f"{random.choice(name_a)} {random.choice(name_b)} {random.choice(suffix)}"
        if nm not in used:
            used.add(nm); break
    tier = np.random.choice(["Strategic", "Key", "Standard"], p=[.10, .30, .60])
    created = START - timedelta(days=random.randint(0, 3650))
    cust_rows.append((i, f"C{100000 + i}", nm, ind, tier, country, rc, created.isoformat()))
dim_customer = pd.DataFrame(cust_rows, columns=[
    "customer_id", "customer_number", "customer_name", "industry_segment",
    "account_tier", "country", "region_code", "created_date"])

# ------------------------------------------------------------------ installed base (machines)
system_products = dim_product[dim_product.product_type == "System"]
bev = system_products[system_products.industry == "Beverage"].product_id.tolist()
food = system_products[system_products.industry == "Food & Consumer"].product_id.tolist()
med = system_products[system_products.industry == "Medical"].product_id.tolist()
pool = {"Beverage": bev, "Food & Consumer": food, "Medical": med}

tiers = ["No Contract", "Bronze", "Silver", "Gold", "Platinum"]
mach_rows = []
mid = 0
for _, c in dim_customer.iterrows():
    n = {"Strategic": random.randint(3, 8), "Key": random.randint(1, 4), "Standard": random.randint(0, 2)}[c.account_tier]
    for _ in range(n):
        mid += 1
        pid = random.choice(pool[c.industry_segment])
        inst = START + timedelta(days=random.randint(-3000, (END - START).days))  # ~1/4 installed during window
        p_tier = [.30, .20, .20, .15, .15] if c.account_tier != "Standard" else [.55, .25, .12, .05, .03]
        tier = np.random.choice(tiers, p=p_tier)
        mach_rows.append((mid, f"MCH-{random.randint(10, 99)}{mid:05d}", c.customer_id, pid,
                          inst.isoformat(), tier))
dim_machine = pd.DataFrame(mach_rows, columns=[
    "machine_id", "serial_number", "customer_id", "product_id", "install_date", "monitoring_tier"])

# ------------------------------------------------------------------ sales orders (header + lines)
reps = [f"REP{n:03d}" for n in range(1, 41)]
rep_region = {r: np.random.choice(list(region_weight)) for r in reps}
order_rows, line_rows = [], []
oid, lid = 0, 0
days = (END - START).days

def order_date():
    d = START + timedelta(days=random.randint(0, days))
    return d

# 1) capital orders: one per installed machine within window, plus molds/hot runners
for _, m in dim_machine.iterrows():
    inst = date.fromisoformat(m.install_date)
    od = inst - timedelta(days=random.randint(90, 240))
    if od < START:
        continue  # ordered before our ERP history starts
    oid += 1
    cust = dim_customer.loc[m.customer_id - 1]
    order_rows.append((oid, f"SO{2000000 + oid}", od.isoformat(), int(m.customer_id),
                       random.choice([r for r in reps if rep_region[r] == cust.region_code] or reps),
                       "Capital", "Closed"))
    base = dim_product.loc[m.product_id - 1]
    lid += 1
    disc = round(random.uniform(0.03, 0.18), 3)
    line_rows.append((lid, oid, 1, int(base.product_id), 1, float(base.list_price_usd), disc))
    # attach a mold for preform/closure systems
    if base.industry == "Beverage":
        mold = 10 if random.random() < .6 else 11
        if base.product_family == "Closure Systems":
            mold = 12
        lid += 1
        line_rows.append((lid, oid, 2, mold, 1, float(dim_product.loc[mold - 1].list_price_usd), disc))

# 1b) capital backlog: systems ordered recently, not yet installed (no machine record yet)
for _ in range(45):
    oid += 1
    od = END - timedelta(days=random.randint(0, 240))
    c = int(dim_customer.sample(1).customer_id.iloc[0])
    seg = dim_customer.loc[c - 1].industry_segment
    pid = random.choice(pool[seg])
    order_rows.append((oid, f"SO{2000000 + oid}", od.isoformat(), c, random.choice(reps), "Capital", "Closed"))
    lid += 1
    line_rows.append((lid, oid, 1, pid, 1, float(dim_product.loc[pid - 1].list_price_usd),
                      round(random.uniform(0.03, 0.18), 3)))

# 2) hot runner / controller orders (independent mold-makers & automotive etc.)
hr_ids = dim_product[dim_product.product_type.isin(["HotRunner", "Controller"])].product_id.tolist()
for _ in range(1100):
    oid += 1
    od = order_date()
    c = random.randint(1, N_CUST)
    order_rows.append((oid, f"SO{2000000 + oid}", od.isoformat(), c, random.choice(reps), "HotRunner", "Closed"))
    for ln in range(1, random.randint(1, 3) + 1):
        lid += 1
        pid = random.choice(hr_ids)
        line_rows.append((lid, oid, ln, pid, random.randint(1, 2),
                          float(dim_product.loc[pid - 1].list_price_usd), round(random.uniform(0, .12), 3)))

# 3) aftermarket parts orders - seasonal, growing over time
part_ids = dim_product[dim_product.product_type == "Part"].product_id.tolist()
for _ in range(9000):
    oid += 1
    od = order_date()
    growth = 1 + (od - START).days / days * 0.25
    c = random.randint(1, N_CUST)
    order_rows.append((oid, f"SO{2000000 + oid}", od.isoformat(), c, random.choice(reps), "Aftermarket", "Closed"))
    for ln in range(1, random.randint(1, 5) + 1):
        lid += 1
        pid = random.choice(part_ids)
        qty = max(1, int(np.random.poisson(4 * growth)))
        line_rows.append((lid, oid, ln, pid, qty,
                          float(dim_product.loc[pid - 1].list_price_usd), round(random.uniform(0, .08), 3)))

# 4) service contracts - annual renewals for monitored machines
tier_prod = {"Bronze": 27, "Silver": 28, "Gold": 29, "Platinum": 30}
for _, m in dim_machine[dim_machine.monitoring_tier != "No Contract"].iterrows():
    first = max(date.fromisoformat(m.install_date), date(2021, 6, 1))
    y = START.year
    while date(y, first.month, min(first.day, 28)) <= END:
        od = date(y, first.month, min(first.day, 28))
        if od >= START and od >= first:
            oid += 1
            order_rows.append((oid, f"SO{2000000 + oid}", od.isoformat(), int(m.customer_id),
                               random.choice(reps), "Service", "Closed"))
            lid += 1
            pid = tier_prod[m.monitoring_tier]
            line_rows.append((lid, oid, 1, pid, 1, float(dim_product.loc[pid - 1].list_price_usd),
                              round(random.uniform(0, .10), 3)))
        y += 1

sales_order = pd.DataFrame(order_rows, columns=[
    "order_id", "order_number", "order_date", "customer_id", "sales_rep_id", "order_type", "order_status"])
sales_order = sales_order.sort_values("order_date").reset_index(drop=True)
sales_order_line = pd.DataFrame(line_rows, columns=[
    "order_line_id", "order_id", "line_number", "product_id", "quantity", "unit_list_price_usd", "discount_pct"])
sales_order_line["net_amount_usd"] = (
    sales_order_line.quantity * sales_order_line.unit_list_price_usd * (1 - sales_order_line.discount_pct)).round(2)

# recent orders still open / some cancelled
recent = sales_order.order_date >= (END - timedelta(days=60)).isoformat()
sales_order.loc[recent, "order_status"] = np.random.choice(["Open", "Shipped", "Closed"], size=recent.sum(), p=[.5, .3, .2])
cancel_idx = sales_order.sample(frac=.02, random_state=SEED).index
sales_order.loc[cancel_idx, "order_status"] = "Cancelled"

# ship date
def ship(row):
    if row.order_status in ("Open", "Cancelled"):
        return None
    lead = {"Capital": (90, 200), "HotRunner": (20, 60), "Aftermarket": (1, 14), "Service": (0, 0)}[row.order_type]
    return (date.fromisoformat(row.order_date) + timedelta(days=random.randint(*lead))).isoformat()
sales_order["ship_date"] = sales_order.apply(ship, axis=1)
# anything that would ship after the data cut-off is still open (backlog)
future = sales_order.ship_date.notna() & (sales_order.ship_date > END.isoformat())
sales_order.loc[future, ["order_status", "ship_date"]] = ["Open", None]

# ------------------------------------------------------------------ machine daily performance (telemetry)
perf_rows = []
perf_days = (END - PERF_START).days + 1
tier_effect = {"No Contract": 0.0, "Bronze": .01, "Silver": .02, "Gold": .03, "Platinum": .045}
for _, m in dim_machine.iterrows():
    inst = date.fromisoformat(m.install_date)
    base_avail = random.uniform(.80, .93) + tier_effect[m.monitoring_tier]
    base_perf = random.uniform(.85, .96) + tier_effect[m.monitoring_tier] / 2
    base_qual = random.uniform(.975, .996)
    rate = int(np.random.choice([18000, 24000, 30000, 40000]))  # parts/hour at full speed
    for d in range(perf_days):
        day = PERF_START + timedelta(days=d)
        if day < inst:
            continue
        planned = 24.0 if random.random() > .04 else round(random.uniform(0, 16), 1)
        if planned == 0:
            continue
        avail = min(1, max(0, np.random.normal(base_avail, .05)))
        run = round(planned * avail, 2)
        perf = min(1, max(.5, np.random.normal(base_perf, .03)))
        total = int(run * rate * perf)
        qual = min(1, max(.85, np.random.normal(base_qual, .006)))
        good = int(total * qual)
        perf_rows.append((int(m.machine_id), day.isoformat(), planned, run, rate, total, good, total - good))
fact_perf = pd.DataFrame(perf_rows, columns=[
    "machine_id", "perf_date", "planned_hours", "run_hours", "ideal_rate_per_hour",
    "total_parts", "good_parts", "scrap_parts"])

# ------------------------------------------------------------------ service tickets
cats = ["Hot Runner Leak", "Heater Failure", "Hydraulic Pressure", "Robot / Post-Mold",
        "Controller Alarm", "Dimensional Quality", "Software / HMI", "Preventive Maintenance"]
cat_p = [.14, .16, .12, .10, .14, .12, .07, .15]
t_rows = []
tid = 0
for _, m in dim_machine.iterrows():
    inst = date.fromisoformat(m.install_date)
    lam = {"No Contract": 9, "Bronze": 8, "Silver": 7, "Gold": 6, "Platinum": 5}[m.monitoring_tier]
    n = np.random.poisson(lam * 2.5)
    for _ in range(n):
        od = START + timedelta(days=random.randint(0, days))
        if od < inst:
            continue
        tid += 1
        cat = np.random.choice(cats, p=cat_p)
        monitored = m.monitoring_tier != "No Contract"
        if monitored and random.random() < .55:
            channel = "Remote Monitoring Alert"
        else:
            channel = np.random.choice(["Phone", "Email", "Portal"], p=[.5, .3, .2])
        prio = np.random.choice(["P1", "P2", "P3"], p=[.15, .45, .40])
        resol = np.random.choice(["Remote", "Phone Support", "Technician Visit"],
                                 p=[.45, .25, .30] if monitored else [.10, .35, .55])
        base_h = {"Remote": 3, "Phone Support": 6, "Technician Visit": 30}[resol]
        if monitored:
            base_h *= .6
        hrs = round(max(.25, np.random.gamma(2, base_h / 2)), 2)
        opened = pd.Timestamp(od) + pd.Timedelta(hours=random.randint(0, 23))
        closed = (opened + pd.Timedelta(hours=hrs)).floor("min")
        status = "Closed"
        if od > END - timedelta(days=10) and random.random() < .5:
            status, closed = "Open", None
        downtime = round(hrs * random.uniform(.3, 1.0), 2) if cat != "Preventive Maintenance" else 0
        t_rows.append((tid, f"TCK{500000 + tid}", int(m.machine_id), int(m.customer_id),
                       opened.isoformat(sep=" "), None if closed is None else closed.isoformat(sep=" "),
                       cat, prio, channel, resol, status, downtime))
service_ticket = pd.DataFrame(t_rows, columns=[
    "ticket_id", "ticket_number", "machine_id", "customer_id", "opened_at", "closed_at",
    "issue_category", "priority", "channel", "resolution_type", "status", "downtime_hours"])

# ------------------------------------------------------------------ PLANT DATA QUALITY ISSUES
rng = np.random.default_rng(SEED)
# DQ1: duplicate customers (same company, different number, inconsistent spelling) -> MDM practice
dups = dim_customer.sample(6, random_state=1).copy()
dups["customer_id"] = range(N_CUST + 1, N_CUST + 7)
dups["customer_number"] = [f"C{900000 + i}" for i in range(6)]
dups["customer_name"] = dups.customer_name.str.upper().str.replace("LTD", "LIMITED")
dim_customer = pd.concat([dim_customer, dups], ignore_index=True)
# ...and some orders/tickets were booked against the duplicate records (so MDM actually matters)
for orig_id, dup_id in zip(dups.index + 1, dups.customer_id):
    o_idx = sales_order[sales_order.customer_id == orig_id].index
    sales_order.loc[o_idx[: len(o_idx) // 3], "customer_id"] = dup_id
    t_idx = service_ticket[service_ticket.customer_id == orig_id].index
    service_ticket.loc[t_idx[: len(t_idx) // 3], "customer_id"] = dup_id
# DQ2: inconsistent country spellings
for idx, bad in zip(dim_customer.sample(8, random_state=2).index,
                    ["USA", "U.S.A.", "UAE", "india", "Deutschland", "KSA", "Viet Nam", "UK"]):
    dim_customer.loc[idx, "country"] = bad
# DQ3: missing account tier / segment
dim_customer.loc[dim_customer.sample(5, random_state=3).index, "account_tier"] = None
# DQ4: orphan order lines (product_id that does not exist)
orph = sales_order_line.sample(12, random_state=4).index
sales_order_line.loc[orph, "product_id"] = 999
# DQ5: negative / zero quantity lines
sales_order_line.loc[sales_order_line.sample(7, random_state=5).index, "quantity"] = -1
sales_order_line["net_amount_usd"] = (
    sales_order_line.quantity * sales_order_line.unit_list_price_usd * (1 - sales_order_line.discount_pct)).round(2)
# DQ6: exact duplicate ticket rows
service_ticket = pd.concat([service_ticket, service_ticket.sample(15, random_state=6)], ignore_index=True)
# DQ7: tickets closed before opened
bad_t = service_ticket[service_ticket.closed_at.notna()].sample(6, random_state=7).index
service_ticket.loc[bad_t, "closed_at"] = (
    pd.to_datetime(service_ticket.loc[bad_t, "opened_at"]) - pd.Timedelta(hours=5)).astype(str)
# DQ8: telemetry where good_parts > total_parts and null run_hours
bad_p = fact_perf.sample(20, random_state=8).index
fact_perf.loc[bad_p, "good_parts"] = fact_perf.loc[bad_p, "total_parts"] + 500
fact_perf.loc[fact_perf.sample(25, random_state=9).index, "run_hours"] = np.nan

# ------------------------------------------------------------------ write
tables = {
    "dim_region": regions,
    "dim_customer": dim_customer,
    "dim_product": dim_product,
    "dim_machine": dim_machine,
    "sales_order": sales_order,
    "sales_order_line": sales_order_line,
    "service_ticket": service_ticket,
    "machine_daily_performance": fact_perf,
}
for name, df in tables.items():
    df.to_csv(os.path.join(OUT, f"{name}.csv"), index=False, lineterminator="\n")
    print(f"{name:28s} {len(df):>8,} rows")
