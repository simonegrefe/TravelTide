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

, session_based_final AS (

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

)



--USER BASED TABLE CTEs--


--Step 5: CTE for user_based_prep - totals

, user_based_prep_total AS (

SELECT user_id,

--adding columns for browsing behavior

        COUNT(session_id) AS total_sessions,
        SUM(page_clicks) AS total_page_clicks,
        SUM(minutes_in_session) AS total_minutes_in_sessions,

--adding columns for travel behavior

        COUNT(DISTINCT trip_id) AS total_bookings,
        SUM(CASE WHEN flight_booked = true AND cancellation = false THEN 1 ELSE 0 END) AS total_flight_bookings,
        SUM(CASE WHEN hotel_booked = true AND cancellation = false THEN 1 ELSE 0 END) AS total_hotel_bookings,
  			COUNT(DISTINCT CASE WHEN trip_status = 'booked' THEN trip_id END) AS not_cancelled_trips,
        SUM(seats) AS total_seats,
        SUM(checked_bags) AS total_bags,
  			SUM(rooms) AS total_rooms,
  			SUM(nights_cleaned) AS total_nights,
  			COUNT(DISTINCT CASE WHEN is_trip_on_weekdays = 1 THEN trip_id END) AS trips_on_weekdays,
  			SUM(flight_and_hotel_booked) AS flight_and_hotel_booked_total,
    		SUM(travel_distance_km) AS total_travelled_km,

--adding columns for costs and discounts

        COUNT(DISTINCT CASE WHEN hotel_discount OR flight_discount THEN trip_id END) AS bookings_with_discounts,
        SUM(hotel_costs) AS total_hotel_costs,
        SUM(flight_costs) AS total_flight_costs,
 				SUM(flight_discount_amount) AS total_flight_discount,
        SUM(hotel_discount_amount) AS total_hotel_discount,

--adding columns for user informations

        MAX(CASE WHEN married THEN 1 ELSE 0 END) AS is_married,
        MAX(CASE WHEN has_children THEN 1 ELSE 0 END) AS has_children,
       	MAX(CASE WHEN trip_id IS NOT NULL AND trip_status = 'booked' THEN date(session_start_date) END) - MIN(date(sign_up_date)) AS days_btw_last_booking_signup,
  			MAX(customer_age) AS age


FROM session_based_final
GROUP BY user_id

)


--Step 6: CTE for user_based information averages and ratios

, user_based_prep_avg AS (

SELECT user_id,
        MAX(is_married) as is_married,
        MAX(has_children) AS has_children,
        MAX(days_btw_last_booking_signup) AS days_btw_last_booking_signup,
        MAX(age) AS age,

--adding age-related columns

    	MAX(CASE WHEN age BETWEEN 20 AND 67 THEN 1 ELSE 0 END) AS is_in_working_age,
  		MAX(CASE WHEN age > 67 THEN 1 ELSE 0 END) AS is_senior,

--adding column for new_customer

   		MAX(CASE WHEN days_btw_last_booking_signup <= 28 THEN 1 ELSE 0 END) AS is_new_customer,

--adding columns for browsing metrics

			 COALESCE(MAX(total_page_clicks::decimal / NULLIF(total_sessions, 0)), 0) AS avg_page_clicks,
       COALESCE(MAX(total_minutes_in_sessions::decimal / NULLIF(total_sessions, 0)), 0) AS avg_minutes_per_session,

--adding columns for travel metrics

        COALESCE(MAX(total_bookings::decimal / NULLIF(total_sessions, 0)), 0) AS booking_rate,
				COALESCE(MAX(trips_on_weekdays::decimal / NULLIF(total_bookings, 0)), 0) AS weekdays_travel_quote,
  			COALESCE(MAX(total_travelled_km::decimal / NULLIF(total_bookings, 0)), 0) AS avg_travelled_km,
				COALESCE(MAX(not_cancelled_trips::decimal / NULLIF(total_bookings, 0)), 0) AS storno_quote,
				COALESCE(MAX(bookings_with_discounts::decimal / NULLIF(total_bookings, 0)), 0) AS discount_quote,
  			COALESCE(MAX(total_rooms::decimal / NULLIF(total_hotel_bookings, 0)), 0) AS avg_rooms_per_trip,
				COALESCE(MAX(total_seats::decimal / NULLIF(total_flight_bookings, 0)), 0) AS avg_seats_per_flight,
  			COALESCE(MAX(total_bags::decimal / NULLIF(total_flight_bookings, 0)), 0) AS avg_bags_per_flight,
 				COALESCE(MAX(total_hotel_costs::decimal / NULLIF(total_bookings, 0)), 0) AS avg_hotel_costs,
				COALESCE(MAX(total_flight_costs::decimal / NULLIF(total_bookings, 0)), 0) AS avg_flight_costs,

--add column for frequent flyer

  		CASE WHEN MAX(total_flight_bookings) > (SELECT PERCENTILE_DISC(0.9) WITHIN GROUP (ORDER BY total_flight_bookings) FROM user_based_prep_total)
      		THEN 1 ELSE 0 END AS is_frequent_flyer


FROM user_based_prep_total
GROUP BY user_id

)


--Step 7: CTE for most and less

, user_based_final AS (

SELECT user_id,

  CASE WHEN MAX(avg_page_clicks) > (SELECT PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY avg_page_clicks) FROM user_based_prep_avg)
    	THEN 1 ELSE 0 END AS is_active_clicker,

  CASE WHEN MAX(avg_page_clicks) > (SELECT PERCENTILE_CONT(0.1) WITHIN GROUP (ORDER BY avg_page_clicks) FROM user_based_prep_avg)
    	THEN 1 ELSE 0 END AS is_less_clicker,

  CASE WHEN MAX(avg_minutes_per_session) > (SELECT PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY avg_minutes_per_session) FROM user_based_prep_avg)
    	THEN 1 ELSE 0 END AS is_long_session_user,

  CASE WHEN MAX(avg_minutes_per_session) > (SELECT PERCENTILE_CONT(0.1) WITHIN GROUP (ORDER BY avg_minutes_per_session) FROM user_based_prep_avg)
    	THEN 1 ELSE 0 END AS is_short_session_user


FROM user_based_prep_avg
GROUP BY user_id

)

  
--Step 8: CTE for Normalisation

, features_norm AS(

SELECT *,
			CASE WHEN booking_rate = 0 THEN 1 ELSE 0 END AS did_not_book,

			(avg_bags_per_flight - MIN(avg_bags_per_flight) OVER()) / (MAX(avg_bags_per_flight) OVER() - MIN(avg_bags_per_flight) OVER ()) AS avg_bags_per_flight_norm,
      (avg_seats_per_flight - MIN(avg_seats_per_flight) OVER()) / (MAX(avg_seats_per_flight) OVER() - MIN(avg_seats_per_flight) OVER ()) AS avg_seats_per_flight_norm,
      (avg_flight_costs - MIN(avg_flight_costs) OVER()) / (MAX(avg_flight_costs) OVER() - MIN(avg_flight_costs) OVER ()) AS avg_flight_costs_norm,
      (avg_hotel_costs - MIN(avg_hotel_costs) OVER()) / (MAX(avg_hotel_costs) OVER() - MIN(avg_hotel_costs) OVER ()) AS avg_hotel_costs_norm


FROM user_based_final
JOIN user_based_prep_avg USING (user_id)

)

  
--Step 9: CTE for Scoring

, features_score AS(

SELECT *,

      CASE WHEN did_not_book = 1 THEN 1 ELSE 0 END AS score_browser,

  		CASE
  			WHEN did_not_book = 1 THEN 0 ELSE (1 - avg_seats_per_flight_norm) * 0.4 + is_less_clicker * 0.15 + weekdays_travel_quote * 0.3 + is_in_working_age * 0.15 END AS score_business,

  		CASE
  			WHEN did_not_book = 1 THEN 0 ELSE has_children * 0.4 + is_married * 0.1 + (1 - avg_seats_per_flight_norm) * 0.25 + (1 - avg_bags_per_flight_norm) * 0.25 END AS score_family,

  		CASE
  			WHEN did_not_book = 1 THEN 0 ELSE is_long_session_user * 0.2 + is_active_clicker * 0.2 + discount_quote * 0.6 END AS score_bargain_hunter,

  		CASE
  			WHEN is_frequent_flyer = 1 THEN 1 ELSE 0 END AS score_frequent_flyer,

  		CASE
  			WHEN is_new_customer = 1 THEN 1 ELSE 0 END AS score_new_customer,

  		CASE
  			WHEN did_not_book = 1 THEN 0 ELSE is_senior * 1 END AS score_senior


FROM features_norm

)

  
--Step 10: create a hirarchy (for users fitting more than one segment) and find highest scores per segment

, check_values AS (

SELECT user_id,
      CASE
      		WHEN score_browser = 1 THEN 'Browser'
          WHEN score_business >= greatest(score_family, score_bargain_hunter, score_frequent_flyer, score_new_customer, score_senior) THEN 'Business'
					WHEN score_family >= greatest(score_business, score_bargain_hunter, score_frequent_flyer, score_new_customer, score_senior) THEN 'Family'
          WHEN score_bargain_hunter >= greatest(score_family, score_business, score_frequent_flyer, score_new_customer, score_senior) THEN 'Bargain Hunter'
          WHEN score_frequent_flyer = 1 THEN 'Frequent Flyer'
					WHEN score_new_customer = 1 THEN 'New Customer'
  				WHEN score_senior = 1 THEN 'Senior'
          ELSE 'Other' END AS segment,

  		score_browser,
      score_business,
      score_family,
      score_bargain_hunter,
      score_new_customer,
      score_frequent_flyer,
      score_senior


FROM features_score

)


--Step 11: user-segements-perks

SELECT COUNT(*) users,
			 segment,
			 CASE
      	 WHEN segment = 'Family' THEN 'No cancellation fees'
         WHEN segment = 'Browser' THEN 'Free room upgrade with hotel'
         WHEN segment = 'Frequent Flyer' THEN 'Free checked bag'
         WHEN segment = 'New Customer' THEN 'One night free with flight'
         WHEN segment = 'Bargain Hunter' THEN 'Exclusive discounts'
         WHEN segment = 'Business' THEN 'Free hotel meal'
         WHEN segment = 'Senior' THEN 'Free pick-up from airport'
       END AS perk

  
FROM check_values
GROUP BY segment
