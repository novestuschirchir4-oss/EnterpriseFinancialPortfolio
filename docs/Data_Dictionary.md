# Enterprise Financial Portfolio — Data Dictionary
# Author  : Phil Kibet | Biostatistician & Financial Data Analyst
# Source  : SEC EDGAR · NSE · LSE · NYSE · NASDAQ · FRED · World Bank · IMF
# Updated : June 2026
# ============================================================================

## DATA SOURCES

| Source               | URL                                        | Data Provided                              |
|----------------------|--------------------------------------------|--------------------------------------------|
| SEC EDGAR            | https://efts.sec.gov/LATEST/search-index   | 10-K, 10-Q annual & quarterly reports      |
| FRED (St. Louis Fed) | https://fred.stlouisfed.org                | GDP, inflation, interest rates, VIX        |
| World Bank           | https://data.worldbank.org/indicator       | GDP growth, unemployment, macro indicators |
| IMF Data             | https://www.imf.org/en/Data                | Country-level economic indicators          |
| NSE Kenya            | https://www.nse.co.ke/market-statistics    | Safaricom, Equity Group prices             |
| London Stock Exch.   | https://www.londonstockexchange.com        | Shell, UBS historical prices               |
| NYSE / NASDAQ        | https://finance.yahoo.com                  | Apple, Microsoft, JPMorgan OHLCV           |
| Central Bank Kenya   | https://www.centralbank.go.ke              | Kenya interest rates, FX                   |

---

## DIMENSION TABLES

### DimDate
Calendar and fiscal date spine — loaded once, never changes (SCD Type 0)

| Column        | Type      | Description                                 | Example        |
|---------------|-----------|---------------------------------------------|----------------|
| date_key      | INT       | Surrogate key (YYYYMMDD format)             | 20240115       |
| Date          | DATE      | Full calendar date                          | 2024-01-15     |
| Year          | INT       | Calendar year                               | 2024           |
| Quarter       | VARCHAR   | Calendar quarter label                      | Q1             |
| Month         | INT       | Month number (1–12)                         | 1              |
| MonthName     | VARCHAR   | Full month name                             | January        |
| MonthShort    | VARCHAR   | 3-letter month abbreviation                 | Jan            |
| FiscalYear    | INT       | Fiscal year (same as calendar year here)    | 2024           |
| FiscalQuarter | VARCHAR   | Fiscal quarter label                        | FQ1            |
| WeekNumber    | INT       | ISO week number                             | 3              |
| DayOfWeek     | VARCHAR   | Day name                                    | Monday         |
| IsWeekend     | BOOLEAN   | True if Saturday or Sunday                  | FALSE          |
| IsTradingDay  | BOOLEAN   | True if weekday (proxy for trading day)     | TRUE           |
| YearMonth     | VARCHAR   | Year-Month label for axis display           | 2024-Jan       |

---

### DimCompany
Company master dimension — SCD Type 2 (new row on attribute change)

| Column             | Type      | Description                                | Example            |
|--------------------|-----------|--------------------------------------------|--------------------|
| company_key        | BIGINT    | Surrogate primary key                      | 1                  |
| company_id         | VARCHAR   | Natural business key (ticker/code)         | AAPL               |
| company_name       | VARCHAR   | Full legal company name                    | Apple Inc.         |
| ticker             | VARCHAR   | Exchange ticker symbol                     | AAPL               |
| sector             | VARCHAR   | GICS sector classification                 | Technology         |
| industry           | VARCHAR   | GICS industry group                        | Technology Hardware|
| region             | VARCHAR   | Geographic region                          | Americas           |
| country            | VARCHAR   | Country of incorporation                   | USA                |
| exchange           | VARCHAR   | Primary listing exchange                   | NASDAQ             |
| sic_code           | CHAR(4)   | Standard Industry Classification code      | 3571               |
| is_current         | BOOLEAN   | TRUE = current active record (SCD Type 2)  | TRUE               |
| employee_count     | INT       | Number of full-time employees              | 147000             |
| shares_outstanding | NUMERIC   | Total shares outstanding                   | 15441943070        |
| effective_from     | DATE      | SCD effective start date                   | 2019-01-01         |
| effective_to       | DATE      | SCD effective end date (9999 = current)    | 9999-12-31         |

Companies included: AAPL, MSFT, GOOGL, JPM, XOM, JNJ, Safaricom (NSE),
Equity Group (NSE), UBS Group (LSE), Shell PLC (LSE)

---

### DimTicker
Equity ticker master with GICS classification

| Column         | Type    | Description                              | Example          |
|----------------|---------|------------------------------------------|------------------|
| ticker_key     | BIGINT  | Surrogate primary key                    | 1                |
| ticker         | VARCHAR | Exchange ticker symbol                   | AAPL             |
| company_name   | VARCHAR | Full company name                        | Apple Inc.       |
| gics_sector    | VARCHAR | GICS sector                              | Technology       |
| gics_industry  | VARCHAR | GICS industry group                      | Tech Hardware    |
| exchange       | VARCHAR | Primary listing exchange                 | NASDAQ           |
| currency       | CHAR(3) | Trading currency                         | USD              |
| market_cap_band| VARCHAR | Market cap size category                 | Mega Cap         |

---

### DimDepartment
Cost centre and department hierarchy for FP&A

| Column            | Type    | Description                        | Example        |
|-------------------|---------|------------------------------------|----------------|
| department_key    | BIGINT  | Surrogate primary key              | 1              |
| department_name   | VARCHAR | Department display name            | Sales          |
| cost_centre_code  | VARCHAR | GL cost centre code                | REV-001        |
| division          | VARCHAR | Business division                  | Commercial     |
| region            | VARCHAR | Geographic region                  | Americas       |
| manager           | VARCHAR | Department manager name            | James Smith    |

Departments: Sales, Marketing, Operations, R&D, Finance, HR, IT, Legal

---

### DimEconomicIndicators
Macro economic data — source: FRED, World Bank, IMF, Central Banks

| Column            | Type    | Description                              | Example    |
|-------------------|---------|------------------------------------------|------------|
| indicator_key     | BIGINT  | Surrogate primary key                    | 1          |
| date_key          | INT     | FK to DimDate                            | 20241231   |
| country           | VARCHAR | Country name                             | USA        |
| gdp_growth        | DECIMAL | Annual GDP growth rate (%)               | 3.10       |
| inflation_rate    | DECIMAL | Consumer price inflation rate (%)        | 3.40       |
| policy_rate       | DECIMAL | Central bank policy interest rate (%)    | 5.25       |
| unemployment_rate | DECIMAL | Unemployment rate (%)                    | 3.70       |
| usd_index         | DECIMAL | USD Index value (DXY)                    | 104.20     |
| vix               | DECIMAL | CBOE Volatility Index                    | 16.80      |

Countries: USA, UK, EU, Kenya, Switzerland

---

## FACT TABLES

### FactFinancials
Monthly income statement data — source: SEC EDGAR 10-K/10-Q, company IR sites
Row count: 720 rows (10 companies × 72 months, Jan 2019 – Dec 2024)
Grain: One row per company per calendar month

| Column           | Type    | Description                         | Format        |
|------------------|---------|-------------------------------------|---------------|
| company_key      | BIGINT  | FK to DimCompany                    | —             |
| date_key         | INT     | FK to DimDate                       | —             |
| fiscal_year      | INT     | Fiscal year of the record           | 2024          |
| revenue          | DECIMAL | Total revenue ($M)                  | $M            |
| cogs             | DECIMAL | Cost of goods sold ($M)             | $M            |
| gross_profit     | DECIMAL | Revenue minus COGS ($M)             | $M            |
| sga              | DECIMAL | Selling, General & Admin expense    | $M            |
| rd_expense       | DECIMAL | Research & Development expense      | $M            |
| ebitda           | DECIMAL | Earnings before I, T, D&A           | $M            |
| da               | DECIMAL | Depreciation & Amortisation         | $M            |
| ebit             | DECIMAL | Earnings before Interest & Tax      | $M            |
| interest_expense | DECIMAL | Net interest expense                | $M            |
| net_income       | DECIMAL | Bottom-line net income              | $M            |

---

### FactBalanceSheet
Monthly balance sheet snapshot — source: SEC EDGAR, company annual reports
Row count: 720 rows (10 companies × 72 months)
Grain: One row per company per calendar month

| Column               | Type    | Description                             | Format |
|----------------------|---------|-----------------------------------------|--------|
| company_key          | BIGINT  | FK to DimCompany                        | —      |
| date_key             | INT     | FK to DimDate                           | —      |
| current_assets       | DECIMAL | Total current assets ($M)               | $M     |
| current_liabilities  | DECIMAL | Total current liabilities ($M)          | $M     |
| total_assets         | DECIMAL | Total assets ($M)                       | $M     |
| total_debt           | DECIMAL | Total financial debt ($M)               | $M     |
| total_equity         | DECIMAL | Total shareholders' equity ($M)         | $M     |
| cash                 | DECIMAL | Cash and equivalents ($M)               | $M     |
| inventory            | DECIMAL | Inventory ($M)                          | $M     |
| receivables          | DECIMAL | Accounts receivable ($M)                | $M     |
| payables             | DECIMAL | Accounts payable ($M)                   | $M     |
| ppe_net              | DECIMAL | Net property, plant & equipment ($M)    | $M     |
| intangibles          | DECIMAL | Intangible assets including goodwill    | $M     |
| retained_earnings    | DECIMAL | Cumulative retained earnings ($M)       | $M     |

---

### FactMarketPrices
Daily OHLCV price data — source: NSE, LSE, NYSE, NASDAQ (Yahoo Finance API)
Row count: 5,220 rows (10 tickers × ~522 trading days, Jan 2023 – Dec 2024)
Grain: One row per ticker per trading day

| Column      | Type    | Description                              | Format     |
|-------------|---------|------------------------------------------|------------|
| ticker_key  | BIGINT  | FK to DimTicker                          | —          |
| date_key    | INT     | FK to DimDate                            | —          |
| open_price  | DECIMAL | Opening price                            | $          |
| high_price  | DECIMAL | Intraday high price                      | $          |
| low_price   | DECIMAL | Intraday low price                       | $          |
| close_price | DECIMAL | Closing price                            | $          |
| adj_close   | DECIMAL | Adjusted close (dividends/splits)        | $          |
| volume      | BIGINT  | Daily trading volume (shares)            | shares     |
| daily_return| DECIMAL | Log daily return                         | decimal    |
| market_cap  | DECIMAL | Market capitalisation ($B)               | $B         |

---

### FactPortfolio
Portfolio holdings, weights and risk attribution
Row count: 5,220 rows (10 tickers × ~522 trading days)
Grain: One row per ticker per trading day

| Column           | Type    | Description                              | Formula / Source          |
|------------------|---------|------------------------------------------|---------------------------|
| portfolio_key    | INT     | Portfolio identifier (1 = main)          | —                         |
| ticker_key       | BIGINT  | FK to DimTicker                          | —                         |
| date_key         | INT     | FK to DimDate                            | —                         |
| weight           | DECIMAL | Portfolio weight (0–1)                   | Analyst assigned          |
| daily_return     | DECIMAL | Security daily return                    | ln(P_t / P_t-1)           |
| benchmark_return | DECIMAL | S&P 500 benchmark return                 | Market data               |
| beta             | DECIMAL | Beta vs benchmark                        | Regression β              |
| std_dev          | DECIMAL | Rolling 30-day standard deviation        | STDEV of daily returns    |
| risk_free_rate   | DECIMAL | Daily risk-free rate (US T-Bill / 252)   | FRED 3-month T-Bill / 252 |
| market_value     | DECIMAL | Position market value ($M)               | Shares × price            |

---

### FactCreditRisk
Loan-level credit risk data — Basel III framework
Row count: 600 rows (200 borrowers × 3 year-end snapshots)
Grain: One row per borrower per year-end date

| Column          | Type    | Description                             | Basel III Ref       |
|-----------------|---------|-----------------------------------------|---------------------|
| borrower_key    | INT     | Borrower identifier                     | —                   |
| date_key        | INT     | FK to DimDate (year-end snapshot)       | —                   |
| rating          | VARCHAR | Internal credit rating (AAA to CCC)     | Internal model      |
| sector          | VARCHAR | Borrower industry sector                | —                   |
| tenor_band      | VARCHAR | Loan tenor bucket (<1yr, 1-3yr, etc.)   | —                   |
| ead             | DECIMAL | Exposure At Default ($M)                | BCBS 128            |
| pd              | DECIMAL | Probability of Default (0–1)            | IRB approach        |
| lgd             | DECIMAL | Loss Given Default (0–1)                | Collateral adjusted |
| collateral_value| DECIMAL | Collateral fair value ($M)              | Market value        |

Key metric: Expected Loss = PD × EAD × LGD

---

### FactFPA
Financial Planning & Analysis — budget, actuals, forecasts
Row count: 288 rows (8 departments × 36 months, Jan 2022 – Dec 2024)
Grain: One row per department per month

| Column         | Type    | Description                          | Example    |
|----------------|---------|--------------------------------------|------------|
| department_key | BIGINT  | FK to DimDepartment                  | —          |
| date_key       | INT     | FK to DimDate                        | —          |
| cost_centre    | VARCHAR | Cost centre name                     | Sales      |
| gl_account     | VARCHAR | General ledger account code          | REV-001    |
| budget         | DECIMAL | Approved budget amount ($M)          | 1,120.00   |
| actual         | DECIMAL | Actual spend/revenue ($M)            | 1,098.00   |
| forecast       | DECIMAL | Updated forecast amount ($M)         | 1,110.00   |

---

### FactTreasury
Daily cash positions, FX exposure, liquidity ratios
Row count: 27,370 rows (5 accounts × 7 currencies × ~782 business days)
Grain: One row per account per currency per business day

| Column                | Type    | Description                        | Basel III Ref |
|-----------------------|---------|------------------------------------|---------------|
| account_key           | INT     | Treasury account identifier        | —             |
| date_key              | INT     | FK to DimDate                      | —             |
| currency_code         | CHAR(3) | ISO currency code                  | USD, EUR …    |
| cash_balance          | DECIMAL | Closing cash balance ($M)          | —             |
| fx_long               | DECIMAL | FX long position ($M)              | —             |
| fx_short              | DECIMAL | FX short position ($M)             | —             |
| hqla                  | DECIMAL | High Quality Liquid Assets ($M)    | Basel III LCR |
| net_cash_outflows_30d | DECIMAL | Net stressed cash outflows 30d     | Basel III LCR |
| rsf                   | DECIMAL | Required Stable Funding ($M)       | Basel III NSFR|
| asf                   | DECIMAL | Available Stable Funding ($M)      | Basel III NSFR|

LCR = HQLA / Net Cash Outflows × 100 (must be ≥ 100%)
NSFR = ASF / RSF × 100 (must be ≥ 100%)
Currencies: USD, EUR, GBP, JPY, KES, AUD, CHF

---

### FactFraud
Transaction-level fraud flags and anomaly scores
Row count: 3,000 transactions (Jan 2023 – Dec 2024)
Grain: One row per transaction

| Column          | Type     | Description                              | Fraud Signal          |
|-----------------|----------|------------------------------------------|-----------------------|
| transaction_key | BIGINT   | Transaction identifier                   | —                     |
| date_key        | INT      | FK to DimDate                            | —                     |
| vendor_key      | INT      | Vendor identifier                        | —                     |
| amount          | DECIMAL  | Transaction amount ($)                   | —                     |
| first_digit     | SMALLINT | First digit of amount (Benford's Law)    | Benford deviation test|
| is_duplicate    | BOOLEAN  | Duplicate vendor+amount+date flag        | Duplicate payment     |
| is_weekend      | BOOLEAN  | Transaction on weekend flag              | Timing anomaly        |
| hour_of_day     | SMALLINT | Hour of transaction (0–23)               | Off-hours flag        |
| fraud_score     | DECIMAL  | Composite fraud risk score (0–10)        | >6 = flagged          |
| flag_reason     | VARCHAR  | Primary flag reason category             | Multi-factor          |

---

### FactESG
Environmental, Social, Governance scores — source: Company sustainability reports
Row count: 60 rows (10 companies × 6 annual periods, 2019–2024)
Grain: One row per company per year

| Column              | Type    | Description                              | Weight    |
|---------------------|---------|------------------------------------------|-----------|
| company_key         | BIGINT  | FK to DimCompany                         | —         |
| period_key          | INT     | Year-end period key (YYYYMM format)      | 202412    |
| e_score             | DECIMAL | Environmental score (0–100)              | 40%       |
| s_score             | DECIMAL | Social score (0–100)                     | 35%       |
| g_score             | DECIMAL | Governance score (0–100)                 | 25%       |
| carbon_intensity    | DECIMAL | Carbon intensity (tCO2 per $M revenue)   | —         |
| renewable_pct       | DECIMAL | Renewable energy % (0–1)                 | —         |
| board_diversity_pct | DECIMAL | Board gender diversity % (0–1)           | —         |
| water_usage         | DECIMAL | Water consumption (ML)                   | —         |
| employee_turnover   | DECIMAL | Annual employee turnover rate (0–1)      | —         |

ESG Composite Score = E × 0.40 + S × 0.35 + G × 0.25
Rating bands: AAA (≥80) | AA (≥70) | A (≥60) | BBB (≥50) | BB (≥40) | B (<40)

---

## RELATIONSHIPS (Star Schema)

| From Table             | From Column    | To Table           | To Column   | Cardinality |
|------------------------|----------------|--------------------|-------------|-------------|
| FactFinancials         | company_key    | DimCompany         | company_key | Many-to-One |
| FactFinancials         | date_key       | DimDate            | date_key    | Many-to-One |
| FactBalanceSheet       | company_key    | DimCompany         | company_key | Many-to-One |
| FactBalanceSheet       | date_key       | DimDate            | date_key    | Many-to-One |
| FactMarketPrices       | ticker_key     | DimTicker          | ticker_key  | Many-to-One |
| FactMarketPrices       | date_key       | DimDate            | date_key    | Many-to-One |
| FactPortfolio          | ticker_key     | DimTicker          | ticker_key  | Many-to-One |
| FactPortfolio          | date_key       | DimDate            | date_key    | Many-to-One |
| FactCreditRisk         | date_key       | DimDate            | date_key    | Many-to-One |
| FactFPA                | department_key | DimDepartment      | dept_key    | Many-to-One |
| FactFPA                | date_key       | DimDate            | date_key    | Many-to-One |
| FactTreasury           | date_key       | DimDate            | date_key    | Many-to-One |
| FactESG                | company_key    | DimCompany         | company_key | Many-to-One |
| FactFraud              | date_key       | DimDate            | date_key    | Many-to-One |
| DimEconomicIndicators  | date_key       | DimDate            | date_key    | Many-to-One |

Total: 15 active relationships | Schema type: Star Schema with conformed dimensions
