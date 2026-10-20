import unittest

from ipl_db.constants import VENUE_CANONICAL
from ipl_db.context import (
    canonical_venue,
    franchise_name,
    phase_bounds,
    phase_of,
    rrr_band,
    season_year,
    wickets_band,
)

RAW_VENUES = [
    "Arun Jaitley Stadium",
    "Arun Jaitley Stadium, Delhi",
    "Barabati Stadium",
    "Barsapara Cricket Stadium, Guwahati",
    "Bharat Ratna Shri Atal Bihari Vajpayee Ekana Cricket Stadium, Lucknow",
    "Brabourne Stadium",
    "Brabourne Stadium, Mumbai",
    "Buffalo Park",
    "De Beers Diamond Oval",
    "Dr DY Patil Sports Academy",
    "Dr DY Patil Sports Academy, Mumbai",
    "Dr. Y.S. Rajasekhara Reddy ACA-VDCA Cricket Stadium",
    "Dr. Y.S. Rajasekhara Reddy ACA-VDCA Cricket Stadium, Visakhapatnam",
    "Dubai International Cricket Stadium",
    "Eden Gardens",
    "Eden Gardens, Kolkata",
    "Feroz Shah Kotla",
    "Green Park",
    "Himachal Pradesh Cricket Association Stadium",
    "Himachal Pradesh Cricket Association Stadium, Dharamsala",
    "Holkar Cricket Stadium",
    "JSCA International Stadium Complex",
    "Kingsmead",
    "M Chinnaswamy Stadium",
    "M Chinnaswamy Stadium, Bengaluru",
    "M.Chinnaswamy Stadium",
    "MA Chidambaram Stadium",
    "MA Chidambaram Stadium, Chepauk",
    "MA Chidambaram Stadium, Chepauk, Chennai",
    "Maharaja Yadavindra Singh International Cricket Stadium, Mullanpur",
    "Maharaja Yadavindra Singh International Cricket Stadium, New Chandigarh",
    "Maharashtra Cricket Association Stadium",
    "Maharashtra Cricket Association Stadium, Pune",
    "Narendra Modi Stadium, Ahmedabad",
    "Nehru Stadium",
    "New Wanderers Stadium",
    "Newlands",
    "OUTsurance Oval",
    "Punjab Cricket Association IS Bindra Stadium",
    "Punjab Cricket Association IS Bindra Stadium, Mohali",
    "Punjab Cricket Association IS Bindra Stadium, Mohali, Chandigarh",
    "Punjab Cricket Association Stadium, Mohali",
    "Rajiv Gandhi International Stadium",
    "Rajiv Gandhi International Stadium, Uppal",
    "Rajiv Gandhi International Stadium, Uppal, Hyderabad",
    "Sardar Patel Stadium, Motera",
    "Saurashtra Cricket Association Stadium",
    "Sawai Mansingh Stadium",
    "Sawai Mansingh Stadium, Jaipur",
    "Shaheed Veer Narayan Singh International Stadium",
    "Shaheed Veer Narayan Singh International Stadium, Raipur",
    "Sharjah Cricket Stadium",
    "Sheikh Zayed Stadium",
    "St George's Park",
    "Subrata Roy Sahara Stadium",
    "SuperSport Park",
    "Vidarbha Cricket Association Stadium, Jamtha",
    "Wankhede Stadium",
    "Wankhede Stadium, Mumbai",
    "Zayed Cricket Stadium, Abu Dhabi",
]


class ContextTests(unittest.TestCase):
    def test_full_t20_phases(self):
        self.assertEqual(phase_bounds(20), (6, 16))
        self.assertEqual(phase_of(1, 20, False), "powerplay")
        self.assertEqual(phase_of(6, 20, False), "powerplay")
        self.assertEqual(phase_of(7, 20, False), "middle")
        self.assertEqual(phase_of(15, 20, False), "middle")
        self.assertEqual(phase_of(16, 20, False), "death")
        self.assertEqual(phase_of(20, 20, False), "death")

    def test_shortened_and_super_over(self):
        powerplay, death_from = phase_bounds(14)
        self.assertEqual(powerplay, 4)
        self.assertGreater(death_from, powerplay)
        self.assertEqual(phase_of(1, 1, True), "super_over")

    def test_required_rate_and_wickets_bands(self):
        self.assertEqual(rrr_band(None, False, 120), "setting")
        self.assertEqual(rrr_band(5.9, True, 12), "under_6")
        self.assertEqual(rrr_band(8.9, True, 12), "6_to_9")
        self.assertEqual(rrr_band(11.9, True, 6), "9_to_12")
        self.assertEqual(rrr_band(12, True, 6), "12_plus")
        self.assertEqual(rrr_band(15, True, 0), "no_balls_left")
        self.assertEqual(wickets_band(10), "8_to_10")
        self.assertEqual(wickets_band(5), "5_to_7")
        self.assertEqual(wickets_band(3), "3_to_4")
        self.assertEqual(wickets_band(2), "0_to_2")

    def test_season_and_franchise(self):
        self.assertEqual(season_year("2007/08"), 2008)
        self.assertEqual(season_year("2009/10"), 2010)
        self.assertEqual(season_year("2020/21"), 2020)
        self.assertEqual(season_year("2026"), 2026)
        self.assertEqual(franchise_name("Delhi Daredevils"), "Delhi Capitals")
        self.assertEqual(franchise_name("Kings XI Punjab"), "Punjab Kings")
        self.assertEqual(franchise_name("Rising Pune Supergiants"), "Rising Pune Supergiant")
        self.assertEqual(franchise_name("Deccan Chargers"), "Deccan Chargers")

    def test_every_known_venue_is_mapped(self):
        self.assertEqual(len(RAW_VENUES), 60)
        self.assertEqual(set(VENUE_CANONICAL), set(RAW_VENUES))
        self.assertEqual(canonical_venue("Feroz Shah Kotla"), "Arun Jaitley Stadium, Delhi")
        self.assertEqual(
            canonical_venue("M.Chinnaswamy Stadium"),
            canonical_venue("M Chinnaswamy Stadium, Bengaluru"),
        )
        self.assertNotEqual(
            canonical_venue("Sardar Patel Stadium, Motera"),
            canonical_venue("Narendra Modi Stadium, Ahmedabad"),
        )


if __name__ == "__main__":
    unittest.main()
