Drop TABLE `items`;

CREATE TABLE IF NOT EXISTS `items` (
  `id` int(11) NOT NULL auto_increment,
  `date` date NOT NULL,
  `name` varchar(256) NOT NULL,
  `description` text NOT NULL,
  `extension` varchar(10) NOT NULL,
  `mime` varchar (50) NOT NULL,
  `image` blob NOT NULL,
  
  PRIMARY KEY  (`id`),
) ENGINE=MyISAM DEFAULT CHARSET=UTF8;
