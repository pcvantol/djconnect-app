"""Exercise the actual Apple workflow manifest selectors with both owners."""
import json
import re
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WORKFLOWS = [
    'apple-secure-distribution-relay.yml',
    'apple-iphone-secure-distribution-relay.yml',
    'apple-ipad-secure-distribution-relay.yml',
    'apple-post-deployment-smoke.yml',
    'apple-iphone-post-deployment-smoke.yml',
    'apple-ipad-post-deployment-smoke.yml',
]


class AppleRepositoryManifestIdentityTests(unittest.TestCase):
    def test_only_current_repository_and_exact_source_match(self):
        source = 'a' * 40
        old = 'pcvantol/djconnect-app'
        new = 'djconnect-music-dj/djconnect-app'
        manifest = {'repositories': [
            {'repository': old, 'source_sha': source, 'version': '4.0.0'},
            {'repository': new, 'source_sha': 'b' * 40, 'version': '4.0.0'},
        ]}
        for name in WORKFLOWS:
            with self.subTest(workflow=name):
                text = (ROOT / '.github/workflows' / name).read_text()
                self.assertIn('--arg repo "$GITHUB_REPOSITORY"', text)
                expressions = re.findall(r"'((?:\.repositories\[\]).*?select\(\.repository == \$repo.*?)(?:'\s+\"\$manifest\")", text)
                self.assertEqual(len(expressions), 1)
                expression = expressions[0]
                def select(repository, sha):
                    return subprocess.run(
                        ['jq', '-c', '--arg', 'repo', repository, '--arg', 'sha', sha, expression],
                        input=json.dumps(manifest), text=True, capture_output=True, check=True,
                    ).stdout.strip()
                self.assertTrue(select(old, source))
                self.assertFalse(select(new, source))
                self.assertTrue(select(new, 'b' * 40))
                self.assertFalse(select('other/djconnect-app', source))


if __name__ == '__main__':
    unittest.main()
