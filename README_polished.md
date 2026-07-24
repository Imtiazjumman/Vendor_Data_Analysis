# 📊 Vendor Performance Analytics

**An end-to-end data analytics project identifying which vendors are actually profitable — built with SQL Server, Python, and Power BI.**

---

## 📖 Table of Contents
- [Business Problem](#-business-problem)
- [Objective](#-objective)
- [Stakeholders](#-stakeholders)
- [Tech Stack](#️-tech-stack)
- [Dataset](#-dataset)
- [Methodology](#-methodology)
- [Key Findings](#-key-findings)
- [Repo Structure](#-repo-structure)
- [Project Roadmap](#-project-roadmap)

---

## 🧩 Business Problem

A retail/distribution business purchases alcohol/beverage inventory from dozens of vendors and sells across multiple stores. Purchasing decisions — who to order more from, who to renegotiate freight terms with, who to drop — were being made on relationship and gut feel rather than data.

This project builds a data-backed view of vendor performance to answer:
- What is our **actual gross profit and margin** from each vendor, based on real purchase cost (not list price)?
- How fast does each vendor's stock **turn over** — are we sitting on dead inventory?
- What is **freight** costing us as a share of what we buy from each vendor?
- Does **vendor size** (sales volume) actually predict profitability, or is that an assumption worth challenging?
- Which specific vendors are **losing us money**, and is it a pattern or isolated cases?

## 🎯 Objective

Build a governed data pipeline and analysis that lets stakeholders evaluate vendor performance on demand — grounded in verified data, statistically validated findings, and a dashboard for ongoing monitoring — culminating in concrete, defensible recommendations.

## 👥 Stakeholders

| Role | What they need |
|---|---|
| Purchasing Manager | Vendor-by-vendor profit & freight ranking, to guide renegotiation |
| Finance | Accurate margin numbers based on actual purchase cost, not list price |
| Inventory/Ops | Stock turnover & dead-stock visibility, to reduce holding cost |
| Leadership | Executive summary of top/bottom vendors and the dollar impact of recommendations |

## 🛠️ Tech Stack

| Layer | Tool | Role in this project |
|---|---|---|
| Data storage & ETL | **Microsoft SQL Server** (T-SQL) | Load, index, and join large source tables; single source of truth |
| Analysis & validation | **Python** (Jupyter Notebook in VS Code) | Clean data, engineer KPIs, run statistical tests, EDA |
| Visualization | **Power BI + DAX** | Interactive stakeholder dashboard *(upcoming — Phase 5)* |

**Why SQL for the heavy joins instead of just DAX?** With 12.8M+ sales rows and 2.3M+ purchase rows, doing the joins/aggregation in Power BI/DAX at report-load time would mean pulling raw row-level data into memory — slow refreshes, bloated file size. SQL Server's indexed, disk-based engine does that work once, upstream, and hands Power BI a small, pre-aggregated table. DAX is reserved for what it's actually best at: interactive, filter-reactive report-time calculations.

## 🗂️ Dataset

| File | Grain | Rows | Description |
|---|---|---|---|
| `begin_inventory.csv` | Store-Brand | ~206K | Opening stock & value, Jan 1 2024 |
| `end_inventory.csv` | Store-Brand | ~224K | Closing stock & value, Dec 31 2024 |
| `purchase_prices.csv` | Brand | ~12K | Retail price, purchase cost, vendor, classification |
| `purchases.csv` | PO line item | ~2.37M | Orders/receipts, actual cost paid, dates |
| `sales.csv` | Sale transaction | ~12.8M | Actual sales, revenue, excise tax |
| `vendor_invoice.csv` | Invoice | ~5.5K | Freight cost, approval, PO/pay dates by vendor |

*Raw data not included in this repo (size/scale) — loaded directly into SQL Server per the process documented in `docs/sql_server_import_guide.md`.*

## 🔬 Methodology

### Phase 1 — Data Loading (SQL Server)
All 6 source files loaded into SQL Server via `BULK INSERT` with explicit, join-friendly data types (`INT` for `Brand`/`VendorNumber` consistently across every table — critical for reliable joins). Verified row counts against source files, checked for NULLs on key columns, and indexed all join keys (`Brand`, `VendorNumber`, `Store`).

### Phase 2 — Vendor Summary View (SQL Server)
Built `vw_VendorSummary`: a single view joining all 6 tables to **Vendor × Brand** grain, using CTEs for each source aggregation (purchases, sales, freight, beginning/ending inventory), joined via `purchase_prices` as the base table so every brand in the price list is preserved even with no matching activity.

**Verification caught a real edge case:** ~13% of rows showed NULL purchase activity. Spot-checked whether this was a join-key mismatch (e.g. vendor reassignment) vs. genuine "never purchased" — confirmed it was genuine, not a data bug, before proceeding.

### Phase 3 — Data Cleaning & KPI Engineering (Python)
Connected Jupyter (VS Code) to SQL Server via SQLAlchemy/pyodbc, pulled `vw_VendorSummary` (12,261 rows verified), and:
- Trimmed whitespace on text fields, filled NULLs in activity columns with `0` (absence = zero activity, not missing data)
- Engineered KPIs: **Gross Profit**, **Profit Margin %**, **Stock Turnover**, **Sales-to-Purchase Ratio**, **Freight Cost %**

**Caught and fixed a grain-mismatch bug:** initial Freight Cost % divided vendor-level total freight by brand-level purchase dollars, producing nonsensical values (up to 17,000,000%). Recomputed freight % correctly at vendor grain.

**Added materiality flags** (`LowSalesVolumeFlag`, `LowInventoryBaseFlag`) rather than dropping outlier rows — near-zero denominators (e.g. a brand with 0.5 units average inventory) blow up ratio metrics without representing real signal, but the underlying rows still matter for aggregate/total reporting.

Final cleaned + enriched table saved back to SQL Server as `VendorSummaryFinal`, plus a local CSV backup.

### Phase 4 — EDA & Hypothesis Testing (Python)
- **Distribution check:** brand-level profit margins cluster in a healthy 0–100% range (median ≈ 32%), with a long negative tail from low-activity brands.
- **Caught a Simpson's Paradox-style bug:** naive vendor ranking (averaging brand-level %s) showed some top-10-by-profit vendors with *negative* average margin. Fixed by switching to **dollar-weighted margin** (ΣProfit / ΣSales) instead of averaging percentages — corrected rankings are now consistent and sensible.
- **Hypothesis test:** "Do higher-sales-volume vendors have better profit margins?" Tested at the correct unit of analysis (vendor-level, n=67 vs n=61 — not brand-level, which would pseudo-replicate correlated brands under the same vendor). Ran both Welch's t-test (p=0.093) and Mann-Whitney U (p=0.101, outlier-robust) — **no statistically significant relationship found.**
- **Freight vs. margin:** freight cost % varies narrowly across vendors (~0.46%–0.64%) and shows no meaningful correlation with margin.

## 💡 Key Findings

1. **Vendor size does not predict profitability.** Larger vendors are not inherently better margin partners — purchasing decisions should be driven by each vendor's actual performance, not assumed scale advantages.
2. **7 vendors show severe, isolated negative margins** (as low as -1,478%), unexplained by market segment or volume — these are individual cases warranting direct pricing renegotiation or relationship review: Truett Hurst, Highland Wine Merchants LLC, Ira Goldman and Williams LLP, Vineyard Brands LLC, Uncorked, Loyal Dog Winery, Black Cove Beverages.
3. **Freight cost is not a meaningful margin driver** in this dataset — it varies too little across vendors to explain performance differences.
4. Naive percentage-averaging **understates top-performing vendors** — Martignetti Companies, for example, looked unprofitable under simple averaging but is a genuinely strong (32% dollar-weighted margin) top-10 vendor once measured correctly.

## 📁 Repo Structure

```
├── README.md                          <- this file
├── docs/
│   ├── PROJECT_README.md              <- detailed business problem & scope doc
│   ├── sql_server_import_guide.md     <- how raw CSVs were loaded into SQL Server
│   └── phase4_findings_summary.md     <- full EDA & hypothesis testing write-up
├── sql/
│   ├── verify_sql_server_import.sql   <- post-load verification checklist
│   ├── vendor_summary_view_fixed.sql  <- vw_VendorSummary (Phase 2 core view)
│   ├── check_nulls_by_column.sql      <- null audit query
│   └── spot_check_null_purchase.sql   <- join-mismatch vs. genuine-null verification
└── Vendor_Data_Analysis.ipynb         <- Phase 3 & 4: cleaning, KPI engineering, EDA, hypothesis testing
```

## 🚧 Project Roadmap

- [x] **Phase 0** — Business problem, stakeholders, KPI definitions
- [x] **Phase 1** — Loaded all 6 source files into SQL Server; verified row counts, types, nulls; indexed join keys
- [x] **Phase 2** — Built `vw_VendorSummary`; verified clean (no join-key mismatches, NULLs confirmed genuine)
- [x] **Phase 3** — Connected Python to SQL Server; cleaned data; engineered KPIs; fixed freight-grain bug; added materiality flags; saved `VendorSummaryFinal`
- [x] **Phase 4** — EDA + hypothesis testing; fixed margin-averaging bug; tested vendor-size-vs-margin hypothesis (not significant); flagged 7 problem vendors; freight/margin correlation checked
- [x] **Phase 5** — Power BI dashboard with DAX measures
- [x] **Phase 6** — Final insights & recommendations write-up

---
*Work in progress — updated phase by phase.*
