CREATE TABLE users (
    id INTEGER UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
    username VARBINARY(50),
    digesta1 VARBINARY(32),
    UNIQUE(username)
);

INSERT INTO users (username,digesta1) VALUES
('admin',  '2bd199b750010a686f5908c2551d39b3');
