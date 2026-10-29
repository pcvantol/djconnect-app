-- Explicit fresh DISPOSABLE TEST bootstrap. Never consumed by product source.
-- This local SQL metadata format is not the signed/native wire or a permission.
PRAGMA journal_mode=WAL;
PRAGMA foreign_keys=ON;
CREATE TABLE native_status_root (
    singleton INTEGER PRIMARY KEY CHECK(singleton=1),
    schema_version INTEGER NOT NULL CHECK(schema_version=1),
    store_id TEXT NOT NULL,
    capacity INTEGER NOT NULL CHECK(capacity>0)
);
CREATE TABLE native_status_operations (
    operation_id TEXT PRIMARY KEY,
    decision_id TEXT NOT NULL UNIQUE,
    presentation_id TEXT NOT NULL,
    presentation_generation TEXT NOT NULL,
    binding BLOB NOT NULL CHECK(length(binding)=32),
    terminal_operation_id TEXT NOT NULL UNIQUE,
    dispatch_consumed INTEGER NOT NULL CHECK(dispatch_consumed IN(0,1)),
    terminal_consumed INTEGER NOT NULL CHECK(terminal_consumed IN(0,1)),
    UNIQUE(presentation_id,presentation_generation)
);
CREATE TABLE native_status_operation_ids (
    id TEXT PRIMARY KEY,
    kind TEXT NOT NULL CHECK(kind IN('dispatch','terminal')),
    reservation_operation_id TEXT NOT NULL REFERENCES native_status_operations(operation_id),
    UNIQUE(reservation_operation_id,kind)
);
