CREATE TABLE users (
	id integer primary key asc,
	username TEXT,
	digesta1 TEXT,
	UNIQUE(username)
);

INSERT INTO users (username,digesta1) VALUES
('admin',  '2bd199b750010a686f5908c2551d39b3');
