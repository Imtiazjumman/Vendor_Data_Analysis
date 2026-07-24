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
- [Dashboard](#-dashboard)
- [Key Findings](#-key-findings)
- [Recommendations](#-recommendations)
- [Repo Structure](#-repo-structure)
- [Project Roadmap](#-project-roadmap)
- [Limitations & Next Steps](#-limitations--next-steps)

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

Build a governed data pipeline and analysis that lets stakeholders evaluate vendor performance on demand — grounded in verified data, statistically validated findings, and a live dashboard for ongoing monitoring — culminating in concrete, defensible recommendations.

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
| Visualization | **Power BI + DAX** | Interactive single-page stakeholder dashboard |

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
All 6 source files loaded into SQL Server via `BULK INSERT` with explicit, join-friendly data types (`INT` for `Brand`/`VendorNumber` consistently across every table). Verified row counts against source files, checked NULLs on key columns, and indexed all join keys.

### Phase 2 — Vendor Summary View (SQL Server)
Built `vw_VendorSummary`: joins all 6 tables to **Vendor × Brand** grain via CTEs (purchases, sales, freight, beginning/ending inventory), based off `purchase_prices` so every brand is preserved even with no matching activity. Verified ~13% NULL purchase-activity rows were genuine "never purchased" cases, not join-key mismatches, via a targeted spot-check before proceeding.

### Phase 3 — Data Cleaning & KPI Engineering (Python)
Connected Jupyter (VS Code) to SQL Server via SQLAlchemy/pyodbc, pulled `vw_VendorSummary` (12,261 rows verified), cleaned nulls/whitespace, and engineered: **Gross Profit, Profit Margin %, Stock Turnover, Sales-to-Purchase Ratio, Freight Cost %**.

**Caught and fixed a grain-mismatch bug:** initial Freight Cost % divided vendor-level total freight by brand-level purchase dollars, producing values as high as 17,000,000%. Recomputed correctly at vendor grain. Added materiality flags (`LowSalesVolumeFlag`, `LowInventoryBaseFlag`) instead of dropping outlier rows, to protect ratio-based rankings without losing aggregate-level data. Final table saved to SQL Server as `VendorSummaryFinal`.

### Phase 4 — EDA & Hypothesis Testing (Python)
- Brand-level margins cluster in a healthy 0–100% range (median ≈ 32%).
- **Caught a Simpson's Paradox-style bug:** naive averaging of brand-level margin percentages made some genuinely strong top-10 vendors (e.g. Martignetti Companies) look unprofitable. Fixed by switching to **dollar-weighted margin** (ΣProfit/ΣSales).
- **Hypothesis test** ("do higher-volume vendors have better margins?"), run at the correct unit of analysis (vendor-level, n=67 vs n=61, not brand-level): Welch's t-test (p=0.093) and Mann-Whitney U (p=0.101) — **no statistically significant relationship.**
- Freight cost % shows no meaningful correlation with margin across most vendors.

### Phase 5 — Power BI Dashboard
Built a single-page interactive dashboard (see [Dashboard](#-dashboard) below) combining KPI cards, ranking charts, a sales-vs-margin scatter plot, an efficiency combo chart, composition visuals, and a fully-flagged vendor detail table — with `VendorName` and `Classification` slicers for interactive filtering.

### Phase 6 — Final Insights & Recommendations
Consolidated all findings into a business-facing report (`docs/phase6_final_insights_and_recommendations.md`) with prioritized, owner-assigned recommendations.

## 📈 Dashboard

Single-page Power BI dashboard including:
- **KPI cards:** Total Sales, Total Purchase, Total Gross Profit, Overall Margin %, Total Freight Cost, Vendor Count, Brand Count
- **Top 10 / Bottom 10 vendors** by Gross Profit (clustered bar charts)
- **Sales vs. Margin scatter plot** — visualizes vendor positioning at a glance
- **Stock Turnover vs. Freight Cost % combo chart** — efficiency view
- **Classification mix** (donut) and **Sales-by-vendor** (treemap) — composition views
- **Full vendor ranking table** with color-scaled margin and a conditional-formatted "Flagged Vendor" column highlighting the 7 vendors requiring review
- **Slicers** for `VendorName` and `Classification` to filter the whole page interactively

## 💡 Key Findings

1. **Vendor size does not predict profitability.** Two independent statistical tests (t-test p=0.093, Mann-Whitney U p=0.101) found no significant margin difference between high- and low-volume vendors — purchasing decisions should be driven by actual vendor performance, not assumed scale advantages.
2. **Top 5 vendors by profit** — Diageo North America, Martignetti Companies, Constellation Brands, Pernod Ricard USA, and Jim Beam Brands — generate ~$55.7M combined, roughly 43% of total gross profit.
3. **7 vendors show severe, isolated negative margins** (as low as -1,478%), unexplained by market segment or volume: Truett Hurst, Highland Wine Merchants LLC, Ira Goldman and Williams LLP, Vineyard Brands LLC, Uncorked, Loyal Dog Winery, Black Cove Beverages.
4. **Freight cost is not a meaningful margin driver** for most vendors (narrow 0.46%–0.64% range), except two outliers — Vineyard Brands LLC (55.43%) and Southern Glazers W&S of NE (46.60%) — flagged for direct investigation.
5. Naive percentage-averaging **understates genuinely strong vendors** — always weight vendor margin by dollars (ΣProfit/ΣSales), not by averaging brand-level percentages.

## ✅ Recommendations

| Priority | Action | Owner |
|---|---|---|
| High | Individually review pricing/terms with the 7 flagged loss-making vendors | Purchasing |
| High | Investigate freight anomaly at Vineyard Brands LLC and Southern Glazers W&S of NE | Purchasing / Logistics |
| Medium | Maintain and prioritize relationships with top-5 profit vendors | Purchasing / Leadership |
| Medium | Stop using vendor size/volume as a proxy for expected margin in negotiations | Purchasing / Leadership |
| Ongoing | Use the Power BI dashboard for continuous vendor monitoring | Finance / Ops |

Full detail in `docs/phase6_final_insights_and_recommendations.md`.

## 📁 Repo Structure

```
├── README.md                                      <- this file
├── docs/
│   ├── PROJECT_README.md                          <- detailed business problem & scope doc
│   ├── sql_server_import_guide.md                 <- how raw CSVs were loaded into SQL Server
│   ├── phase4_findings_summary.md                 <- full EDA & hypothesis testing write-up
│   └── phase6_final_insights_and_recommendations.md <- final business report
├── sql/
│   ├── verify_sql_server_import.sql               <- post-load verification checklist
│   ├── vendor_summary_view_fixed.sql              <- vw_VendorSummary (Phase 2 core view)
│   ├── check_nulls_by_column.sql                  <- null audit query
│   └── spot_check_null_purchase.sql               <- join-mismatch vs. genuine-null verification
├── powerbi/
│   └── Vendor_Data_Analysis_dashboard.pbix        <- Power BI dashboard (Phase 5)
└── Vendor_Data_Analysis.ipynb                     <- Phase 3 & 4: cleaning, KPI engineering, EDA, hypothesis testing
```

## 🚧 Project Roadmap

- [x] **Phase 0** — Business problem, stakeholders, KPI definitions
- [x] **Phase 1** — Loaded all 6 source files into SQL Server; verified row counts, types, nulls; indexed join keys
- [x] **Phase 2** — Built `vw_VendorSummary`; verified clean (no join-key mismatches, NULLs confirmed genuine)
- [x] **Phase 3** — Connected Python to SQL Server; cleaned data; engineered KPIs; fixed freight-grain bug; added materiality flags; saved `VendorSummaryFinal`
- [x] **Phase 4** — EDA + hypothesis testing; fixed margin-averaging bug; tested vendor-size-vs-margin hypothesis (not significant); flagged 7 problem vendors; freight/margin correlation checked
- [x] **Phase 5** — Power BI dashboard built: single-page layout with KPI cards, ranking charts, scatter, combo chart, composition visuals, slicers, and flagged-vendor detail table
- [x] **Phase 6** — Final insights & recommendations written up and consolidated into a business-facing report

**Project complete — Phase 0 through Phase 6.**

## ⚠️ Limitations & Next Steps

- This analysis covers a single calendar year (2024); multi-year trend data would clarify whether flagged vendors' losses are one-time or recurring.
- Freight is invoiced at the vendor level, not itemized per brand/shipment — more granular freight allocation could sharpen per-brand profitability further.
- This project establishes that vendor *size* doesn't predict margin — a natural next question is what *does* (product category, region, contract terms), which would need additional data not currently captured here.

---
*A complete end-to-end analytics project — from business problem to statistically validated, dashboard-backed recommendations.*
