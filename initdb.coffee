config = require './config'
sqlite3 = require 'sqlite3'
db = new sqlite3.Database './nco.db'

db.exec '''
  PRAGMA foreign_keys = ON;
  BEGIN;

  CREATE TABLE IF NOT EXISTS User(
    uid       INTEGER PRIMARY KEY,
    name      TEXT NOT NULL,
    email     TEXT UNIQUE NOT NULL,
    acl       INTEGER,
    pass2     TEXT,
    trustee   INTEGER,
    bio       TEXT,
    void      INTEGER,

    FOREIGN KEY(trustee) REFERENCES User(uid)
  );
  INSERT OR IGNORE INTO User (name, email, acl, pass2, trustee, bio, void)
    VALUES ('admin', '723.nco@gmail.com', 65535,
    '$2a$10$exjrKhtZvqR7UUA.In1A/.TjxXXBQ/KTduOREYvOzS1WLp/DtHuMy', 1, '', NULL);

  CREATE TABLE IF NOT EXISTS Person(
    pid       INTEGER PRIMARY KEY,
    name      TEXT NOT NULL,
    grouping  INTEGER,
    void      INTEGER,

    FOREIGN KEY(grouping) REFERENCES Grouping(gid)
  );

  CREATE TABLE IF NOT EXISTS Grouping(
    gid       INTEGER PRIMARY KEY,
    name      TEXT NOT NULL,
    colour    TEXT NOT NULL
  );

  CREATE TABLE IF NOT EXISTS Report(
    rid       INTEGER PRIMARY KEY,
    date      INTEGER NOT NULL,
    type      TEXT NOT NULL,
    body      TEXT,
    author    INTEGER,

    FOREIGN KEY(type) REFERENCES ReportType(type),
    FOREIGN KEY(author) REFERENCES User(uid)
  );

  CREATE TABLE IF NOT EXISTS ReportType(
    type      TEXT PRIMARY KEY
  );
  INSERT OR IGNORE INTO ReportType (type) VALUES ('SeriousConcern'),
    ('MinorConcern'), ('Praise'), ('Award'), ('Event');

  CREATE TABLE IF NOT EXISTS ReportSubject(
    sid       INTEGER PRIMARY KEY,
    report    INTEGER NOT NULL,
    person    INTEGER NOT NULL,
    score     INTEGER,

    FOREIGN KEY(report) REFERENCES Report(rid),
    FOREIGN KEY(person) REFERENCES Person(pid)
  );
  
  COMMIT;
''', (e) ->
  if e
    console.error e
  else
    console.log 'done'