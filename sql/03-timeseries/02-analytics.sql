/*
 * Category: Time Series
 * Extension: timescaledb
 * Task: Anomaly detection using z-score.
 */



-- DISTRIBUTION TEST FUNCTIONS

DROP FUNCTION IF EXISTS test_normality;

CREATE OR REPLACE FUNCTION test_normality(
    data double precision[],
    p_threshold double precision DEFAULT 0.05,
    sample_size integer DEFAULT NULL
)
RETURNS boolean AS $$
    import numpy as np
    from scipy.stats import normaltest as normality_test

    if sample_size is None:
        _, p = normality_test(data)
    else:
        sample_data = np.random.choice(data, sample_size)
        _, p = normality_test(sample_data)

    return p > p_threshold
$$ LANGUAGE plpython3u;


DROP FUNCTION IF EXISTS test_powerlaw;

CREATE OR REPLACE FUNCTION test_powerlaw(
    data double precision[],
    p_threshold double precision DEFAULT 0.05,
    sample_size integer DEFAULT NULL
)
RETURNS boolean AS $$
    import numpy as np
    import powerlaw

    if sample_size is None:
        fit = powerlaw.Fit(data)
    else:
        sample_data = np.random.choice(data, sample_size)
        fit = powerlaw.Fit(sample_data)

    R, p = fit.distribution_compare('power_law', 'lognormal')

    return R > 0 and p < p_threshold
$$ LANGUAGE plpython3u;



-- TEST WEEKLY VIEWS: NORMALITY, LOG-NORMALITY, POWER LAW

-- Normality test
SELECT
    date_trunc('week', "timestamp") AS week_start,
    test_normality(array_agg(views), sample_size => 1000) AS is_normal
FROM youtube_ts
GROUP BY week_start;

-- Log-normality test
SELECT
    date_trunc('week', "timestamp") AS week_start,
    test_normality(array_agg(log(views)), sample_size => 1000) AS is_log_normal
FROM youtube_ts
GROUP BY week_start;

-- Power law test
SELECT
    date_trunc('week', "timestamp") AS week_start,
    test_powerlaw(array_agg(views), sample_size => 1000) AS is_powerlaw
FROM youtube_ts
GROUP BY week_start;



-- FUNCTION TO CONVERT TO A NORMAL DISTRIBUTION

DROP FUNCTION IF EXISTS to_normal_distribution;

CREATE OR REPLACE FUNCTION to_normal_distribution(
    data double precision[],
    method integer DEFAULT 0
)
RETURNS double precision[] AS $$
    import numpy as np

    if method == 0:
        from scipy.stats import boxcox
        normalized_data, _ = boxcox(data)

    elif method == 1:
        from sklearn.preprocessing import PowerTransformer
        pt = PowerTransformer(method="yeo-johnson")
        normalized_data = (
            pt.fit_transform(np.array(data).reshape(-1, 1)).flatten()
        )

    return normalized_data.tolist()
$$ LANGUAGE plpython3u;



-- ADD NORMALLY DISTRIBUTED VIEWS TRANSFORMATION

ALTER TABLE youtube_ts
ADD COLUMN norm_views double precision;

-- If it's the first run, also execute the SET by itself.
ALTER DATABASE datalabtech
SET timescaledb.max_tuples_decompressed_per_dml_transaction TO 0;

WITH weekly_views AS (
    SELECT
        date_trunc('week', "timestamp") AS week_start,
        array_agg(
            views::double precision
            ORDER BY videostatsid
        ) AS week_views,
        array_agg(
            videostatsid::integer
            ORDER BY videostatsid
        ) AS week_videostatsid
    FROM youtube_ts
    GROUP BY week_start
),
norm_weekly_views AS (
    SELECT
        week_start,
        v.val AS videostatsid,
        n.val AS norm_views
    FROM weekly_views w
    JOIN LATERAL UNNEST(w.week_videostatsid)
        WITH ORDINALITY AS v(val, ord)
    ON TRUE
    JOIN LATERAL UNNEST(to_normal_distribution(w.week_views, method => 1))
        WITH ORDINALITY AS n(val, ord)
    ON v.ord = n.ord
)
UPDATE youtube_ts y
SET norm_views = w.norm_views
FROM norm_weekly_views w
WHERE y.videostatsid = w.videostatsid;


SELECT
    date_trunc('week', "timestamp") AS week_start,
    test_normality(array_agg(norm_views), sample_size => 1000) AS is_normal
FROM youtube_ts
GROUP BY week_start;
