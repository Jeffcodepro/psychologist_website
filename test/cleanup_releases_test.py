import importlib.util
import tempfile
import unittest
from unittest.mock import patch
from pathlib import Path

MODULE = Path(__file__).resolve().parents[1] / "deploy/swarm/cleanup-releases.py"
spec = importlib.util.spec_from_file_location("cleanup_releases", MODULE)
cleanup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cleanup)

class CleanupTest(unittest.TestCase):
    def test_plan_only_targets_old_releases_and_keeps_backups_unknown_files_and_symlinks(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            for version in ("1.2.5", "1.2.7", "1.2.8", "1.3.0"):
                (root / "releases" / version).mkdir(parents=True)
                (root / f"rosemarydias-source-{version}.tar.gz").touch()
            (root / "backups").mkdir()
            (root / "backups/database.dump").touch()
            (root / "releases/1.0.0").symlink_to(root / "backups", target_is_directory=True)
            operations, keep = cleanup.plan(root, "1.2.8", "1.2.7", [], [])
            self.assertEqual({"1.2.8", "1.2.7"}, keep)
            self.assertEqual([("directory", str(root / "releases/1.2.5")), ("archive", str(root / "rosemarydias-source-1.2.5.tar.gz"))], operations)
            self.assertTrue((root / "releases/1.2.5").exists())
            self.assertTrue((root / "backups/database.dump").exists())

    def test_containers_of_other_services_or_running_versions_are_protected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve(); (root / "releases").mkdir()
            def container(tag, service, running):
                return {"Id": tag, "Config": {"Image": "psychologist-website:" + tag, "Labels": {"com.docker.swarm.service.name": service}}, "State": {"Running": running}}
            containers = [container("1.2.4", "another_web", False), container("1.2.5", "psychologist-app_web", True), container("1.2.6", "psychologist-release_migrate", False)]
            images = [{"Repository": "psychologist-website", "Tag": tag} for tag in ["1.2.4", "1.2.5", "1.2.6", "1.2.7", "1.2.8"]]
            operations, keep = cleanup.plan(root, "1.2.8", "1.2.7", containers, images)
            self.assertIn("1.2.4", keep); self.assertIn("1.2.5", keep)
            self.assertEqual([("container", "1.2.6"), ("image", "psychologist-website:1.2.6")], operations)

    def test_apply_aborts_if_image_inventory_changes_after_preview(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            for tag in ("1.2.7", "1.2.8"):
                (root / "releases" / tag).mkdir(parents=True)
            web = {"Config": {"Image": "psychologist-website:1.2.8", "Labels": {"com.docker.swarm.service.name": "psychologist-app_web"}}, "State": {"Running": True, "Health": {"Status": "healthy"}}}
            old_image = {"Repository": "psychologist-website", "Tag": "1.2.5"}
            args = ["cleanup", "--root", str(root), "--current", "1.2.8", "--rollback", "1.2.7", "--apply"]
            with patch("sys.argv", args), patch.object(cleanup, "inventory", side_effect=[([web], []), ([web], [old_image])]), patch.object(cleanup, "docker") as docker, patch("builtins.print"):
                with self.assertRaisesRegex(ValueError, "estado mudou"):
                    cleanup.main()
                self.assertTrue(all(call.args[:2] == ("image", "inspect") for call in docker.call_args_list))

    def test_unhealthy_web_or_invalid_versions_cannot_be_used_for_cleanup(self):
        with self.assertRaises(ValueError): cleanup.check_current([], "1.2.8")
        for value in ("../backups", "latest", "1.2.8;rm", "v1.2.8"):
            with self.assertRaises(ValueError): cleanup.version(value)

if __name__ == "__main__": unittest.main()
