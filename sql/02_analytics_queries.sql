-- ============================================================================
-- ENTERPRISE FINANCIAL ANALYTICS — ADVANCED SQL QUERIES
-- Window Functions · CTEs · Stored Procedures · Views · Recursive Queries
-- Author  : Phil Kibet | Biostatistician & Financial Data Analyst
-- ============================================================================

-- ── 1. ROLLING 12-MONTH REVENUE WITH YoY GROWTH ─────────────────────────────
-- Demonstrates: PARTITION BY, LAG, SUM OVER ROWS

WITH monthly_revenue AS (
    SELECT
        c.company_name,
        c.sector,
        d.fiscal_year,
        d.month_number,
        d.MonthName,
        SUM(f.revenue)                                          AS monthly_rev,
        SUM(SUM(f.revenue)) OVER (
            PARTITION BY c.company_key
            ORDER BY d.fiscal_year, d.month_number
            ROWS BETWEEN 11 PRECEDING AND CURRENT ROW
        )                                                       AS rolling_12m_rev,
        LAG(SUM(f.revenue), 12) OVER (
            PARTITION BY c.company_key
            ORDER BY d.fiscal_year, d.month_number
        )                                                       AS prior_year_rev
    FROM FactFinancials   f
    JOIN DimCompany       c ON c.company_key = f.company_key
    JOIN DimDate          d ON d.date_key    = f.date_key
    GROUP BY c.company_key, c.company_name, c.sector,
             d.fiscal_year, d.month_number, d.MonthName
)
SELECT
    company_name,
    sector,
    fiscal_year,
    MonthName,
    ROUND(monthly_rev,       0)                                 AS revenue,
    ROUND(rolling_12m_rev,   0)                                 AS rolling_12m,
    ROUND(
        (monthly_rev - prior_year_rev)
        / NULLIF(prior_year_rev, 0) * 100, 2
    )                                                           AS yoy_growth_pct
FROM monthly_revenue
ORDER BY company_name, fiscal_year, month_number;


-- ── 2. DUPONT ROE DECOMPOSITION (Multi-level CTE) ────────────────────────────
-- Net Margin × Asset Turnover × Equity Multiplier = ROE

WITH profitability AS (
    SELECT
        f.company_key,
        SUM(f.revenue)                                          AS total_revenue,
        SUM(f.net_income)                                       AS total_net_income,
        ROUND(SUM(f.net_income) / NULLIF(SUM(f.revenue), 0) * 100, 2)
                                                                AS net_margin_pct
    FROM FactFinancials f
    WHERE f.fiscal_year = 2024
    GROUP BY f.company_key
),
efficiency AS (
    SELECT
        b.company_key,
        AVG(b.total_assets)                                     AS avg_total_assets,
        ROUND(p.total_revenue / NULLIF(AVG(b.total_assets), 0), 3)
                                                                AS asset_turnover
    FROM FactBalanceSheet b
    JOIN profitability    p ON p.company_key = b.company_key
    GROUP BY b.company_key, p.total_revenue
),
leverage AS (
    SELECT
        b.company_key,
        ROUND(AVG(b.total_assets) / NULLIF(AVG(b.total_equity), 0), 2)
                                                                AS equity_multiplier
    FROM FactBalanceSheet b
    GROUP BY b.company_key
)
SELECT
    c.company_name,
    c.sector,
    c.region,
    ROUND(p.net_margin_pct, 2)                                  AS net_margin_pct,
    ROUND(e.asset_turnover, 3)                                  AS asset_turnover,
    ROUND(l.equity_multiplier, 2)                               AS equity_multiplier,
    ROUND(
        p.net_margin_pct / 100
        * e.asset_turnover
        * l.equity_multiplier * 100, 2
    )                                                           AS roe_dupont_pct
FROM profitability p
JOIN efficiency    e USING (company_key)
JOIN leverage      l USING (company_key)
JOIN DimCompany    c ON c.company_key = p.company_key
ORDER BY roe_dupont_pct DESC;


-- ── 3. QUARTILE RANKING BY GROSS MARGIN ──────────────────────────────────────
-- Demonstrates: NTILE, DENSE_RANK, PERCENT_RANK

SELECT
    c.company_name,
    c.sector,
    ROUND(f.gross_profit / NULLIF(f.revenue, 0) * 100, 2)      AS gross_margin_pct,
    NTILE(4) OVER (
        ORDER BY f.gross_profit / NULLIF(f.revenue, 0) DESC
    )                                                           AS global_quartile,
    DENSE_RANK() OVER (
        PARTITION BY c.sector
        ORDER BY f.gross_profit / NULLIF(f.revenue, 0) DESC
    )                                                           AS sector_rank,
    PERCENT_RANK() OVER (
        PARTITION BY c.sector
        ORDER BY f.gross_profit / NULLIF(f.revenue, 0)
    )                                                           AS pct_rank_in_sector,
    AVG(f.gross_profit / NULLIF(f.revenue, 0)) OVER (
        PARTITION BY c.sector
    )                                                           AS sector_avg_gm
FROM FactFinancials f
JOIN DimCompany     c ON c.company_key = f.company_key
WHERE f.fiscal_year = 2024;


-- ── 4. EXPECTED LOSS STORED PROCEDURE ────────────────────────────────────────
-- PD × EAD × LGD with risk tier classification

CREATE OR REPLACE PROCEDURE sp_calc_expected_loss(p_as_of_date DATE)
LANGUAGE plpgsql AS $$
BEGIN
    TRUNCATE TABLE stage_credit_risk;

    INSERT INTO stage_credit_risk (
        borrower_key, rating, sector,
        ead, pd, lgd, expected_loss, risk_tier
    )
    SELECT
        cr.borrower_key,
        cr.rating,
        cr.sector,
        cr.ead,
        cr.pd,
        cr.lgd,
        ROUND(cr.pd * cr.ead * cr.lgd, 2)                      AS expected_loss,
        CASE
            WHEN cr.pd < 0.01  THEN 'Green'
            WHEN cr.pd < 0.05  THEN 'Amber'
            WHEN cr.pd < 0.15  THEN 'Red'
            ELSE                    'Critical'
        END                                                     AS risk_tier
    FROM FactCreditRisk cr
    WHERE cr.date_key = TO_CHAR(p_as_of_date, 'YYYYMMDD')::INT;

    RAISE NOTICE 'Expected Loss calculated for %', p_as_of_date;
END;
$$;


-- ── 5. BENFORD LAW FRAUD DETECTION ───────────────────────────────────────────
-- First-digit distribution test on journal entries

WITH benford_expected AS (
    SELECT digit,
           LOG(1 + 1.0 / digit) / LOG(10)                      AS expected_pct
    FROM   (VALUES (1),(2),(3),(4),(5),(6),(7),(8),(9)) t(digit)
),
actual_distribution AS (
    SELECT
        CAST(LEFT(CAST(ABS(f.amount) AS VARCHAR), 1) AS INT)   AS digit,
        COUNT(*)                                                AS actual_count
    FROM   FactFraud f
    WHERE  ABS(f.amount) >= 1
    GROUP  BY LEFT(CAST(ABS(f.amount) AS VARCHAR), 1)
),
freq_compare AS (
    SELECT
        a.digit,
        a.actual_count,
        SUM(a.actual_count) OVER ()                             AS total_txns,
        a.actual_count * 1.0 / SUM(a.actual_count) OVER ()     AS actual_pct,
        b.expected_pct,
        ABS(
            a.actual_count * 1.0 / SUM(a.actual_count) OVER ()
            - b.expected_pct
        )                                                       AS abs_deviation
    FROM   actual_distribution a
    JOIN   benford_expected     b ON b.digit = a.digit
)
SELECT
    digit,
    ROUND(actual_pct   * 100, 2)                                AS actual_pct,
    ROUND(expected_pct * 100, 2)                                AS expected_pct,
    ROUND(abs_deviation * 100, 2)                               AS deviation_pct,
    CASE WHEN abs_deviation > 0.03 THEN 'FLAG' ELSE 'OK' END   AS status
FROM   freq_compare
ORDER  BY digit;


-- ── 6. FP&A VARIANCE ANALYSIS VIEW ───────────────────────────────────────────

CREATE OR REPLACE VIEW vw_fpa_variance AS
SELECT
    dd.department_name,
    dd.division,
    d.fiscal_year,
    d.MonthName,
    f.cost_centre,
    ROUND(f.budget,   2)                                        AS budget,
    ROUND(f.actual,   2)                                        AS actual,
    ROUND(f.forecast, 2)                                        AS forecast,
    ROUND(f.actual - f.budget, 2)                               AS variance_amt,
    ROUND((f.actual - f.budget) / NULLIF(f.budget, 0) * 100, 2)
                                                                AS variance_pct,
    CASE
        WHEN (f.actual - f.budget) / NULLIF(f.budget, 0) > 0.05   THEN 'Over Budget'
        WHEN (f.actual - f.budget) / NULLIF(f.budget, 0) < -0.05  THEN 'Favourable'
        ELSE 'On Track'
    END                                                         AS budget_status,
    ROUND(
        1 - ABS(f.forecast - f.actual) / NULLIF(ABS(f.actual), 0), 4
    )                                                           AS forecast_accuracy
FROM   FactFPA           f
JOIN   DimDepartment     dd ON dd.department_key = f.department_key
JOIN   DimDate           d  ON d.date_key        = f.date_key;


-- ── 7. TREASURY LCR / NSFR CALCULATION ───────────────────────────────────────

SELECT
    t.currency_code,
    d.fiscal_year,
    d.MonthName,
    ROUND(SUM(t.cash_balance),                    2)            AS total_cash,
    ROUND(SUM(t.hqla),                            2)            AS hqla,
    ROUND(SUM(t.net_cash_outflows_30d),           2)            AS net_outflows_30d,
    ROUND(
        SUM(t.hqla)
        / NULLIF(SUM(t.net_cash_outflows_30d), 0) * 100, 2
    )                                                           AS lcr_pct,
    ROUND(SUM(t.asf),                             2)            AS asf,
    ROUND(SUM(t.rsf),                             2)            AS rsf,
    ROUND(
        SUM(t.asf) / NULLIF(SUM(t.rsf), 0) * 100, 2
    )                                                           AS nsfr_pct,
    CASE
        WHEN SUM(t.hqla) / NULLIF(SUM(t.net_cash_outflows_30d), 0) >= 1
        THEN 'Compliant' ELSE 'Breach'
    END                                                         AS lcr_status
FROM   FactTreasury t
JOIN   DimDate      d ON d.date_key = t.date_key
GROUP  BY t.currency_code, d.fiscal_year, d.MonthName
ORDER  BY d.fiscal_year, t.currency_code;


-- ── 8. PORTFOLIO SHARPE RATIO ─────────────────────────────────────────────────

SELECT
    dt.gics_sector,
    dt.ticker,
    ROUND(AVG(fp.daily_return),                              6) AS avg_daily_return,
    ROUND(STDDEV_POP(fp.daily_return),                       6) AS std_dev,
    ROUND(AVG(fp.risk_free_rate),                            8) AS avg_rfr,
    ROUND(
        (AVG(fp.daily_return) - AVG(fp.risk_free_rate))
        / NULLIF(STDDEV_POP(fp.daily_return), 0)
        * SQRT(252), 4
    )                                                           AS sharpe_ratio_annualised,
    ROUND(AVG(fp.beta),                                      4) AS avg_beta,
    ROUND(SUM(fp.market_value),                              2) AS total_market_value,
    ROUND(AVG(fp.weight) * 100,                              2) AS avg_weight_pct
FROM   FactPortfolio fp
JOIN   DimTicker     dt ON dt.ticker_key = fp.ticker_key
GROUP  BY dt.gics_sector, dt.ticker
ORDER  BY sharpe_ratio_annualised DESC;


-- ── 9. ESG COMPOSITE SCORE WITH RATING ───────────────────────────────────────

SELECT
    c.company_name,
    c.sector,
    c.region,
    ROUND(AVG(e.e_score),                   2)                 AS avg_e_score,
    ROUND(AVG(e.s_score),                   2)                 AS avg_s_score,
    ROUND(AVG(e.g_score),                   2)                 AS avg_g_score,
    ROUND(
        AVG(e.e_score) * 0.40
        + AVG(e.s_score) * 0.35
        + AVG(e.g_score) * 0.25, 2
    )                                                           AS esg_composite,
    CASE
        WHEN AVG(e.e_score)*0.4+AVG(e.s_score)*0.35+AVG(e.g_score)*0.25 >= 80 THEN 'AAA'
        WHEN AVG(e.e_score)*0.4+AVG(e.s_score)*0.35+AVG(e.g_score)*0.25 >= 70 THEN 'AA'
        WHEN AVG(e.e_score)*0.4+AVG(e.s_score)*0.35+AVG(e.g_score)*0.25 >= 60 THEN 'A'
        WHEN AVG(e.e_score)*0.4+AVG(e.s_score)*0.35+AVG(e.g_score)*0.25 >= 50 THEN 'BBB'
        ELSE 'BB'
    END                                                         AS esg_rating,
    ROUND(AVG(e.carbon_intensity),          2)                 AS avg_carbon_intensity,
    ROUND(AVG(e.board_diversity_pct) * 100, 1)                 AS board_diversity_pct,
    RANK() OVER (
        ORDER BY
            AVG(e.e_score)*0.4+AVG(e.s_score)*0.35+AVG(e.g_score)*0.25 DESC
    )                                                           AS esg_rank
FROM   FactESG    e
JOIN   DimCompany c ON c.company_key = e.company_key
GROUP  BY c.company_name, c.sector, c.region
ORDER  BY esg_composite DESC;


-- ── 10. MATERIALIZED VIEW: MONTHLY KPI SUMMARY ───────────────────────────────

CREATE MATERIALIZED VIEW mv_monthly_kpi_summary AS
SELECT
    c.company_name,
    c.sector,
    c.region,
    d.fiscal_year,
    d.MonthName,
    d.Month,
    SUM(f.revenue)                                              AS revenue,
    SUM(f.gross_profit)                                         AS gross_profit,
    SUM(f.ebitda)                                               AS ebitda,
    SUM(f.net_income)                                           AS net_income,
    ROUND(SUM(f.gross_profit)/NULLIF(SUM(f.revenue),0)*100, 2) AS gross_margin_pct,
    ROUND(SUM(f.ebitda)      /NULLIF(SUM(f.revenue),0)*100, 2) AS ebitda_margin_pct,
    ROUND(SUM(f.net_income)  /NULLIF(SUM(f.revenue),0)*100, 2) AS net_margin_pct,
    MAX(b.total_assets)                                         AS total_assets,
    MAX(b.total_debt)                                           AS total_debt,
    MAX(b.total_equity)                                         AS total_equity,
    ROUND(MAX(b.total_debt)/NULLIF(MAX(b.total_equity),0), 2)  AS debt_to_equity
FROM   FactFinancials f
JOIN   DimCompany     c ON c.company_key = f.company_key
JOIN   DimDate        d ON d.date_key    = f.date_key
LEFT   JOIN FactBalanceSheet b ON b.company_key = f.company_key
                               AND b.date_key   = f.date_key
GROUP  BY c.company_name, c.sector, c.region,
          d.fiscal_year, d.MonthName, d.Month;

-- Refresh nightly
-- REFRESH MATERIALIZED VIEW mv_monthly_kpi_summary;
