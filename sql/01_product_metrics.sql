-- PostgreSQL. Перед запуском импортируйте users.csv в таблицу users,
-- events.csv в таблицу events. Даты: signup_date DATE, event_time TIMESTAMP.

-- 1. Проверка количества пользователей и событий
SELECT COUNT(DISTINCT user_id) AS users_count FROM users;
SELECT event_name, COUNT(DISTINCT user_id) AS users_count
FROM events GROUP BY event_name ORDER BY users_count DESC;

-- 2. Onboarding-воронка: уникальные пользователи на каждом шаге
SELECT event_name, COUNT(DISTINCT user_id) AS users_count
FROM events
WHERE event_name IN ('app_opened', 'tutorial_started', 'tutorial_completed',
                     'first_lesson_started', 'first_lesson_completed')
GROUP BY event_name
ORDER BY CASE event_name
    WHEN 'app_opened' THEN 1
    WHEN 'tutorial_started' THEN 2
    WHEN 'tutorial_completed' THEN 3
    WHEN 'first_lesson_started' THEN 4
    WHEN 'first_lesson_completed' THEN 5 END;

-- 3. Activation rate: первый урок завершён в течение 24 часов после регистрации
WITH activated AS (
    SELECT DISTINCT e.user_id
    FROM events e
    JOIN users u USING (user_id)
    WHERE e.event_name = 'first_lesson_completed'
      AND e.event_time >= u.signup_date
      AND e.event_time < u.signup_date + INTERVAL '24 hours'
)
SELECT COUNT(*) AS activated_users,
       ROUND(COUNT(*)::numeric / (SELECT COUNT(*) FROM users), 4) AS activation_rate
FROM activated;

-- 4. Retention D1 и D7 по календарным дням
WITH user_activity AS (
    SELECT DISTINCT e.user_id,
           (e.event_time::date - u.signup_date) AS days_after_signup
    FROM events e JOIN users u USING (user_id)
    WHERE e.event_name = 'session_started'
)
SELECT days_after_signup,
       COUNT(DISTINCT user_id) AS returned_users,
       ROUND(COUNT(DISTINCT user_id)::numeric / (SELECT COUNT(*) FROM users), 4) AS retention
FROM user_activity
WHERE days_after_signup IN (1, 7)
GROUP BY days_after_signup ORDER BY days_after_signup;

-- 5. Activation по каналу и платформе
WITH activation AS (
    SELECT DISTINCT e.user_id
    FROM events e JOIN users u USING (user_id)
    WHERE e.event_name = 'first_lesson_completed'
      AND e.event_time >= u.signup_date
      AND e.event_time < u.signup_date + INTERVAL '24 hours'
)
SELECT u.acquisition_channel, u.platform,
       COUNT(*) AS registered_users,
       COUNT(a.user_id) AS activated_users,
       ROUND(COUNT(a.user_id)::numeric / COUNT(*), 4) AS activation_rate
FROM users u LEFT JOIN activation a USING (user_id)
GROUP BY u.acquisition_channel, u.platform
ORDER BY activation_rate DESC;
