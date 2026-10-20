import unittest

from ipl_db.project import ground_category, project_next_season, season_draws


class ProjectionTests(unittest.TestCase):
    def test_ground_bands(self):
        self.assertEqual(ground_category(185), "high_scoring")
        self.assertEqual(ground_category(170), "high_scoring")
        self.assertEqual(ground_category(160), "mid_scoring")
        self.assertEqual(ground_category(155), "mid_scoring")
        self.assertEqual(ground_category(154.9), "low_scoring")
        self.assertIsNone(ground_category(None))

    def test_season_size(self):
        self.assertEqual(season_draws(10, 4), 3)
        self.assertEqual(season_draws(1, 5), 1)

    def test_bootstrap_is_seeded(self):
        scores = [0, 4, 12, 30]
        first = project_next_season(scores, 3, seed=99, simulations=400)
        second = project_next_season(scores, 3, seed=99, simulations=400)
        other = project_next_season(scores, 3, seed=100, simulations=400)
        self.assertEqual(first, second)
        self.assertGreaterEqual(first[0], 0)
        self.assertLessEqual(first[0], 1)
        self.assertNotEqual(first, other)

    def test_certain_and_empty_scores(self):
        probability, expected = project_next_season([8], 2, seed=1, simulations=50)
        self.assertEqual(probability, 1)
        self.assertEqual(expected, 16)
        probability, expected = project_next_season([0], 2, seed=1, simulations=50)
        self.assertEqual(probability, 0)
        self.assertEqual(expected, 0)


if __name__ == "__main__":
    unittest.main()