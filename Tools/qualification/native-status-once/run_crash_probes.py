"""Opt-in actual subprocess exits against fresh disposable SQL metadata only.

No app data, SDK, native permission/factory, pairing, keys or network operation.
Compile the exact journal source; explicitly bootstrap only NEW test databases.
"""
import argparse
import base64
from contextlib import closing
import hashlib
import json
import os
from pathlib import Path
import sqlite3
import subprocess
import uuid


def run(output: Path) -> None:
    root = Path(__file__).resolve().parents[3]
    source = root / "Sources/DJConnectCore/NativeStatusOnceDataJournal.swift"
    helper = Path(__file__).with_name("MetadataCrashProbe.swift")
    schema = root / "Tests/Fixtures/native-status-once-data-test-schema-v1.sql"
    output.mkdir(mode=0o700, exist_ok=False)
    for name in ("tmp", "module-cache"):
        (output / name).mkdir(mode=0o700)
    env = os.environ.copy()
    env["TMPDIR"] = str(output / "tmp")
    executable = output / "metadata-crash-probe"
    sdk = subprocess.check_output(["xcrun", "--sdk", "macosx", "--show-sdk-path"], text=True).strip()
    command = ["xcrun", "swiftc", "-parse-as-library", "-sdk", sdk,
               "-module-cache-path", str(output / "module-cache"), str(source), str(helper), "-o", str(executable)]
    compile_result = subprocess.run(command, env=env, capture_output=True, text=True)
    (output / "compile.log").write_text(compile_result.stdout + compile_result.stderr)
    (output / "compile.exit").write_text(str(compile_result.returncode) + "\n")
    compile_result.check_returncode()
    receipt = {"scope": "Actual process exits and fresh-process readback of SQL DATA; no native capability",
               "sources_sha256": {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
                                  for p in (source, helper, schema)}, "cases": []}
    for mode, expected_exit in (("before-reserve", 71), ("after-reserve", 72),
                                ("after-consume", 73), ("after-terminal", 74)):
        folder = output / mode
        folder.mkdir(mode=0o700)
        database = folder / "existing.sqlite3"
        descriptor = os.open(database, os.O_RDWR | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
        os.close(descriptor)
        # Only this explicit disposable TEST harness initializes the schema.
        ids = [str(uuid.uuid4()) for _ in range(6)]
        with closing(sqlite3.connect(database.as_uri() + "?mode=rw", uri=True)) as connection:
            connection.executescript(schema.read_text())
            connection.execute("INSERT INTO native_status_root VALUES(1,1,?,2)", (ids[0],))
            connection.commit()
        value = dict(database=str(database), store=ids[0], capacity=2, operation=ids[1],
                     decision=ids[2], presentation=ids[3], generation=ids[4], terminal=ids[5],
                     binding=base64.b64encode(bytes([7] * 32)).decode())
        inputs = folder / "synthetic-input.json"
        inputs.write_text(json.dumps(value, sort_keys=True) + "\n")
        crashed = subprocess.run([str(executable), mode, str(inputs)], env=env, capture_output=True, text=True)
        (folder / "original-exit.log").write_text(crashed.stdout + crashed.stderr)
        (folder / "original-exit.code").write_text(str(crashed.returncode) + "\n")
        assert crashed.returncode == expected_exit
        with closing(sqlite3.connect(database.as_uri() + "?mode=ro", uri=True)) as connection:
            rows = connection.execute("SELECT dispatch_consumed,terminal_consumed FROM native_status_operations").fetchall()
            roles = connection.execute("SELECT COUNT(*) FROM native_status_operation_ids").fetchone()[0]
        expected_rows = [] if mode == "before-reserve" else [(int(mode == "after-consume"), int(mode == "after-terminal"))]
        assert rows == expected_rows and roles == (0 if mode == "before-reserve" else 2)
        reopened = subprocess.run([str(executable), "reopen", str(inputs)], env=env, capture_output=True, text=True)
        (folder / "fresh-process-readback.log").write_text(reopened.stdout + reopened.stderr)
        (folder / "fresh-process-readback.exit").write_text(str(reopened.returncode) + "\n")
        reopened.check_returncode()
        actual = json.loads(reopened.stdout)
        assert actual["record_present"] == (mode != "before-reserve")
        expected_dispatch = ("missing-record" if mode == "before-reserve" else "already-recorded"
                             if mode == "after-consume" else "original-process-reservation-missing")
        expected_terminal = ("missing-record" if mode == "before-reserve" else "already-recorded"
                            if mode == "after-terminal" else "original-process-reservation-missing")
        assert actual["dispatch_result"] == expected_dispatch and actual["terminal_result"] == expected_terminal
        receipt["cases"].append(dict(mode=mode, actual_original_exit=crashed.returncode,
                                     independent_sqlite_rows=rows, independent_role_count=roles,
                                     fresh_process_actual_exit=reopened.returncode, fresh_process=actual))
    receipt["limits"] = ["No power-loss, full VFS fault or nonrollback/restore qualification.",
                         "No real native owner, SDK, fake-SDK dispatch authority or complete 20-vector claim.",
                         "Existing metadata may be inspected after restart; no process reservation is recreated."]
    (output / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print("Four actual subprocess exit/readback cases passed; SQL DATA only.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path, help="New disposable directory under the external qualification root")
    parser.add_argument("--disposable-test-only", action="store_true", required=True)
    arguments = parser.parse_args()
    run(arguments.output.resolve())
