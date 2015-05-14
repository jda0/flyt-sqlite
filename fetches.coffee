module.exports = fetches = {}

fetches.feed = '''
  SELECT Report.rid AS rid,
         Report.date AS date,
         Report.type AS type, 
         ReportSubject.person AS pid,
         Person.name AS person,
         Person.grouping AS gid,
         Grouping.name AS grouping, 
         ReportSubject.score AS score,
         Report.body AS body, 
         Report.author AS uid,
         User.name AS author

  FROM Report

  JOIN ReportSubject
  ON Report.rid=ReportSubject.report

  JOIN Person
  ON ReportSubject.person=Person.pid

  LEFT OUTER JOIN Grouping
  ON Person.grouping=Grouping.gid

  LEFT OUTER JOIN User
  ON Report.author=User.uid

  WHERE Report.date < $date
  ORDER BY date DESC
  LIMIT 50
'''

fetches.person = '''
  SELECT Report.rid AS rid,
         Report.date AS date,
         Report.type AS type, 
         ReportSubject.person AS pid,
         Person.name AS person,
         Person.grouping AS gid,
         Grouping.name AS grouping, 
         ReportSubject.score AS score,
         Report.body AS body, 
         Report.author AS uid,
         User.name AS author

  FROM Report

  JOIN ReportSubject
  ON Report.rid=ReportSubject.report

  JOIN Person
  ON ReportSubject.person=Person.pid

  LEFT OUTER JOIN Grouping
  ON Person.grouping=Grouping.gid

  LEFT OUTER JOIN User
  ON Report.author=User.uid

  WHERE Report.date < $date AND ReportSubject.person = $pid
  ORDER BY date DESC
  LIMIT 50
'''

fetches.overview = '''
  SELECT ReportSubject.person AS pid,
         Person.name AS person,
         coalesce(a2.score2, 0) AS score,
         Person.grouping AS gid,
         Grouping.name AS grouping,
         Report.type AS type,
         count(Report.type) AS count

  FROM ReportSubject

  LEFT OUTER JOIN Person
  ON ReportSubject.person=Person.pid

  LEFT OUTER JOIN Grouping
  ON Person.grouping=Grouping.gid

  JOIN Report
  ON ReportSubject.report=Report.rid

  LEFT OUTER JOIN (
    SELECT ReportSubject.person AS pid2,
           sum(ReportSubject.score) As score2

    FROM ReportSubject

    JOIN Report
    ON ReportSubject.report=Report.rid

    WHERE Report.date >= $date_start and Report.date < $date_end
    GROUP BY pid2
  ) a2
  ON ReportSubject.person=a2.pid2

  WHERE Report.date >= $date_start and Report.date < $date_end
  GROUP BY pid, type
  ORDER BY score DESC
'''