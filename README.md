# 📊 Vendor Performance Data Analytics

**End-to-end vendor performance analysis using SQL Server, Python, and Power BI** — identifying which vendors are actually profitable once purchase cost, freight, and inventory turnover are properly accounted for.

---

## 🧩 Business Problem

A retail/distribution business purchases from many vendors across multiple stores, but purchasing decisions (who to order more from, who to renegotiate freight with, who to drop) are currently made on relationship/gut feel rather than data.

This project builds a data-backed view of vendor performance to answer:
- What's our **actual gross profit and margin** from each vendor (based on real purchase cost, not list price)?
- How fast does each vendor's stock **turn over** — are we sitting on dead inventory?
- What is **freight** costing us as a % of what we buy from each vendor?
- Who are our **top and bottom vendors** by profitability?

## 🎯 Objective

Build a governed data pipeline and dashboard that lets stakeholders (Purchasing, Finance, Ops, Leadership) evaluate vendor performance on demand, and produce concrete recommendations backed by the numbers.

## 🛠️ Tech Stack

| Layer | Tool |
|---|---|
| Data storage & ETL | Microsoft SQL Server (T-SQL) |
| Analysis & validation | Python — Jupyter Notebook in VS Code (`.ipynb`) |
| Visualization | Power BI + DAX |

## 🗂️ Dataset

| File | Grain | Rows | Description |
|---|---|---|---|
| `begin_inventory.csv` | Store-Brand | ~206K | Opening stock, Jan 1 2024 |
| `end_inventory.csv` | Store-Brand | ~224K | Closing stock, Dec 31 2024 |
| `purchase_prices.csv` | Brand | ~12K | Retail price, purchase cost, vendor, classification |
| `purchases.csv` | PO line item | ~2.37M | Orders/receipts, actual cost, dates |
| `sales.csv` | Sale transaction | ~12.8M | Actual sales, revenue, excise tax |
| `vendor_invoice.csv` | Invoice | ~5.5K | Freight cost, approval, PO/pay dates |

*(Raw data not included in this repo due to size — see `/data` folder notes for source.)*

## 📈 Key Metrics (KPIs)

- **Gross Profit** = Sales Dollars − Purchase Dollars (actual cost)
- **Profit Margin %** = Gross Profit / Sales Dollars
- **Stock Turnover** = Sales Quantity / Average Inventory ((Begin + End)/2)
- **Sales-to-Purchase Ratio** = Sales Dollars / Purchase Dollars
- **Freight Cost %** = Freight / Purchase Dollars

## 🚧 Project Roadmap & Progress

- [x] **Phase 0** — Business problem, stakeholders, KPI definitions
- [x] **Phase 1** — Load all 6 source files into SQL Server, verify row counts/types/nulls, index join keys
- [x] **Phase 2** — Build `vw_VendorSummary` (SQL view): joins purchases, sales, freight, and inventory to Vendor × Brand grain; verified clean (no join-key mismatches; NULLs confirmed as genuine "no activity" cases, not data errors)
- [ ] **Phase 3** — Python (Jupyter/VS Code): pull `vw_VendorSummary` into pandas, clean, engineer KPI columns
- [ ] **Phase 4** — Python: EDA + hypothesis testing (e.g. margin difference between top vs. bottom vendors)
- [ ] **Phase 5** — Power BI dashboard with DAX measures
- [ ] **Phase 6** — Insights & recommendations write-up

## 📁 Repo Structure (so far)

```
├── README.md                        <- this file
├── docs/
│   ├── PROJECT_README.md            <- detailed business problem & scope doc
│   └── sql_server_import_guide.md   <- how the raw CSVs were loaded into SQL Server
├── sql/
│   ├── verify_sql_server_import.sql <- post-load verification checklist
│   ├── vendor_summary_view_fixed.sql<- the core vw_VendorSummary view (Phase 2)
│   ├── check_nulls_by_column.sql    <- null audit query
│   └── spot_check_null_purchase.sql <- join-mismatch vs. genuine-null verification
└── notebooks/                       <- Phase 3 onward (Python/Jupyter)
```

## 🔑 Core SQL Logic (Phase 2 highlight)

`vw_VendorSummary` aggregates each source table to Vendor × Brand (or Vendor-only for freight, since freight is invoiced per shipment, not itemized per brand), using CTEs:
- `PurchasesCTE` — total quantity/dollars purchased, avg purchase price
- `SalesCTE` — total quantity/dollars sold, excise tax
- `FreightCTE` — total freight per vendor
- `BeginInventoryCTE` / `EndInventoryCTE` — opening/closing stock value per brand

All joined via `LEFT JOIN` onto `purchase_prices` as the base table (12,261 rows — one per Brand), so every brand in the price list is preserved even where no purchase/sale/inventory activity exists.

## 🚀 Next Steps

Continuing in Phase 3: connecting Python (Jupyter Notebook in VS Code) to SQL Server, pulling `vw_VendorSummary`, and engineering the KPI columns above for deeper analysis.

---
*Work in progress — updated phase by phase.*
