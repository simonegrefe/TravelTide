# 🌍 TravelTide – Customer Segmentation & Perk Recommendation

**TravelTide** is an e-booking startup, where customers have access to the largest travel inventory in the e-booking space. Its mission is to design and execute a **personalized rewards program** that keeps customers returning to the TravelTide platform.


## 👀 Overview

This SQL script uses a multi-stage chain of **Common Table Expressions (CTEs)** to transform raw session, user, flight, and hotel data into structured user segments. The query enables identification of key customer types.

The primary goal of this project is to enhance the understanding of customer behaviors and preferences within the TravelTide platform by segmenting users based on their interactions and subsequently assigning personalized perks to improve engagement and satisfaction. 

The Tableau visualizations help to provide actionable recommendations for the TravelTide personalized rewards program.



## 🔑 Features

- **Session Filtering**: Focus on customers active after *January 4th, 2023* and with high engagement (> 7 sessions).
- **Data Cleaning**: Clean inconsistent datetime fields.
- **Behavioral Profiling**: Build session-based and user-based aggregations to calculate browsing patterns, travel activities, and key booking stats per user.
- **Segmentation**: Score users across multiple segment categories.
- **Normalization & Scoring**: Apply normalization for select features and compute weighted segment scores.
- **Hierarchy Resolution**: Assign each user to the highest-priority segment based on computed scores.
- **Perk Assignment**: Link user segments to specific marketing perks.
- **Recommendations**: Visualize insights to provide actionable recommendations for the TravelTide personalized rewards program 

  
## 🛠️ Tools used

- **PostgreSQL**: Used for data extraction, transformation, and aggregation to create customer segments.
- **Tableau**: Utilized for visualizing the segmentation results and analyzing perk distribution across customer groups.


## 📝 CTE Step by Step Process

1. **session_2023**: Filters sessions by date on customers active after January 4th, 2023.  
2. **over_7_sessions**: Keeps highly active users (> 7 sessions).  
3. **sessions_2023_cleaned, users_cleaned, flights_cleaned & hotels_cleaned**: Clean datetime fields in all tables for reliable calculations.  
4. **session_based_final**: Calculates session metrics (costs, trip status, booking type, travel days, session time, age, etc.).  
5. **user_based_prep_total**: Aggregates user totals for browsing and travel behavior, costs, discounts and user information to prepare and compute averages and ratios per user.
6. **user_based_prep_avg:** Aggregates user averages and ratios (e.g. average page clicks, average minutes per session, booking rate, discount quota, etc.). 
7. **user_based_final**: Identifies exceptional browsing/travel behaviors with percentile logic.  
8. **features_norm**: Normalizes feature columns for downstream scoring for average costs and number of flights and bags.  
9. **features_score**: Calculates scores for each segment type.  
10. **check_values**: Resolves segment hierarchy and picks top segment per user.  
11. **user_segments_perks**: Final aggregation and output of segment size and marketing perks.  



## 🧩 Segment Definitions

| Segment            | Criteria (scoring logic)                   | Perk                          |
|--------------------|--------------------------------------------|-------------------------------|
| **Browser**        | high online activity, no booking           | free room upgrade             |
| **Business**       | consistent, short weekday travel           | free hotel meal               |
| **Family**         | high bookings, children                    | no cancellation fee           |
| **Bargain Hunter** | high online activity, seeks deals          | exclusive discounts           |
| **Frequent Flyer** | top 10% of flight bookers                  | free checked bag              |
| **New Customer**   | recent sign-up                             | one night free with flight    |
| **Senior**         | age over 67                                | free airport pick-up          |

---






