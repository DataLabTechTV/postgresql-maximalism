/*
 * Category: Time Series
 * Extension: timescaledb
 * Task: Data normalization (dislikes).
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



-- TEST WEEKLY DISLIKES: NORMALITY, LOG-NORMALITY, POWER LAW

-- Normality test
SELECT
    bucket AS week_start,
    test_normality(array_agg(dislikes), sample_size => 1000) AS is_normal
FROM youtube_ts_weekly_stats
GROUP BY week_start
ORDER BY week_start;

-- Log-normality test
SELECT
    bucket AS week_start,
    test_normality(array_agg(log(dislikes)), sample_size => 1000) AS is_log_normal
FROM youtube_ts_weekly_stats
GROUP BY week_start
ORDER BY week_start;

-- Power law test
SELECT
    bucket AS week_start,
    test_powerlaw(array_agg(dislikes), sample_size => 1000) AS is_powerlaw
FROM youtube_ts_weekly_stats
GROUP BY week_start
ORDER BY week_start;



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



-- NORMALLY DISTRIBUTED TRANSFORMATIONS

-- If it's the first run, also execute the SET by itself.
ALTER DATABASE datalabtech
SET timescaledb.max_tuples_decompressed_per_dml_transaction TO 0;

DROP MATERIALIZED VIEW IF EXISTS youtube_ts_weekly_features;

SELECT * FROM youtube_ts_weekly_stats LIMIT 10;

-- Non-CE materialized view due to use of CTEs
CREATE MATERIALIZED VIEW youtube_ts_weekly_features(
    bucket,
    ytvideoid,
    norm_dislikes
) AS
WITH weekly_dislikes AS (
    SELECT
        bucket::date AS week_start,
        array_agg(
            dislikes::double precision
            ORDER BY bucket, ytvideoid
        ) AS week_dislikes,
        array_agg(
            ytvideoid
            ORDER BY bucket, ytvideoid
        ) AS week_ytvideoids
    FROM youtube_ts_weekly_stats
    GROUP BY bucket
),
norm_weekly_dislikes AS (
    SELECT
        week_start,
        ytvideoid.val AS ytvideoid,
        norm_dislikes.val AS norm_dislikes
    FROM weekly_dislikes w
    JOIN LATERAL unnest(w.week_ytvideoids)
        WITH ORDINALITY AS ytvideoid(val, ord)
    ON TRUE
    JOIN LATERAL unnest(
            to_normal_distribution(
                w.week_dislikes,
                method => 1
            )
        )
        WITH ORDINALITY AS norm_dislikes(val, ord)
    ON ytvideoid.ord = norm_dislikes.ord
)
SELECT
    week_start,
    ytvideoid,
    norm_dislikes
FROM norm_weekly_dislikes;

SELECT * FROM youtube_ts_weekly_features;

-- Normality test (norm_dislikes)
-- See visualization notebook for plots
SELECT
    bucket AS week_start,
    test_normality(array_agg(norm_dislikes), sample_size => 1000) AS is_normal
FROM youtube_ts_weekly_features
GROUP BY week_start
ORDER BY week_start;
