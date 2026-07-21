
Create database Vendor;
Use Vendor;

-- ============================================================
-- PHASE 2: VENDOR SUMMARY VIEW
-- Grain: one row per Vendor + Brand
-- Built step by step as separate CTEs, then joined at the end.
-- Run each CTE alone first (as a SELECT) to sanity check before
-- combining, if you want to verify along the way.
-- ============================================================

-- ------------------------------------------------------------
-- STEP 2.1 — Purchases aggregated to Vendor + Brand
-- What we ACTUALLY paid and received, not what we listed to sell
-- ------------------------------------------------------------
select 
	VendorNumber,Brand,
	SUM(Quantity) as TotalPurchaseQunatity,
	SUM(Dollars) as TotalPurchaseDollars,
	Avg(PurchasePrice) as AveragePurchasePrice
from dbo.purchases
group by VendorNumber,Brand

-- ------------------------------------------------------------
-- STEP 2.2 — Sales aggregated to Vendor + Brand
-- What actually sold, and for how much, plus excise tax
-- ------------------------------------------------------------

select 
	VendorNo,Brand,
	SUM(SalesQuantity) as TotalSalesQuantity,
	SUM(SalesDollars) as TotalSalesDollars,
	SUM(ExciseTax) as TotalExciseTax
From dbo.sales
group by VendorNo,Brand;

-- ------------------------------------------------------------
-- STEP 2.3 — Freight aggregated to Vendor (NOT brand — freight
-- is invoiced per shipment/vendor, not itemized per brand)
-- ------------------------------------------------------------

Select 
	VendorNumber,
	SUM(Freight) as TotalFreightcost
from dbo.vendor_invoice
group by VendorNumber;

-- ------------------------------------------------------------
-- STEP 2.4 — Begin & End inventory aggregated to Brand
-- (no vendor here — we'll attach vendor via purchase_prices later)
-- ------------------------------------------------------------

SELECT
    Brand,
    SUM(onHand) AS BegInventoryQty,
    SUM(onHand * Price) AS BegInventoryValue
FROM begin_inventory
GROUP BY Brand;

select 
	Brand,
	SUM(onHand) AS EndInventoryQty,
	SUM(onHand * Price) AS EndInventoryValue
from dbo.end_inventory
group by Brand;

-- Now the Full combined query to create the Vendor Summary view, joining all the above CTEs together.

IF OBJECT_ID('dbo.VendorSummary', 'V') IS NOT NULL
	DROP VIEW dbo.VendorSummary;

Create VIEW dbo.VendorSummary AS
With PurchasesCTE as (
	select 
		VendorNumber,Brand,
		SUM(Quantity) as TotalPurchaseQunatity,
		SUM(Dollars) as TotalPurchaseDollars,
		Avg(PurchasePrice) as AveragePurchasePrice
	from dbo.purchases
	group by VendorNumber,Brand
),
 
SalesCTE as (
	select 
		VendorNo,Brand,
		SUM(SalesQuantity) as TotalSalesQuantity,
		SUM(SalesDollars) as TotalSalesDollars,
		SUM(ExciseTax) as TotalExciseTax
	from dbo.sales
	group by VendorNo,Brand
),
 
FreightCTE as (
	select 
		VendorNumber,
		SUM(Freight) as TotalFreightcost
	from dbo.vendor_invoice
	group by VendorNumber
),
 
BeginInventoryCTE as (
	SELECT
		Brand,
		SUM(onHand) AS BegInventoryQty,
		SUM(onHand * Price) AS BegInventoryValue
	FROM dbo.begin_inventory
	GROUP BY Brand
),
 
EndInventoryCTE as (
	select 
		Brand,
		SUM(onHand) AS EndInventoryQty,
		SUM(onHand * Price) AS EndInventoryValue
	from dbo.end_inventory
	group by Brand
)
 
SELECT
    pp.Brand,
    pp.Description,
    pp.VendorNumber,
    pp.VendorName,
    pp.Price               AS RetailPrice,
    pp.PurchasePrice       AS ListedPurchasePrice,
    pp.Classification,
 
    pc.TotalPurchaseQunatity,
    pc.TotalPurchaseDollars,
    pc.AveragePurchasePrice,
 
    sc.TotalSalesQuantity,
    sc.TotalSalesDollars,
    sc.TotalExciseTax,
 
    fc.TotalFreightcost,
 
    bi.BegInventoryQty,
    bi.BegInventoryValue,
    ei.EndInventoryQty,
    ei.EndInventoryValue
 
FROM purchase_prices pp
LEFT JOIN PurchasesCTE pc  ON pp.Brand = pc.Brand AND pp.VendorNumber = pc.VendorNumber
LEFT JOIN SalesCTE sc      ON pp.Brand = sc.Brand AND pp.VendorNumber = sc.VendorNo
LEFT JOIN FreightCTE fc    ON pp.VendorNumber = fc.VendorNumber
LEFT JOIN BeginInventoryCTE bi   ON pp.Brand = bi.Brand
LEFT JOIN EndInventoryCTE ei     ON pp.Brand = ei.Brand;

-- ============================================================
-- VERIFY THE VIEW
-- ============================================================

Select Top 20 * from dbo.VendorSummary;

Select count(*) as TotalRows from dbo.VendorSummary;

-- Check for rows where purchases/sales didn't match at all
-- (these brands may have been purchased but never sold, or vice versa)

Select count(*) as BrandswithNoPurchasesMatch from dbo.VendorSummary where TotalPurchaseDollars is null;

Select count(*) as BrandswithNoSalesMatch from dbo.VendorSummary where TotalPurchaseDollars is null;

-- Count null for each column to see where we have missing data, and how much of it.

SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN TotalPurchaseQunatity IS NULL THEN 1 ELSE 0 END) AS null_purchase_qty,
    SUM(CASE WHEN TotalPurchaseDollars  IS NULL THEN 1 ELSE 0 END) AS null_purchase_dollars,
    SUM(CASE WHEN TotalSalesQuantity    IS NULL THEN 1 ELSE 0 END) AS null_sales_qty,
    SUM(CASE WHEN TotalSalesDollars     IS NULL THEN 1 ELSE 0 END) AS null_sales_dollars,
    SUM(CASE WHEN TotalFreightcost      IS NULL THEN 1 ELSE 0 END) AS null_freight,
    SUM(CASE WHEN BegInventoryQty       IS NULL THEN 1 ELSE 0 END) AS null_beg_inventory,
    SUM(CASE WHEN EndInventoryQty       IS NULL THEN 1 ELSE 0 END) AS null_end_inventory
FROM dbo.VendorSummary;

-- Pick a few brands that show NULL purchase in the view
SELECT TOP 10 Brand, VendorNumber, VendorName
FROM dbo.VendorSummary
WHERE TotalPurchaseQunatity IS NULL;

-- For those same Brands, check if they DO exist in purchases table
-- under a DIFFERENT VendorNumber (this would indicate a real mismatch,
-- e.g. the brand changed vendor mid-year, or VendorNumber data type/
-- spacing differs between tables)
SELECT p.Brand, p.VendorNumber AS purchases_vendor, pp.VendorNumber AS pricelist_vendor
FROM dbo.purchases p
JOIN dbo.purchase_prices pp ON p.Brand = pp.Brand
WHERE p.Brand IN (
    SELECT TOP 10 Brand FROM dbo.VendorSummary WHERE TotalPurchaseQunatity IS NULL
)
AND p.VendorNumber <> pp.VendorNumber;