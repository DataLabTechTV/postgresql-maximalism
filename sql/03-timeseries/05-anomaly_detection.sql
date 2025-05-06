/*
 * Category: Time Series
 * Extension: timescaledb
 * Task: Detecting anomalous days, view-wise.
 */



-- Inspiration: https://medium.com/booking-com-development/anomaly-detection-in-time-series-using-statistical-analysis-cc587b21d008
--
-- Steps for a single day of the current week being tested:
--
-- 0. Compute mean and stdev for each existing week.
-- 1. Compute four z-scores, based on the previous four weeks.
-- 2. Normalize absolute z-scores and exclude weeks with a normalized z-score outside of a 0.6 range of the median normalized z-score.
-- 3. Compute a single absolute z-score based on the mean/stdev of the selected weeks.
-- 4. Signal an anomaly when the absolute z-score is larger than 3.
