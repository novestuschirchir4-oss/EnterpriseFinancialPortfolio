-- ============================================================================
-- ENTERPRISE FINANCIAL DATA WAREHOUSE
-- Star Schema DDL — PostgreSQL / SQL Server / Snowflake compatible
-- Author  : Phil Kibet | Biostatistician & Financial Data Analyst
-- Project : Enterprise Financial Intelligence Suite
-- Source  : SEC EDGAR · NSE · LSE · NYSE · NASDAQ · FRED · World Bank · IMF
-- ============================================================================

-- ── DIMENSION TABLES ────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS DimDate (
    date_key        INT             PRIMARY KEY,
    Date            DATE            NOT NULL,
    Year            INT             NOT NULL,
    Quarter         VARCHAR(2)      NOT NULL,
    Month           INT             NOT NULL,
    MonthName       VARCHAR(20)     NOT NULL,
    MonthShort      VARCHAR(3)      NOT NULL,
    FiscalYear      INT             NOT NULL,
    FiscalQuarter   VARCHAR(3)      NOT NULL,
    WeekNumber      INT             NOT NULL,
    DayOfWeek       VARCHAR(15)     NOT NULL,
    IsWeekend       BOOLEAN         NOT NULL DEFAULT FALSE,
    IsTradingDay    BOOLEAN         NOT NULL DEFAULT TRUE,
    YearMonth       VARCHAR(10)     NOT NULL
);

CREATE INDEX idx_dimdate_year       ON DimDate(Year);
CREATE INDEX idx_dimdate_fiscalyear ON DimDate(FiscalYear);
CREATE INDEX idx_dimdate_quarter    ON DimDate(Quarter);

-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS DimCompany (
    company_key         BIGSERIAL       PRIMARY KEY,
    company_id          VARCHAR(20)     NOT NULL,
    company_name        VARCHAR(200)    NOT NULL,
    ticker              VARCHAR(20),
    sector              VARCHAR(100),
    industry            VARCHAR(100),
    region              VARCHAR(100),
    country             VARCHAR(100),
    exchange            VARCHAR(50),
    sic_code            CHAR(4),
    is_current          BOOLEAN         NOT NULL DEFAULT TRUE,
    employee_count      INT,
    shares_outstanding  NUMERIC(20,0),
    effective_from      DATE            NOT NULL DEFAULT CURRENT_DATE,
    effective_to        DATE            NOT NULL DEFAULT '9999-12-31',
    -- SCD Type 2 tracking
    CONSTRAINT uq_company_current UNIQUE (company_id, is_current, effective_from)
);

CREATE INDEX idx_dimco_sector   ON DimCompany(sector);
CREATE INDEX idx_dimco_region   ON DimCompany(region);
CREATE INDEX idx_dimco_current  ON DimCompany(is_current);

-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS DimTicker (
    ticker_key      BIGSERIAL       PRIMARY KEY,
    ticker          VARCHAR(20)     NOT NULL,
    company_name    VARCHAR(200)    NOT NULL,
    gics_sector     VARCHAR(100),
    gics_industry   VARCHAR(100),
    exchange        VARCHAR(50),
    currency        CHAR(3),
    market_cap_band VARCHAR(30)
);

CREATE INDEX idx_dimticker_sector   ON DimTicker(gics_sector);
CREATE INDEX idx_dimticker_exchange ON DimTicker(exchange);

-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS DimDepartment (
    department_key      BIGSERIAL       PRIMARY KEY,
    department_name     VARCHAR(100)    NOT NULL,
    cost_centre_code    VARCHAR(20)     NOT NULL,
    division            VARCHAR(100),
    region              VARCHAR(100),
    manager             VARCHAR(200)
);

-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS DimEconomicIndicators (
    indicator_key       BIGSERIAL       PRIMARY KEY,
    date_key            INT             NOT NULL REFERENCES DimDate(date_key),
    country             VARCHAR(100)    NOT NULL,
    gdp_growth          NUMERIC(8,4),
    inflation_rate      NUMERIC(8,4),
    policy_rate         NUMERIC(8,4),
    unemployment_rate   NUMERIC(8,4),
    usd_index           NUMERIC(10,4),
    vix                 NUMERIC(8,4)
);

CREATE INDEX idx_macro_country  ON DimEconomicIndicators(country);
CREATE INDEX idx_macro_date     ON DimEconomicIndicators(date_key);

-- ── FACT TABLES ─────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS FactFinancials (
    financial_key       BIGSERIAL       PRIMARY KEY,
    company_key         BIGINT          NOT NULL REFERENCES DimCompany(company_key),
    date_key            INT             NOT NULL REFERENCES DimDate(date_key),
    fiscal_year         INT             NOT NULL,
    revenue             NUMERIC(18,2)   NOT NULL DEFAULT 0,
    cogs                NUMERIC(18,2)   NOT NULL DEFAULT 0,
    gross_profit        NUMERIC(18,2)   GENERATED ALWAYS AS (revenue - cogs) STORED,
    sga                 NUMERIC(18,2)   NOT NULL DEFAULT 0,
    rd_expense          NUMERIC(18,2)   NOT NULL DEFAULT 0,
    ebitda              NUMERIC(18,2)   NOT NULL DEFAULT 0,
    da                  NUMERIC(18,2)   NOT NULL DEFAULT 0,
    ebit                NUMERIC(18,2)   NOT NULL DEFAULT 0,
    interest_expense    NUMERIC(18,2)   NOT NULL DEFAULT 0,
    net_income          NUMERIC(18,2)   NOT NULL DEFAULT 0
)
PARTITION BY RANGE (fiscal_year);

CREATE TABLE FactFinancials_2019 PARTITION OF FactFinancials FOR VALUES FROM (2019) TO (2020);
CREATE TABLE FactFinancials_2020 PARTITION OF FactFinancials FOR VALUES FROM (2020) TO (2021);
CREATE TABLE FactFinancials_2021 PARTITION OF FactFinancials FOR VALUES FROM (2021) TO (2022);
CREATE TABLE FactFinancials_2022 PARTITION OF FactFinancials FOR VALUES FROM (2022) TO (2023);
CREATE TABLE FactFinancials_2023 PARTITION OF FactFinancials FOR VALUES FROM (2023) TO (2024);
CREATE TABLE FactFinancials_2024 PARTITION OF FactFinancials FOR VALUES FROM (2024) TO (2025);

CREATE INDEX idx_ff_company ON FactFinancials(company_key);
CREATE INDEX idx_ff_date    ON FactFinancials(date_key);
CREATE INDEX idx_ff_year    ON FactFinancials(fiscal_year);

-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS FactBalanceSheet (
    bs_key              BIGSERIAL       PRIMARY KEY,
    company_key         BIGINT          NOT NULL REFERENCES DimCompany(company_key),
    date_key            INT             NOT NULL REFERENCES DimDate(date_key),
    current_assets      NUMERIC(18,2),
    current_liabilities NUMERIC(18,2),
    total_assets        NUMERIC(18,2),
    total_debt          NUMERIC(18,2),
    total_equity        NUMERIC(18,2),
    cash                NUMERIC(18,2),
    inventory           NUMERIC(18,2),
    receivables         NUMERIC(18,2),
    payables            NUMERIC(18,2),
    ppe_net             NUMERIC(18,2),
    intangibles         NUMERIC(18,2),
    retained_earnings   NUMERIC(18,2)
);

CREATE INDEX idx_fb_company ON FactBalanceSheet(company_key);
CREATE INDEX idx_fb_date    ON FactBalanceSheet(date_key);

-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS FactMarketPrices (
    price_key       BIGSERIAL       PRIMARY KEY,
    ticker_key      BIGINT          NOT NULL REFERENCES DimTicker(ticker_key),
    date_key        INT             NOT NULL REFERENCES DimDate(date_key),
    open_price      NUMERIC(14,4),
    high_price      NUMERIC(14,4),
    low_price       NUMERIC(14,4),
    close_price     NUMERIC(14,4),
    adj_close       NUMERIC(14,4),
    volume          BIGINT,
    daily_return    NUMERIC(10,6),
    market_cap      NUMERIC(22,2)
)
PARTITION BY RANGE (date_key);

CREATE INDEX idx_fmp_ticker ON FactMarketPrices(ticker_key);
CREATE INDEX idx_fmp_date   ON FactMarketPrices(date_key);

-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS FactPortfolio (
    holding_key         BIGSERIAL       PRIMARY KEY,
    portfolio_key       INT             NOT NULL DEFAULT 1,
    ticker_key          BIGINT          NOT NULL REFERENCES DimTicker(ticker_key),
    date_key            INT             NOT NULL REFERENCES DimDate(date_key),
    weight              NUMERIC(8,6),
    daily_return        NUMERIC(10,6),
    benchmark_return    NUMERIC(10,6),
    beta                NUMERIC(8,4),
    std_dev             NUMERIC(10,6),
    risk_free_rate      NUMERIC(10,8),
    market_value        NUMERIC(18,2)
);

CREATE INDEX idx_fp_ticker ON FactPortfolio(ticker_key);
CREATE INDEX idx_fp_date   ON FactPortfolio(date_key);

-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS FactCreditRisk (
    risk_key            BIGSERIAL       PRIMARY KEY,
    borrower_key        INT             NOT NULL,
    date_key            INT             NOT NULL REFERENCES DimDate(date_key),
    rating              VARCHAR(10)     NOT NULL,
    sector              VARCHAR(100),
    tenor_band          VARCHAR(20),
    ead                 NUMERIC(18,2)   NOT NULL COMMENT 'Exposure At Default',
    pd                  NUMERIC(8,6)    NOT NULL COMMENT 'Probability of Default',
    lgd                 NUMERIC(8,6)    NOT NULL COMMENT 'Loss Given Default',
    collateral_value    NUMERIC(18,2),
    -- Calculated: Expected Loss = PD * EAD * LGD
    expected_loss       NUMERIC(18,2)
        GENERATED ALWAYS AS (pd * ead * lgd) STORED
);

CREATE INDEX idx_fcr_rating ON FactCreditRisk(rating);
CREATE INDEX idx_fcr_sector ON FactCreditRisk(sector);
CREATE INDEX idx_fcr_date   ON FactCreditRisk(date_key);

-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS FactFPA (
    fpa_key             BIGSERIAL       PRIMARY KEY,
    department_key      BIGINT          NOT NULL REFERENCES DimDepartment(department_key),
    date_key            INT             NOT NULL REFERENCES DimDate(date_key),
    cost_centre         VARCHAR(50),
    gl_account          VARCHAR(30),
    budget              NUMERIC(18,2)   NOT NULL DEFAULT 0,
    actual              NUMERIC(18,2)   NOT NULL DEFAULT 0,
    forecast            NUMERIC(18,2)   NOT NULL DEFAULT 0,
    -- Calculated variance
    variance_amt        NUMERIC(18,2)
        GENERATED ALWAYS AS (actual - budget) STORED
);

CREATE INDEX idx_fpa_dept ON FactFPA(department_key);
CREATE INDEX idx_fpa_date ON FactFPA(date_key);

-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS FactTreasury (
    treasury_key            BIGSERIAL       PRIMARY KEY,
    account_key             INT             NOT NULL,
    date_key                INT             NOT NULL REFERENCES DimDate(date_key),
    currency_code           CHAR(3)         NOT NULL,
    cash_balance            NUMERIC(18,2),
    fx_long                 NUMERIC(18,2),
    fx_short                NUMERIC(18,2),
    hqla                    NUMERIC(18,2)   COMMENT 'High Quality Liquid Assets',
    net_cash_outflows_30d   NUMERIC(18,2),
    rsf                     NUMERIC(18,2)   COMMENT 'Required Stable Funding',
    asf                     NUMERIC(18,2)   COMMENT 'Available Stable Funding'
);

CREATE INDEX idx_ft_currency ON FactTreasury(currency_code);
CREATE INDEX idx_ft_date     ON FactTreasury(date_key);

-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS FactFraud (
    fraud_key           BIGSERIAL       PRIMARY KEY,
    transaction_key     BIGINT          NOT NULL,
    date_key            INT             NOT NULL REFERENCES DimDate(date_key),
    vendor_key          INT,
    amount              NUMERIC(14,2)   NOT NULL,
    first_digit         SMALLINT,
    is_duplicate        BOOLEAN         NOT NULL DEFAULT FALSE,
    is_weekend          BOOLEAN         NOT NULL DEFAULT FALSE,
    hour_of_day         SMALLINT,
    fraud_score         NUMERIC(4,2),
    flag_reason         VARCHAR(100)
);

CREATE INDEX idx_ffraud_date   ON FactFraud(date_key);
CREATE INDEX idx_ffraud_score  ON FactFraud(fraud_score);
CREATE INDEX idx_ffraud_reason ON FactFraud(flag_reason);

-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS FactESG (
    esg_key             BIGSERIAL       PRIMARY KEY,
    company_key         BIGINT          NOT NULL REFERENCES DimCompany(company_key),
    period_key          INT             NOT NULL,
    e_score             NUMERIC(5,2),
    s_score             NUMERIC(5,2),
    g_score             NUMERIC(5,2),
    carbon_intensity    NUMERIC(10,4),
    renewable_pct       NUMERIC(5,4),
    board_diversity_pct NUMERIC(5,4),
    water_usage         NUMERIC(14,2),
    employee_turnover   NUMERIC(5,4),
    -- Composite ESG Score: 40% E + 35% S + 25% G
    esg_composite       NUMERIC(5,2)
        GENERATED ALWAYS AS (e_score * 0.40 + s_score * 0.35 + g_score * 0.25) STORED
);

CREATE INDEX idx_fesg_company ON FactESG(company_key);
CREATE INDEX idx_fesg_period  ON FactESG(period_key);
