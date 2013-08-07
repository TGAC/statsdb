-- MySQL dump 10.13  Distrib 5.1.63, for debian-linux-gnu (i686)
--
-- Host: n78048.nbi.ac.uk    Database: statsdb
-- ------------------------------------------------------
-- Server version	5.5.28

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `analysis`
--

DROP TABLE IF EXISTS `analysis`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `analysis` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `analysisDate` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `analysis_property`
--

DROP TABLE IF EXISTS `analysis_property`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `analysis_property` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `property` varchar(45) DEFAULT NULL,
  `value` varchar(500) DEFAULT NULL,
  `analysis_id` bigint(20) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_analysis_property_analysis1` (`id`),
  KEY `fk_analysis_property_analysis2` (`analysis_id`),
  CONSTRAINT `fk_analysis_property_analysis2` FOREIGN KEY (`analysis_id`) REFERENCES `analysis` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `analysis_value`
--

DROP TABLE IF EXISTS `analysis_value`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `analysis_value` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `value` double DEFAULT NULL,
  `analysis_id` bigint(20) NOT NULL,
  `value_type_id` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_analysis_value_analysis1` (`id`),
  KEY `fk_analysis_value_value_type1` (`value_type_id`),
  KEY `fk_analysis_value_analysis2` (`analysis_id`),
  CONSTRAINT `fk_analysis_value_analysis2` FOREIGN KEY (`analysis_id`) REFERENCES `analysis` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `fk_analysis_value_value_type3` FOREIGN KEY (`value_type_id`) REFERENCES `value_type` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Temporary table structure for view `latest_run`
--

DROP TABLE IF EXISTS `latest_run`;
/*!50001 DROP VIEW IF EXISTS `latest_run`*/;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
/*!50001 CREATE TABLE `latest_run` (
  `analysis_id` bigint(20),
  `tool` varchar(500),
  `encoding` varchar(500),
  `casava` varchar(500),
  `chemistry` varchar(500),
  `instrument` varchar(500),
  `software` varchar(500),
  `type` varchar(500),
  `pair` varchar(500),
  `sample_name` varchar(500),
  `lane` varchar(500),
  `run` varchar(500),
  `barcode` varchar(500)
) ENGINE=MyISAM */;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `per_partition_value`
--

DROP TABLE IF EXISTS `per_partition_value`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `per_partition_value` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `analysis_id` bigint(20) NOT NULL,
  `position` int(11) NOT NULL,
  `size` int(11) NOT NULL,
  `value` double NOT NULL,
  `value_type_id` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_per_partition_value_analysis` (`analysis_id`),
  KEY `fk_per_partition_value_value_type1` (`value_type_id`),
  CONSTRAINT `fk_per_base_gc_content_analysis1` FOREIGN KEY (`analysis_id`) REFERENCES `analysis` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `fk_per_partition_value_value_type1` FOREIGN KEY (`value_type_id`) REFERENCES `value_type` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `per_position_value`
--

DROP TABLE IF EXISTS `per_position_value`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `per_position_value` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `analysis_id` bigint(20) NOT NULL,
  `position` int(11) NOT NULL,
  `value` double NOT NULL,
  `value_type_id` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `fkper_position_value_analysis1` (`analysis_id`),
  KEY `fk_per_position_value_value_type1` (`value_type_id`),
  CONSTRAINT `fk_per_position_value_content_analysis1` FOREIGN KEY (`analysis_id`) REFERENCES `analysis` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `fk_per_position_value_value_type1` FOREIGN KEY (`value_type_id`) REFERENCES `value_type` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Temporary table structure for view `property`
--

DROP TABLE IF EXISTS `property`;
/*!50001 DROP VIEW IF EXISTS `property`*/;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
/*!50001 CREATE TABLE `property` (
  `id` bigint(20),
  `tool` varchar(500),
  `encoding` varchar(500),
  `casava` varchar(500),
  `chemistry` varchar(500),
  `instrument` varchar(500),
  `software` varchar(500),
  `type` varchar(500),
  `pair` varchar(500),
  `sample_name` varchar(500),
  `lane` varchar(500),
  `barcode` varchar(500),
  `run` varchar(500)
) ENGINE=MyISAM */;
SET character_set_client = @saved_cs_client;

--
-- Temporary table structure for view `run`
--

DROP TABLE IF EXISTS `run`;
/*!50001 DROP VIEW IF EXISTS `run`*/;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
/*!50001 CREATE TABLE `run` (
  `analysis_id` bigint(20),
  `tool` varchar(500),
  `encoding` varchar(500),
  `casava` varchar(500),
  `chemistry` varchar(500),
  `instrument` varchar(500),
  `software` varchar(500),
  `type` varchar(500),
  `pair` varchar(500),
  `sample_name` varchar(500),
  `lane` varchar(500),
  `run` varchar(500),
  `barcode` varchar(500)
) ENGINE=MyISAM */;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `type_scope`
--

DROP TABLE IF EXISTS `type_scope`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `type_scope` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `scope` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1 COMMENT='This table sets if the scope is for run, for each base, or p';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `value_type`
--

DROP TABLE IF EXISTS `value_type`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `value_type` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `type_scope_id` int(11) NOT NULL,
  `description` varchar(45) DEFAULT NULL,
  `comment` varchar(200) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_value_type_type_scope` (`type_scope_id`),
  CONSTRAINT `fk_value_type_type_scope` FOREIGN KEY (`type_scope_id`) REFERENCES `type_scope` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Final view structure for view `latest_run`
--

/*!50001 DROP TABLE IF EXISTS `latest_run`*/;
/*!50001 DROP VIEW IF EXISTS `latest_run`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8 */;
/*!50001 SET character_set_results     = utf8 */;
/*!50001 SET collation_connection      = utf8_general_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`statsdb`@`%` SQL SECURITY DEFINER */
/*!50001 VIEW `latest_run` AS select max(`run`.`analysis_id`) AS `analysis_id`,`run`.`tool` AS `tool`,`run`.`encoding` AS `encoding`,`run`.`casava` AS `casava`,`run`.`chemistry` AS `chemistry`,`run`.`instrument` AS `instrument`,`run`.`software` AS `software`,`run`.`type` AS `type`,`run`.`pair` AS `pair`,`run`.`sample_name` AS `sample_name`,`run`.`lane` AS `lane`,`run`.`run` AS `run`,`run`.`barcode` AS `barcode` from `run` group by `run`.`tool`,`run`.`encoding`,`run`.`casava`,`run`.`chemistry`,`run`.`instrument`,`run`.`software`,`run`.`type`,`run`.`pair`,`run`.`sample_name`,`run`.`lane`,`run`.`run`,`run`.`barcode` */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `property`
--

/*!50001 DROP TABLE IF EXISTS `property`*/;
/*!50001 DROP VIEW IF EXISTS `property`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8 */;
/*!50001 SET character_set_results     = utf8 */;
/*!50001 SET collation_connection      = utf8_general_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`statsdb`@`%` SQL SECURITY DEFINER */
/*!50001 VIEW `property` AS select `analysis_property`.`analysis_id` AS `id`,if((`analysis_property`.`property` = 'tool'),`analysis_property`.`value`,NULL) AS `tool`,if((`analysis_property`.`property` = 'Encoding'),`analysis_property`.`value`,NULL) AS `encoding`,if((`analysis_property`.`property` = 'cassava_version'),`analysis_property`.`value`,NULL) AS `casava`,if((`analysis_property`.`property` = 'chemistry_version'),`analysis_property`.`value`,NULL) AS `chemistry`,if((`analysis_property`.`property` = 'instrument'),`analysis_property`.`value`,NULL) AS `instrument`,if((`analysis_property`.`property` = 'software_on_instrument_version'),`analysis_property`.`value`,NULL) AS `software`,if((`analysis_property`.`property` = 'type_of_experiment'),`analysis_property`.`value`,NULL) AS `type`,if((`analysis_property`.`property` = 'pair'),`analysis_property`.`value`,NULL) AS `pair`,if((`analysis_property`.`property` = 'sample_name'),`analysis_property`.`value`,NULL) AS `sample_name`,if((`analysis_property`.`property` = 'lane'),`analysis_property`.`value`,NULL) AS `lane`,if((`analysis_property`.`property` = 'barcode'),`analysis_property`.`value`,NULL) AS `barcode`,if((`analysis_property`.`property` = 'run'),`analysis_property`.`value`,NULL) AS `run` from `analysis_property` group by `analysis_property`.`id` */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `run`
--

/*!50001 DROP TABLE IF EXISTS `run`*/;
/*!50001 DROP VIEW IF EXISTS `run`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8 */;
/*!50001 SET character_set_results     = utf8 */;
/*!50001 SET collation_connection      = utf8_general_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`statsdb`@`%` SQL SECURITY DEFINER */
/*!50001 VIEW `run` AS select `property`.`id` AS `analysis_id`,max(`property`.`tool`) AS `tool`,max(`property`.`encoding`) AS `encoding`,max(`property`.`casava`) AS `casava`,max(`property`.`chemistry`) AS `chemistry`,max(`property`.`instrument`) AS `instrument`,max(`property`.`software`) AS `software`,max(`property`.`type`) AS `type`,max(`property`.`pair`) AS `pair`,max(`property`.`sample_name`) AS `sample_name`,max(`property`.`lane`) AS `lane`,max(`property`.`run`) AS `run`,max(`property`.`barcode`) AS `barcode` from `property` group by `property`.`id` */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2013-08-07 16:38:19
