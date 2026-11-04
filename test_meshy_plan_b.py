import importlib.util
import io
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('meshy_plan_b', Path(__file__).with_name('meshy_plan_b.py'))
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

class BudgetTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.base = Path(self.tmp.name)
        self.old_base, self.old_db = mod.BASE, mod.DB
        mod.BASE, mod.DB = self.base, self.base / 'ledger.sqlite3'
        self.image = self.base / 'input.png'
        self.image.write_bytes(b'test image')

    def tearDown(self):
        mod.BASE, mod.DB = self.old_base, self.old_db
        self.tmp.cleanup()

    def test_reservation_and_attempt_limit(self):
        with patch.object(mod.meshy, 'request', return_value={'result':'fake-id'}), redirect_stdout(io.StringIO()):
            for _ in range(3): mod.submit('pilot_tree', self.image)
            with self.assertRaisesRegex(RuntimeError, 'attempts=3'):
                mod.submit('pilot_tree', self.image)
        rows = mod.connect().execute('SELECT reserved,actual,status FROM tasks').fetchall()
        self.assertEqual(rows, [(30,None,'PENDING')]*3)

    def test_ambiguous_submission_blocks_all_future_paid_tasks(self):
        with patch.object(mod.meshy, 'request', side_effect=RuntimeError('network')):
            with self.assertRaises(RuntimeError): mod.submit('pilot_tree', self.image)
        with patch.object(mod.meshy, 'request') as request:
            with self.assertRaisesRegex(RuntimeError, 'unresolved=1'): mod.submit('pilot_slab', self.image)
            request.assert_not_called()
        self.assertEqual(mod.connect().execute('SELECT status,reserved FROM tasks').fetchone(),('UNCERTAIN',30))

    def test_non_pilot_requires_review(self):
        with self.assertRaisesRegex(RuntimeError, 'blocked'):
            mod.submit('fern', self.image)
        with self.assertRaises(ValueError): mod.submit('../unsafe', self.image)

    def test_budget_cap(self):
        with patch.object(mod.meshy, 'request', return_value={'result':'fake-id'}), redirect_stdout(io.StringIO()):
            for i in range(26):
                # Open the gate to exercise the independent project budget limit.
                (self.base/'pilot_review.json').write_text('{"all_passed":true}',encoding='utf-8')
                mod.submit('item_'+str(i), self.image)
            with self.assertRaisesRegex(RuntimeError,'committed=780'):
                mod.submit('item_over', self.image)

    def test_pending_zero_actual_does_not_release_reservation(self):
        with patch.object(mod.meshy, 'request', return_value={'result':'fake-id'}), redirect_stdout(io.StringIO()):
            (self.base/'pilot_review.json').write_text('{"all_passed":true}',encoding='utf-8')
            for i in range(26): mod.submit('item_'+str(i), self.image)
            db = mod.connect()
            db.execute('UPDATE tasks SET actual=0')
            db.commit()
            with self.assertRaisesRegex(RuntimeError,'committed=780'):
                mod.submit('item_over', self.image)

if __name__ == '__main__': unittest.main()
