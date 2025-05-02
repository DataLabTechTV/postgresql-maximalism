/*
 * Category: Time Series
 * Extension: timescaledb
 * Task: Anomaly detection using z-score.
 */



-- DISTRIBUTION TEST FUNCTIONS

DROP FUNCTION IF EXISTS test_normality;

CREATE OR REPLACE FUNCTION test_normality(
    data double precision[],
    p_threshold double precision DEFAULT 0.05
)
RETURNS boolean AS $$
    import scipy.stats
    stat, p = scipy.stats.shapiro(data)
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
    test_normality(array_agg(views)) AS is_normal
FROM youtube_ts
GROUP BY week_start;

-- Log-normality test
SELECT
    date_trunc('week', "timestamp") AS week_start,
    test_normality(array_agg(log(views))) AS is_log_normal
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

CREATE OR REPLACE FUNCTION to_normal_distribution(data double precision[])
RETURNS double precision[] AS $$
    import scipy.stats
    import numpy as np
    normalized_data, _ = scipy.stats.boxcox(data)
    return np.array(normalized_data).tolist()
$$ LANGUAGE plpython3u;


DROP FUNCTION IF EXISTS boxcox_transform;

CREATE OR REPLACE FUNCTION boxcox_transform(
    x double precision,
    lambda double precision
)
RETURNS double precision AS $$
BEGIN
    IF lambda = 0 THEN
        RETURN log(x);
    ELSE
        RETURN (power(x, lambda) - 1) / lambda;
    END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;


DROP FUNCTION IF EXISTS boxbox_estimate_lambda;

CREATE OR REPLACE FUNCTION boxbox_estimate_lambda(data double precision[])
RETURNS double precision AS $$
DECLARE
    mean_x double precision;
    mean_x_squared double precision;
BEGIN
    -- Calculate the sample mean of the data
    mean_x := (SELECT avg(val) FROM unnest(data) AS val);

    -- Calculate the sample mean of the squares of the data
    mean_x_squared := (SELECT avg(val^2) FROM unnest(data) AS val);

    -- Calculate lambda using the method of moments formula
    RETURN (3 * mean_x_squared - mean_x) / (2 * (mean_x_squared - mean_x^2));
END;
$$ LANGUAGE plpgsql IMMUTABLE;



-- ADD NORMALLY DISTRIBUTED VIEWS TRANSFORMATION

ALTER TABLE youtube_ts
ADD COLUMN norm_views double precision;

-- FIXME: "tuple decompression limit exceeded by operation
WITH weekly_lambda AS (
    SELECT
        date_trunc('week', "timestamp") AS week_start,
        boxbox_estimate_lambda(
            array_agg(views::double precision)
        ) AS lambda
    FROM youtube_ts
    GROUP BY week_start
)
UPDATE youtube_ts y
SET norm_views = boxcox_transform(y.views, w.lambda)
FROM weekly_lambda w
WHERE date_trunc('week', y."timestamp") = w.week_start;

SELECT *
FROM youtube_ts
LIMIT 100;
