"""Names, venues, and the rules used to put a delivery in context."""

SOURCE_URL = "https://cricsheet.org/downloads/ipl_json.zip"
SOURCE_PAGE = "https://cricsheet.org/"
SOURCE_LICENSE = "Open Data Commons Attribution License (ODC-By)"

# Same franchise after a rename or a one-letter spelling difference.
# Deccan Chargers and Sunrisers Hyderabad stay separate: the franchise
# was replaced, not renamed. Sardar Patel Stadium and Narendra Modi
# Stadium stay separate: the old ground was demolished.
FRANCHISE_NAME = {
    "Delhi Daredevils": "Delhi Capitals",
    "Kings XI Punjab": "Punjab Kings",
    "Royal Challengers Bangalore": "Royal Challengers Bengaluru",
    "Rising Pune Supergiants": "Rising Pune Supergiant",
}

# Raw Cricsheet venue string -> one ground. Suffix-only variants and
# renames of the same pitch are folded together.
VENUE_CANONICAL = {
    "Arun Jaitley Stadium": "Arun Jaitley Stadium, Delhi",
    "Arun Jaitley Stadium, Delhi": "Arun Jaitley Stadium, Delhi",
    "Feroz Shah Kotla": "Arun Jaitley Stadium, Delhi",
    "Barabati Stadium": "Barabati Stadium, Cuttack",
    "Barsapara Cricket Stadium, Guwahati": "Barsapara Cricket Stadium, Guwahati",
    "Bharat Ratna Shri Atal Bihari Vajpayee Ekana Cricket Stadium, Lucknow": (
        "Bharat Ratna Shri Atal Bihari Vajpayee Ekana Cricket Stadium, Lucknow"
    ),
    "Brabourne Stadium": "Brabourne Stadium, Mumbai",
    "Brabourne Stadium, Mumbai": "Brabourne Stadium, Mumbai",
    "Buffalo Park": "Buffalo Park, East London",
    "De Beers Diamond Oval": "De Beers Diamond Oval, Kimberley",
    "Dr DY Patil Sports Academy": "Dr DY Patil Sports Academy, Mumbai",
    "Dr DY Patil Sports Academy, Mumbai": "Dr DY Patil Sports Academy, Mumbai",
    "Dr. Y.S. Rajasekhara Reddy ACA-VDCA Cricket Stadium": (
        "Dr. Y.S. Rajasekhara Reddy ACA-VDCA Cricket Stadium, Visakhapatnam"
    ),
    "Dr. Y.S. Rajasekhara Reddy ACA-VDCA Cricket Stadium, Visakhapatnam": (
        "Dr. Y.S. Rajasekhara Reddy ACA-VDCA Cricket Stadium, Visakhapatnam"
    ),
    "Dubai International Cricket Stadium": "Dubai International Cricket Stadium",
    "Eden Gardens": "Eden Gardens, Kolkata",
    "Eden Gardens, Kolkata": "Eden Gardens, Kolkata",
    "Green Park": "Green Park, Kanpur",
    "Himachal Pradesh Cricket Association Stadium": (
        "Himachal Pradesh Cricket Association Stadium, Dharamsala"
    ),
    "Himachal Pradesh Cricket Association Stadium, Dharamsala": (
        "Himachal Pradesh Cricket Association Stadium, Dharamsala"
    ),
    "Holkar Cricket Stadium": "Holkar Cricket Stadium, Indore",
    "JSCA International Stadium Complex": "JSCA International Stadium Complex, Ranchi",
    "Kingsmead": "Kingsmead, Durban",
    "M Chinnaswamy Stadium": "M Chinnaswamy Stadium, Bengaluru",
    "M Chinnaswamy Stadium, Bengaluru": "M Chinnaswamy Stadium, Bengaluru",
    "M.Chinnaswamy Stadium": "M Chinnaswamy Stadium, Bengaluru",
    "MA Chidambaram Stadium": "MA Chidambaram Stadium, Chennai",
    "MA Chidambaram Stadium, Chepauk": "MA Chidambaram Stadium, Chennai",
    "MA Chidambaram Stadium, Chepauk, Chennai": "MA Chidambaram Stadium, Chennai",
    "Maharaja Yadavindra Singh International Cricket Stadium, Mullanpur": (
        "Maharaja Yadavindra Singh International Cricket Stadium, New Chandigarh"
    ),
    "Maharaja Yadavindra Singh International Cricket Stadium, New Chandigarh": (
        "Maharaja Yadavindra Singh International Cricket Stadium, New Chandigarh"
    ),
    "Maharashtra Cricket Association Stadium": "Maharashtra Cricket Association Stadium, Pune",
    "Maharashtra Cricket Association Stadium, Pune": (
        "Maharashtra Cricket Association Stadium, Pune"
    ),
    "Subrata Roy Sahara Stadium": "Maharashtra Cricket Association Stadium, Pune",
    "Narendra Modi Stadium, Ahmedabad": "Narendra Modi Stadium, Ahmedabad",
    "Nehru Stadium": "Nehru Stadium, Kochi",
    "New Wanderers Stadium": "New Wanderers Stadium, Johannesburg",
    "Newlands": "Newlands, Cape Town",
    "OUTsurance Oval": "OUTsurance Oval, Bloemfontein",
    "Punjab Cricket Association IS Bindra Stadium": (
        "Punjab Cricket Association IS Bindra Stadium, Mohali"
    ),
    "Punjab Cricket Association IS Bindra Stadium, Mohali": (
        "Punjab Cricket Association IS Bindra Stadium, Mohali"
    ),
    "Punjab Cricket Association IS Bindra Stadium, Mohali, Chandigarh": (
        "Punjab Cricket Association IS Bindra Stadium, Mohali"
    ),
    "Punjab Cricket Association Stadium, Mohali": (
        "Punjab Cricket Association IS Bindra Stadium, Mohali"
    ),
    "Rajiv Gandhi International Stadium": "Rajiv Gandhi International Stadium, Hyderabad",
    "Rajiv Gandhi International Stadium, Uppal": "Rajiv Gandhi International Stadium, Hyderabad",
    "Rajiv Gandhi International Stadium, Uppal, Hyderabad": (
        "Rajiv Gandhi International Stadium, Hyderabad"
    ),
    "Sardar Patel Stadium, Motera": "Sardar Patel Stadium, Motera",
    "Saurashtra Cricket Association Stadium": "Saurashtra Cricket Association Stadium, Rajkot",
    "Sawai Mansingh Stadium": "Sawai Mansingh Stadium, Jaipur",
    "Sawai Mansingh Stadium, Jaipur": "Sawai Mansingh Stadium, Jaipur",
    "Shaheed Veer Narayan Singh International Stadium": (
        "Shaheed Veer Narayan Singh International Stadium, Raipur"
    ),
    "Shaheed Veer Narayan Singh International Stadium, Raipur": (
        "Shaheed Veer Narayan Singh International Stadium, Raipur"
    ),
    "Sharjah Cricket Stadium": "Sharjah Cricket Stadium",
    "Sheikh Zayed Stadium": "Zayed Cricket Stadium, Abu Dhabi",
    "St George's Park": "St George's Park, Gqeberha",
    "SuperSport Park": "SuperSport Park, Centurion",
    "Vidarbha Cricket Association Stadium, Jamtha": (
        "Vidarbha Cricket Association Stadium, Nagpur"
    ),
    "Wankhede Stadium": "Wankhede Stadium, Mumbai",
    "Wankhede Stadium, Mumbai": "Wankhede Stadium, Mumbai",
    "Zayed Cricket Stadium, Abu Dhabi": "Zayed Cricket Stadium, Abu Dhabi",
}

VENUE_CITY = {
    "Arun Jaitley Stadium, Delhi": "Delhi",
    "Barabati Stadium, Cuttack": "Cuttack",
    "Barsapara Cricket Stadium, Guwahati": "Guwahati",
    "Bharat Ratna Shri Atal Bihari Vajpayee Ekana Cricket Stadium, Lucknow": "Lucknow",
    "Brabourne Stadium, Mumbai": "Mumbai",
    "Buffalo Park, East London": "East London",
    "De Beers Diamond Oval, Kimberley": "Kimberley",
    "Dr DY Patil Sports Academy, Mumbai": "Mumbai",
    "Dr. Y.S. Rajasekhara Reddy ACA-VDCA Cricket Stadium, Visakhapatnam": "Visakhapatnam",
    "Dubai International Cricket Stadium": "Dubai",
    "Eden Gardens, Kolkata": "Kolkata",
    "Green Park, Kanpur": "Kanpur",
    "Himachal Pradesh Cricket Association Stadium, Dharamsala": "Dharamsala",
    "Holkar Cricket Stadium, Indore": "Indore",
    "JSCA International Stadium Complex, Ranchi": "Ranchi",
    "Kingsmead, Durban": "Durban",
    "M Chinnaswamy Stadium, Bengaluru": "Bengaluru",
    "MA Chidambaram Stadium, Chennai": "Chennai",
    "Maharaja Yadavindra Singh International Cricket Stadium, New Chandigarh": "New Chandigarh",
    "Maharashtra Cricket Association Stadium, Pune": "Pune",
    "Narendra Modi Stadium, Ahmedabad": "Ahmedabad",
    "Nehru Stadium, Kochi": "Kochi",
    "New Wanderers Stadium, Johannesburg": "Johannesburg",
    "Newlands, Cape Town": "Cape Town",
    "OUTsurance Oval, Bloemfontein": "Bloemfontein",
    "Punjab Cricket Association IS Bindra Stadium, Mohali": "Mohali",
    "Rajiv Gandhi International Stadium, Hyderabad": "Hyderabad",
    "Sardar Patel Stadium, Motera": "Ahmedabad",
    "Saurashtra Cricket Association Stadium, Rajkot": "Rajkot",
    "Sawai Mansingh Stadium, Jaipur": "Jaipur",
    "Shaheed Veer Narayan Singh International Stadium, Raipur": "Raipur",
    "Sharjah Cricket Stadium": "Sharjah",
    "St George's Park, Gqeberha": "Gqeberha",
    "SuperSport Park, Centurion": "Centurion",
    "Vidarbha Cricket Association Stadium, Nagpur": "Nagpur",
    "Wankhede Stadium, Mumbai": "Mumbai",
    "Zayed Cricket Stadium, Abu Dhabi": "Abu Dhabi",
}

# Dismissals credited to the bowler. Run outs, retired hurt/out, and
# obstructing the field are wickets on the ball but not bowler wickets.
BOWLER_WICKET_KINDS = frozenset(
    {"bowled", "caught", "caught and bowled", "lbw", "stumped", "hit wicket"}
)

# Retired hurt brings a new batter in without a wicket falling.
NON_WICKET_KINDS = frozenset({"retired hurt"})

METRICS = (
    (
        1,
        "Phase of play",
        "Powerplay, middle, or death, scaled to the overs allotted to that "
        "innings. A full T20 is overs 1-6 / 7-15 / 16-20. Super overs are "
        "their own phase.",
    ),
    (
        2,
        "Innings role and required rate",
        "Setting a total versus chasing. While chasing, each ball carries "
        "the required run rate at the start of the ball, in bands under 6, "
        "6 to 9, 9 to 12, and 12 or more.",
    ),
    (
        3,
        "Wickets in hand",
        "How many wickets the batting side still has at the start of the "
        "ball: 8-10, 5-7, 3-4, or 0-2. Retired hurt does not reduce the count.",
    ),
    (
        4,
        "Batting position",
        "Order of appearance in the innings. The striker on the first ball "
        "is 1 and the non-striker is 2. Later batters take the next number.",
    ),
    (
        5,
        "Venue",
        "Canonical ground, so renamed and suffixed spellings of the same "
        "pitch sit together. First-innings totals and chase results are "
        "aggregated per ground.",
    ),
    (
        6,
        "Toss",
        "Whether the toss winner batted or fielded, and whether that side "
        "won the match in regulation.",
    ),
    (
        7,
        "Opposition",
        "Franchise head-to-head results, and batter and bowler output "
        "against each opposing franchise.",
    ),
    (
        8,
        "Season",
        "IPL edition year. Split seasons are stored as 2008, 2010, and 2020 "
        "for the 2007/08, 2009/10, and 2020/21 Cricsheet labels.",
    ),
)
