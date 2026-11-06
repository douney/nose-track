CREATE TABLE tracks (
  id TEXT PRIMARY KEY NOT NULL,
  name TEXT NOT NULL CHECK (length(trim(name)) > 0),
  description TEXT,
  dog_name TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER,
  tracer_file_name TEXT,
  tracer_started_at INTEGER,
  tracer_ended_at INTEGER,
  tracer_status TEXT CHECK (tracer_status IN ('recording', 'interrupted', 'finished')),
  tracer_point_count INTEGER NOT NULL DEFAULT 0 CHECK (tracer_point_count >= 0),
  tracer_start_latitude REAL CHECK (tracer_start_latitude BETWEEN -90 AND 90),
  tracer_start_longitude REAL CHECK (tracer_start_longitude BETWEEN -180 AND 180),
  dog_file_name TEXT,
  dog_started_at INTEGER,
  dog_ended_at INTEGER,
  dog_status TEXT CHECK (dog_status IN ('recording', 'interrupted', 'finished')),
  dog_point_count INTEGER NOT NULL DEFAULT 0 CHECK (dog_point_count >= 0),
  dog_start_latitude REAL CHECK (dog_start_latitude BETWEEN -90 AND 90),
  dog_start_longitude REAL CHECK (dog_start_longitude BETWEEN -180 AND 180)
);
CREATE INDEX tracks_created_at ON tracks(created_at DESC);
PRAGMA user_version = 1;
