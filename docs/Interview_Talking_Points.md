# Enterprise Financial Portfolio — Interview Talking Points
# Author  : Phil Kibet | Biostatistician & Financial Data Analyst
# ============================================================================

## HOW TO PRESENT THIS PORTFOLIO IN AN INTERVIEW

---

### OPENING STATEMENT (30 seconds)

"This portfolio is an enterprise-grade financial analytics platform I built
in Power BI, backed by a SQL star schema data warehouse. It covers twelve
analytical domains — from CFO-level P&L reporting all the way to credit risk
modelling, ESG scoring, and forensic fraud detection. Every metric is
formula-driven using DAX; no numbers are hardcoded. The data originates from
SEC EDGAR filings, NSE Kenya, LSE, NYSE, FRED, and the World Bank."

---

## DASHBOARD-BY-DASHBOARD TALKING POINTS

### Page 1 — CFO Financial Performance
"This is what a CFO sees every Monday morning. The top row shows Revenue,
Gross Profit, EBITDA, Net Income, and Total Assets as KPI cards — all
calculated using DAX CALCULATE with ALLSELECTED so they respond to every
slicer. The revenue trend line uses DATESINPERIOD for a rolling 12-month
view. The waterfall breaks down the P&L from Revenue to Net Income. I applied
SAMEPERIODLASTYEAR for YoY variance and TOTALYTD for the year-to-date view."

### Page 2 — Financial Statement Analysis
"This replicates a 10-year financial statement explorer similar to what
equity analysts use on Bloomberg. The DuPont decomposition — Net Margin ×
Asset Turnover × Equity Multiplier — is calculated through a multi-level CTE
in SQL and exposed as a DAX measure using DIVIDE with zero-division guards.
The star schema means I can slice every income statement metric simultaneously
by company, sector, region, and year."

### Page 3 — Equity Research Command Center
"This is designed to look like an institutional equity research terminal.
The MA20, MA50, and MA200 moving averages are calculated with DATESINPERIOD
inside CALCULATE. Rolling 30-day volatility is STDEV.P annualised by
multiplying by SQRT(252). The 52-week high and low use CALCULATE with
DATESINPERIOD on a 365-day window."

### Page 4 — Portfolio Analytics
"Portfolio risk metrics follow the CFA Institute methodology. Sharpe Ratio =
(Portfolio Return − Risk-Free Rate) / Standard Deviation. Alpha is Jensen's
Alpha. Beta is the weighted average of individual security betas. The Sortino
Ratio uses only downside deviation in the denominator, making it more
appropriate for non-normal return distributions."

### Page 5 — Credit Risk Analytics
"This implements the Basel III / IFRS 9 expected credit loss model:
EL = PD × EAD × LGD. The heatmap shows PD by sector and tenor band.
The colour-coded risk tier — Green, Amber, Red, Critical — mirrors what you
would see in a bank's credit risk committee pack. I also calculate the NPL
ratio as EAD of exposures with PD ≥ 20% as a percentage of total EAD."

### Page 6 — Forensic Accounting & Fraud Detection
"The Benford's Law analysis compares the first-digit distribution of
transaction amounts against the expected LOG(1 + 1/d) distribution. A
chi-square deviation above 3% triggers a flag. The fraud score is a composite
of five signals: Benford deviation, amount vs 3-sigma threshold, duplicate
vendor-amount-date patterns, round-number bias, and off-hours transaction
timing. This is how forensic accountants at Big Four firms automate the
initial risk scan."

### Page 7 — FP&A Analytics
"The FP&A dashboard replicates what a finance business partner presents to
department heads. Budget Attainment = Actual / Budget. Forecast Accuracy =
1 − |Forecast − Actual| / |Actual|. The variance waterfall decomposes the
total budget variance by department. The Full Year Forecast measure adds
actuals to date with forecasts for remaining months using DimDate[Month] >
MONTH(TODAY())."

### Page 8 — Treasury Command Center
"The LCR and NSFR are Basel III regulatory capital ratios. LCR must be
≥ 100% to ensure 30-day survival under a stress scenario. NSFR must be
≥ 100% to ensure stable funding over a 1-year horizon. The FX exposure chart
shows net long versus short positions by currency. This is the kind of daily
reporting a Group Treasurer at a commercial bank would receive."

### Page 9 — ESG Analytics
"The ESG composite score uses a weighted average: 40% Environmental, 35%
Social, 25% Governance — consistent with MSCI ESG methodology. Carbon
intensity is normalised per $M of revenue for cross-sector comparability.
The YoY carbon change measure uses SAMEPERIODLASTYEAR. The rating band from
AAA to B maps to MSCI's seven-tier scale."

### Page 10 — Macroeconomic Intelligence
"This aggregates country-level data from FRED, World Bank, and IMF. The
Real Policy Rate = Nominal Policy Rate − Inflation Rate. The VIX trend
provides a fear gauge for market risk. I used AVERAGEX on the country
dimension to calculate population-weighted averages. This dashboard feeds
the top-down economic assumptions used in credit risk stress testing."

### Page 11 — Balance Sheet Deep Dive
"The balance sheet dashboard tracks the DuPont identity components visually.
Working Capital = Current Assets − Current Liabilities. The Debt-to-Equity
ratio is calculated monthly and trended to show deleveraging progress. Cash
Conversion Cycle = DIO + DSO − DPO. All ratios adjust automatically when
the year or company slicer changes."

### Page 12 — Executive Boardroom Command Center
"This is the flagship page — the single-screen board summary. It uses ALL
twelve data domains simultaneously. A board member can see Revenue, EBITDA,
Portfolio Value, Credit Exposure, Cash Position, and ESG Score in one view.
Every visual cross-filters every other visual. Clicking a sector on the donut
chart instantly updates all other visuals to show only that sector."

---

## TECHNICAL DEEP-DIVE QUESTIONS & ANSWERS

**Q: Why did you choose a star schema over a flat table?**
A: "A star schema separates facts (measurements) from dimensions (context).
This produces faster query performance because the query engine can scan small
dimension tables to filter large fact tables without full joins. It also makes
DAX relationships deterministic — CALCULATE respects the filter propagation
direction automatically. A flat table would require ALLEXCEPT on every measure
to avoid double-counting when slicing by multiple dimensions."

**Q: Explain the difference between CALCULATE and CALCULATETABLE.**
A: "CALCULATE evaluates a scalar expression in a modified filter context —
it always returns a single value. CALCULATETABLE evaluates a table expression
in a modified filter context — it returns a table. CALCULATETABLE is used
inside functions that expect a table argument, such as SUMX, COUNTROWS, or
FILTER. For example, the NPL Ratio uses CALCULATE with a filter on PD >= 0.2
to get a single sum, while a drill-through page might use CALCULATETABLE to
generate the filtered list of breaching loans."

**Q: How did you implement the rolling 12-month revenue?**
A: "CALCULATE([Total Revenue], DATESINPERIOD(DimDate[Date], LASTDATE
(DimDate[Date]), -12, MONTH)). DATESINPERIOD creates a date table starting
from the last visible date and going back 12 months. CALCULATE then
evaluates Total Revenue in that modified filter context. The key subtlety is
that LASTDATE respects the current filter context, so the window always ends
at the latest date visible after slicer selections."

**Q: What is SCD Type 2 and why does it matter?**
A: "Slowly Changing Dimension Type 2 preserves history by inserting a new row
when an attribute changes, using effective_from and effective_to dates with an
is_current flag. This matters for DimCompany because if Apple changed its
GICS sector classification, all historical financial data must still map to the
sector that was correct at the time of each transaction. Type 1 (overwrite)
would corrupt all historical sector analysis."

**Q: How did you calculate Expected Loss?**
A: "EL = PD × EAD × LGD. In DAX: SUMX(FactCreditRisk, FactCreditRisk[pd]
* FactCreditRisk[ead] * FactCreditRisk[lgd]). SUMX iterates each row of
FactCreditRisk and multiplies the three risk parameters at the loan level
before summing. This is correct because averaging PD then multiplying by
average EAD would introduce aggregation bias when the correlation between
PD and EAD is non-zero."

**Q: Why use DIVIDE instead of the division operator?**
A: "The native / operator returns an error when the denominator is zero,
which crashes the visual. DIVIDE(numerator, denominator, alternate_result)
returns a specified alternate result — typically 0 or BLANK() — when the
denominator is zero or BLANK. This is critical in financial dashboards where
ratios like Current Ratio can have zero denominators during data loading
or for newly incorporated entities."

---

## LINKEDIN SHOWCASE TEMPLATE

Title: "Enterprise Financial Intelligence Suite — Power BI Portfolio"

Post text:
"Excited to share my latest Power BI portfolio project — 12 institutional-grade
financial dashboards covering every domain a senior finance professional
encounters:

📊 CFO Financial Performance — Rolling 12M revenue, DuPont ROE, margin waterfalls
📈 Equity Research — Price technicals, MA20/50/200, 30D volatility, 52W range
💼 Portfolio Analytics — Sharpe Ratio, Alpha, Beta, Sortino, Information Ratio
⚠️  Credit Risk — PD × EAD × LGD, Basel III EL, NPL ratio, risk tier heatmap
🔍 Forensic Accounting — Benford's Law, duplicate payment detection, fraud scoring
📋 FP&A — Budget vs Actual, forecast accuracy, variance waterfall
🏦 Treasury — LCR, NSFR, FX exposure, HQLA monitoring (Basel III)
🌿 ESG — Composite scoring (MSCI methodology), carbon intensity, governance
🌐 Macroeconomics — GDP, inflation, VIX, policy rates (FRED/World Bank/IMF)
👔 Executive Boardroom — All 12 domains unified on a single board-level page

Tech stack: Power BI · DAX · SQL · Star Schema · SCD Type 2
Data: SEC EDGAR · NSE Kenya · LSE · NYSE · FRED · World Bank · IMF

GitHub: github.com/Apollop24/EnterpriseFinancialPortfolio

#PowerBI #DAX #FinancialAnalytics #DataVisualization #BusinessIntelligence"
