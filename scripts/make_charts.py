"""
Builds the README charts straight from the PostgreSQL database.

Usage (from the repo root, with the database loaded):
    python scripts/make_charts.py

Connection settings come from the standard PG* environment variables
(PGHOST, PGPORT, PGUSER, PGDATABASE), the same ones psql uses.
"""
import io
import subprocess
from pathlib import Path

import matplotlib.pyplot as plt
import matplotlib.ticker as mtick
import pandas as pd

OUT = Path("images")
OUT.mkdir(exist_ok=True)

# Palette (validated categorical slots, light mode)
BLUE = "#2a78d6"      # primary series
ORANGE = "#eb6834"    # emphasis: the thing we want the reader to notice
GRAY = "#b9b8b2"      # context
SURFACE = "#fcfcfb"
INK = "#0b0b0b"
INK_2 = "#52514e"

plt.rcParams.update({
    "figure.facecolor": SURFACE, "axes.facecolor": SURFACE,
    "savefig.facecolor": SURFACE, "font.family": "DejaVu Sans",
    "font.size": 11, "axes.edgecolor": "#d6d5cf", "axes.labelcolor": INK_2,
    "xtick.color": INK_2, "ytick.color": INK_2, "axes.spines.top": False,
    "axes.spines.right": False, "axes.grid": True, "grid.color": "#ecebe6",
    "grid.linewidth": 0.8, "axes.axisbelow": True,
    "axes.titlesize": 14, "axes.titleweight": "bold", "axes.titlecolor": INK,
    "axes.titlelocation": "left", "axes.titlepad": 26,
})


def q(sql: str) -> pd.DataFrame:
    """Run a query with psql and return the result as a DataFrame."""
    res = subprocess.run(
        ["psql", "-X", "-v", "ON_ERROR_STOP=1", "--csv", "-c",
         f"SET search_path TO olist; {sql}"],
        capture_output=True, text=True, check=True,
    )
    # psql prints "SET" first; the CSV starts on the next line
    return pd.read_csv(io.StringIO(res.stdout.split("\n", 1)[1]))


def subtitle(ax, text):
    ax.text(0, 1.02, text, transform=ax.transAxes, color=INK_2, fontsize=10.5)


def save(fig, name):
    fig.tight_layout()
    fig.savefig(OUT / name, dpi=160)
    plt.close(fig)
    print("wrote", OUT / name)


# 1. Monthly GMV -------------------------------------------------------------
df = q("""SELECT order_month, SUM(items_value)/1000 AS gmv_k
          FROM v_sales GROUP BY 1 ORDER BY 1""")
df["order_month"] = pd.to_datetime(df["order_month"])
fig, ax = plt.subplots(figsize=(10, 4.8))
colors = [ORANGE if d.month == 11 and d.year == 2017 else BLUE for d in df["order_month"]]
ax.bar(df["order_month"], df["gmv_k"], width=22, color=colors)
ax.set_title("GMV more than doubled year over year, then plateaued in 2018")
subtitle(ax, "Monthly product sales (BRL thousands), Jan 2017 – Aug 2018")
nov = df[df["order_month"] == "2017-11-01"].iloc[0]
ax.annotate("Black Friday\nNov 2017", (nov["order_month"], nov["gmv_k"]),
            xytext=(0, 8), textcoords="offset points", ha="center",
            color=INK, fontsize=10)
ax.yaxis.set_major_formatter(mtick.FuncFormatter(lambda v, _: f"{v:,.0f}k"))
ax.set_ylim(0, df["gmv_k"].max() * 1.18)
ax.grid(axis="x", visible=False)
save(fig, "01_monthly_gmv.png")

# 2. Delivery vs review -----------------------------------------------------
df = q("""SELECT CASE
             WHEN days_late <= -10 THEN '10+ days early'
             WHEN days_late <= -1  THEN '1-9 days early'
             WHEN days_late =  0   THEN 'On the day'
             WHEN days_late <= 3   THEN '1-3 days late'
             WHEN days_late <= 7   THEN '4-7 days late'
             ELSE '8+ days late' END AS bucket,
             MIN(days_late) AS k, AVG(review_score) AS avg_review
          FROM v_delivered WHERE review_score IS NOT NULL
          GROUP BY 1 ORDER BY k""")
fig, ax = plt.subplots(figsize=(10, 4.8))
colors = [ORANGE if "late" in b else BLUE for b in df["bucket"]]
bars = ax.bar(df["bucket"], df["avg_review"], color=colors, width=0.62)
for b, v in zip(bars, df["avg_review"]):
    ax.text(b.get_x() + b.get_width() / 2, v + 0.08, f"{v:.2f}",
            ha="center", color=INK, fontsize=11, fontweight="bold")
ax.set_title("A late delivery costs more than 2 stars")
subtitle(ax, "Average review score by delivery date vs. the date promised at checkout")
ax.set_ylim(0, 5.2)
ax.set_ylabel("Avg review (1–5)")
ax.grid(axis="x", visible=False)
save(fig, "02_delivery_vs_review.png")

# 3. RFM segments ------------------------------------------------------------
rfm_sql = Path("sql/analysis/04_rfm_segmentation.sql").read_text()
rfm_sql = rfm_sql.split("SET search_path TO olist;", 1)[1]
df = q(rfm_sql).sort_values("pct_gmv")
fig, ax = plt.subplots(figsize=(10, 5))
y = range(len(df))
ax.barh([i + 0.2 for i in y], df["pct_customers"], height=0.38, color=GRAY,
        label="% of customers")
ax.barh([i - 0.2 for i in y], df["pct_gmv"], height=0.38, color=BLUE,
        label="% of GMV")
for i, (c, g) in enumerate(zip(df["pct_customers"], df["pct_gmv"])):
    ax.text(g + 0.4, i - 0.2, f"{g:.0f}%", va="center", color=INK, fontsize=10)
    ax.text(c + 0.4, i + 0.2, f"{c:.0f}%", va="center", color=INK_2, fontsize=10)
ax.set_yticks(list(y), df["segment"])
ax.xaxis.set_major_formatter(mtick.PercentFormatter(decimals=0))
ax.set_title("30% of customers drive 58% of revenue, and half of them have gone quiet")
subtitle(ax, "RFM segments: share of customers vs. share of GMV")
ax.legend(loc="lower right", frameon=False)
ax.grid(axis="y", visible=False)
save(fig, "03_rfm_segments.png")

# 4. Region: delivery days & late rate --------------------------------------
reg_sql = Path("sql/analysis/09_freight_geography.sql").read_text()
reg_sql = reg_sql.split("SET search_path TO olist;", 1)[1]
df = q(reg_sql)
df["label"] = df["region"].str[3:]
df = df.iloc[::-1]
fig, ax = plt.subplots(figsize=(10, 4.6))
colors = [ORANGE if r in ("Northeast", "North") else BLUE for r in df["label"]]
bars = ax.barh(df["label"], df["avg_delivery_days"], color=colors, height=0.6)
for b, d, f, l in zip(bars, df["avg_delivery_days"], df["freight_pct_of_basket"], df["pct_late"]):
    ax.text(d + 0.3, b.get_y() + b.get_height() / 2,
            f"{d:.0f} days · freight {f:.0f}% of basket · {l:.0f}% late",
            va="center", color=INK, fontsize=10)
ax.set_xlim(0, df["avg_delivery_days"].max() * 1.75)
ax.set_title("Customers far from São Paulo wait 2.5x longer and pay more for shipping")
subtitle(ax, "Average delivery time by customer region")
ax.set_xlabel("Average delivery days")
ax.grid(axis="y", visible=False)
save(fig, "04_region_delivery.png")

# 5. Installments ------------------------------------------------------------
pay_sql = Path("sql/analysis/08_payments.sql").read_text()
pay_sql = pay_sql.split("-- 8b.", 1)[1].split("\n", 1)[1]
df = q(pay_sql)
df["label"] = df["installment_plan"].str[3:]
fig, ax = plt.subplots(figsize=(10, 4.6))
bars = ax.bar(df["label"], df["median_order_value"], color=BLUE, width=0.6)
for b, v, p in zip(bars, df["median_order_value"], df["pct_orders"]):
    ax.text(b.get_x() + b.get_width() / 2, v + 4, f"R$ {v:,.0f}",
            ha="center", color=INK, fontsize=11, fontweight="bold")
    ax.text(b.get_x() + b.get_width() / 2, 6, f"{p:.0f}% of orders",
            ha="center", color="white", fontsize=10)
ax.set_title("Customers paying in 7+ installments spend 3x more per order")
subtitle(ax, "Median order value by credit-card installment plan")
ax.yaxis.set_major_formatter(mtick.FuncFormatter(lambda v, _: f"R$ {v:,.0f}"))
ax.set_ylim(0, df["median_order_value"].max() * 1.15)
ax.grid(axis="x", visible=False)
save(fig, "05_installments.png")
