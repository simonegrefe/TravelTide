--Step 1: CTE to filter sessions after 04.January 2023 and cleaning date type issues

WITH sessions_2023 AS (
	SELECT *
	FROM sessions
	WHERE session_start >= '2023-01-05'
)


  
--Step 2: CTE to filter for customers with more than 7 sessions

, over_7_sessions AS (
  SELECT user_id,
  			COUNT(session_id) num_sessions
  FROM sessions_2023
	GROUP BY user_id
	HAVING COUNT(session_id) > 7
)



--Step 3: CTEs to clean date type issues

, sessions_2023_cleaned AS (
  SELECT *,
 				CAST(session_start AS DATE) AS session_start_date,
  			CAST(session_end AS DATE) AS session_end_date
  FROM sessions_2023
)

, users_cleaned AS (
  SELECT *,
  			CAST(birthdate AS DATE) AS birthdate_date,
  			CAST(sign_up_date AS DATE) AS sign_up_date_date
  FROM users
)

, flights_cleaned AS (
  SELECT *,
  			CAST(departure_time AS DATE)AS departure_time_date,
  			CAST(return_time AS DATE) AS return_time_date
  FROM flights
)

, hotels_cleaned AS (
  SELECT *,
  			CAST(check_in_time AS DATE) AS check_in_time_date,
  			CAST(check_out_time AS DATE) AS check_out_time_date
  FROM hotels
)



--Step 4: CTE to create new columns based on cleaning and organizing session based information


SELECT *,
  
--cleaning the calculation of nights due to wrong check_out_time as new column nights_cleaned

  			CASE
        		WHEN (check_out_time_date <= check_in_time_date) AND (return_time_date IS NOT NULL) THEN (return_time_date - check_in_time_date)
            WHEN (check_out_time_date <= check_in_time_date) AND (return_time_date IS NULL) THEN (check_out_time_date - departure_time_date)
            ELSE (check_out_time_date - check_in_time_date)
            END AS nights_cleaned,

--adding a column for cancellations as trip_status

        CASE
       			WHEN cancellation = true AND trip_id IS NOT NULL THEN 'cancelled'
            WHEN cancellation = false AND trip_id IS NOT NULL THEN 'booked'
  					ELSE 'none' END AS trip_status,

		MAX(CASE WHEN cancellation = true THEN 1 ELSE 0 END) OVER (PARTITION BY trip_id) AS trip_was_cancelled,


--adding a column for type of booking as booking_type

        CASE WHEN flight_booked = true AND hotel_booked = false THEN 'flight'
             WHEN flight_booked = false AND hotel_booked = true THEN 'hotel'
             WHEN flight_booked = true AND hotel_booked = true THEN 'flight-hotel'
             ELSE 'none' END AS booking_type,

  			CASE WHEN cancellation = false AND flight_booked
   							AND hotel_booked THEN 1 ELSE 0 END AS flight_and_hotel_booked,

--adding a column travel distance in km

    CASE WHEN cancellation = false THEN haversine_distance(home_airport_lat, home_airport_lon, destination_airport_lat, destination_airport_lon)
  		END AS travel_distance_km,

--adding a column number of travel days

			CASE
        WHEN flight_booked = true AND hotel_booked = false THEN (return_time_date - departure_time_date)
        WHEN flight_booked = false AND hotel_booked = true THEN (check_out_time_date - check_in_time_date)
        WHEN flight_booked = true AND hotel_booked = true THEN (return_time_date - departure_time_date)
        ELSE 0 END AS travel_days,


--adding a column flight cost

   		CASE WHEN cancellation = false THEN base_fare_usd::DEC * COALESCE((1 - flight_discount_amount), 1)
   			END AS flight_costs,


--adding a column to have hotel costs per room per night

		(hotel_per_room_usd * CASE
        										WHEN (check_out_time_date <= check_in_time_date) AND (return_time_date IS NOT NULL) THEN (return_time_date - check_in_time_date)
            								WHEN (check_out_time_date <= check_in_time_date) AND (return_time_date IS NULL) THEN (check_out_time_date - departure_time_date)
            								ELSE (check_out_time_date - check_in_time_date) END) AS hotel_costs,


--adding a column for session time (how many minutes per session)

		EXTRACT(epoch FROM(session_end - session_start))/60 AS minutes_in_session,


--adding a column to calculate travel only on week days (e.g. for business travellers)

  	CASE WHEN EXTRACT(dow FROM return_time) >= EXTRACT(dow FROM departure_time)
        AND (date(return_time) - date(departure_time)) <= 5
        AND EXTRACT(dow FROM departure_time) BETWEEN 1 AND 5
        AND EXTRACT(dow FROM return_time) BETWEEN 1 AND 5 THEN 1 ELSE 0 END AS is_trip_on_weekdays,


--adding a column with customer age in 2023

		EXTRACT(YEAR FROM age('2023-12-31', birthdate)) AS customer_age



--Join all tables

FROM sessions_2023_cleaned
LEFT JOIN users_cleaned USING (user_id)
LEFT JOIN flights_cleaned USING (trip_id)
LEFT JOIN hotels_cleaned USING (trip_id)


--Subquery to the second cte (filter for customers with more than 7 sessions)

WHERE user_id IN (SELECT user_id FROM over_7_sessions)
