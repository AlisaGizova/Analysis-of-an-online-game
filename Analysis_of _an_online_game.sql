/* Анализ онлайн-игры
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Гизова Алиса
 * Дата: 22.01.2025
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков
-- 1.1. Доля платящих пользователей по всем данным:

SELECT
	-- общее количество игроков, зарегистрированных в игре 
	COUNT(id) AS total_users,
	-- количество платящих игроков
	SUM(payer) AS paying_users,
	-- доля платящих игроков от общего количества пользователей, зарегистрированных в игре
	ROUND(AVG(payer), 2) AS paying_users_share
FROM fantasy.users;

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:

SELECT 
	-- раса персонажа 
	r.race,
	-- общее количество зарегистрированных игроков
	COUNT(u.id) AS total_users,
	-- количество платящих игроков
	SUM(u.payer) AS paying_users,
	-- доля платящих игроков от общего количества пользователей, зарегистрированных в игре
	ROUND(AVG(u.payer), 2) AS paying_users_share
FROM fantasy.users AS u
JOIN fantasy.race AS r USING(race_id)
GROUP BY r.race
ORDER BY paying_users_share DESC;

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:

SELECT 
	-- общее количество покупок
	COUNT(transaction_id) AS total_transactions,
	--суммарная стоимость всех покупок 
	SUM(amount) AS total_amount,
	-- минимальная стоимость всех покупок
	MIN(amount) AS min_amount,
	-- максимальная стоимость всех покупок
	ROUND(MAX(amount)) AS max_amount,
	--среднее значение стоимости покупки
	ROUND(AVG(amount)::numeric) AS avg_amount,
	-- медиана стоимости покупки
	ROUND(PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY amount)) AS mediana_amount,
	-- стандартное отклонение стоимости покупки
	ROUND(STDDEV(amount)::numeric) AS std_amount
FROM fantasy.events;

-- 2.2: Аномальные нулевые покупки:

-- общее количество покупок
WITH total_transactions AS(
	SELECT 
		COUNT(transaction_id) AS total_transactions
	FROM fantasy.events
),
-- количество покупок с нулевой стоимостью
zero_transactions AS(
	SELECT 
		COUNT(transaction_id) AS zero_transactions
	FROM fantasy.events
	WHERE amount = 0
)
SELECT 
	-- количество покупок с нулевой стоимостью
	CASE
		WHEN zero_transactions <> 0 THEN zero_transactions
		ELSE NULL
	END AS zero_transactions,
	-- доля покупок с нулевой стоимостью от общего числа покупок
	CASE
		WHEN zero_transactions <> 0 THEN ROUND(zero_transactions::numeric / (SELECT total_transactions FROM total_transactions), 5)
		ELSE NULL
	END AS zero_transactions_share
FROM zero_transactions;

-- 2.3: Сравнительный анализ активности платящих и неплатящих игроков:

-- активность игроков по покупке предметов
WITH per_user AS(
	SELECT 
		DISTINCT id,
		COUNT(transaction_id) AS transactions_per_user,
		SUM(amount) AS amount_per_user
	FROM fantasy.events
	WHERE amount <> 0
	GROUP BY id
)
SELECT 
	-- статус игрока
	CASE	
		WHEN u.payer = 1 THEN 'платящие'
		ELSE 'неплатящие'
	END AS user_status,
	-- общее количество игроков
	COUNT(u.id) AS count_users,
	-- среднее количество покупок на одного игрока
	ROUND(AVG(p.transactions_per_user)) AS avg_transactions_per_user,
	-- суммарная стоимость покупок на одного игрока
	ROUND(AVG(p.amount_per_user)::numeric) AS avg_amount_per_user
FROM fantasy.users AS u
JOIN per_user AS p USING(id)
GROUP BY u.payer;
	
-- 2.4: Популярные эпические предметы:

-- общее количество продаж
WITH total_transactions AS(
	SELECT 
		COUNT(transaction_id) AS total_transactions
	FROM fantasy.events
	WHERE amount <> 0
),
-- общее количество пользователей
total_users AS(
	SELECT 
		COUNT(id) AS total_users
	FROM fantasy.users
)
SELECT 
	-- название эпического предмета
	i.game_items,
	-- общее количество внутриигровых продаж
	COUNT(e.transaction_id) AS item_transactions,
	-- доля продаж каждого предмета от всех продаж
	COUNT(e.transaction_id)::numeric / (SELECT total_transactions FROM total_transactions) AS item_transactions_share,
	-- доля игроков, которые хотя бы раз покупали этот предмет
	COUNT(DISTINCT e.id)::numeric / (SELECT total_users FROM total_users) AS item_users_share
FROM fantasy.items AS i
LEFT JOIN fantasy.events AS e USING(item_code)
WHERE amount <> 0
GROUP BY i.game_items
ORDER BY item_users_share DESC;

-- Часть 2. Решение ad hoc-задач
-- Задача 1. Зависимость активности игроков от расы персонажа:

-- общее количество зарегистрированных игроков для каждой расы
WITH users_count AS(
	SELECT 
		r.race,
		COUNT(DISTINCT u.id) AS users_count
	FROM fantasy.race AS r
	JOIN fantasy.users AS u USING(race_id)
	GROUP BY r.race
),
-- количество игроков, которые совершили покупку, и доля платящих игроков среди них в разрезе расы
paying_users AS(
	SELECT 
		r.race,
		COUNT(DISTINCT e.id) AS buying_users,
		COUNT(DISTINCT e.id) FILTER (WHERE u.payer = 1) AS paying_users
	FROM fantasy.race AS r
	JOIN fantasy.users AS u USING(race_id)
	JOIN fantasy.events AS e USING(id)
	WHERE e.amount <> 0
	GROUP BY r.race
),
-- информация об активности игроков с учётом расы персонажа
users_activity AS(
	SELECT 
		r.race,
		COUNT(e.transaction_id) / COUNT(DISTINCT u.id) AS avg_transactions_per_user,
		ROUND(SUM(e.amount)::numeric / COUNT(e.transaction_id)) AS avg_amount_per_user,
		ROUND(SUM(e.amount)::numeric  / COUNT(DISTINCT u.id)) AS avg_sum_amount_per_user
	FROM fantasy.users AS u
	LEFT JOIN fantasy.events AS e USING(id)
	JOIN fantasy.race AS r USING(race_id)
	WHERE e.amount <> 0
	GROUP BY r.race
)
SELECT 
	c.race,
	-- общее количество зарегистрированных игроков
	c.users_count,
	-- количество игроков, которые совершают внутриигровые покупки
	p.buying_users,
	-- доля игроков, которые совершают внутриигровые покупки, от общего количества
	ROUND(p.buying_users::numeric/ c.users_count, 2) AS buying_users_share,
	-- доля платящих игроков от количества игроков, которые совершили покупки
	ROUND(p.paying_users::numeric / p.buying_users, 2) AS paying_users_share,
	-- среднее количество покупок на одного игрока
	u.avg_transactions_per_user,
	-- средняя стоимость одной покупки на одного игрока
	u.avg_amount_per_user,
	-- средняя суммарная стоимость всех покупок на одного игрока
	u.avg_sum_amount_per_user
FROM users_count AS c
JOIN paying_users AS p ON c.race = p.race
JOIN users_activity AS u ON p.race = u.race
ORDER BY u.avg_transactions_per_user DESC;

-- Задача 2: Частота покупок

-- количество дней с предыдущей покупки для каждой покупки
WITH time_between_transactions AS(
	SELECT
		u.id,
		e.transaction_id,
		e.date::date - LAG(e.date::date) OVER (PARTITION BY u.id ORDER BY e.date::date) AS time_between_transactions
	FROM fantasy.users AS u
	LEFT JOIN fantasy.events AS e USING(id)
	WHERE amount <> 0
),
-- общее количество покупок и среднее значение по количеству дней между покупками (с учётом минимального количества покупок на одного игрока)
users AS(
	SELECT
		t.id,
		COUNT(t.transaction_id) AS count_transactions,
		AVG(t.time_between_transactions) AS avg_time_between_transactions,
		u.payer
	FROM time_between_transactions AS t
	LEFT JOIN fantasy.users AS u USING(id) 
	GROUP BY t.id, u.payer
	HAVING COUNT(t.transaction_id) >= 25
),
-- ранжирование игроков по среднему количеству дней между покупками
buy_frequency AS(
	SELECT
		id,
		count_transactions,
		avg_time_between_transactions,
		payer,
		NTILE(3) OVER (ORDER BY avg_time_between_transactions) AS frequency_category
	FROM users
)
SELECT
	-- группы игроков по частоте покупки
	CASE
		WHEN frequency_category = 1 THEN 'высокая частота'
		WHEN frequency_category = 2 THEN 'умеренная частота' 
		WHEN frequency_category = 3 THEN 'низкая частота'
	END AS buy_frequency_category,
	-- количество игроков, которые совершили покупки
	COUNT (DISTINCT id) AS count_users,
	-- количество платящих игроков, совершивших покупки
	COUNT (DISTINCT id) FILTER (WHERE payer = 1) AS paying_users,
	-- доля платящих игроков, совершивших покупку, от общего количества игроков, совершивших покупку;
	ROUND((COUNT (DISTINCT id) FILTER (WHERE payer = 1))::numeric / COUNT (DISTINCT id), 2) AS paying_users_share,
	-- среднее количество покупок на одного игрока
	ROUND(AVG(count_transactions)) AS avg_count_transactions_per_user,
	-- среднее количество дней между покупками на одного игрока
	ROUND(AVG(avg_time_between_transactions)) AS avg_time_between_transactions
FROM buy_frequency
GROUP BY buy_frequency_category

ORDER BY avg_time_between_transactions;
