SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='TRADITIONAL';
DROP DATABASE statsdb;

CREATE SCHEMA IF NOT EXISTS `statsdb` DEFAULT CHARACTER SET latin1 ;
USE `statsdb` ;

-- -----------------------------------------------------
-- Table `type_scope`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `type_scope` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `scope` VARCHAR(45) NULL ,
  PRIMARY KEY (`id`) )
ENGINE = InnoDB
COMMENT = 'This table sets if the scope is for run, for each base, or p' /* comment truncated */;


-- -----------------------------------------------------
-- Table `value_type`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `value_type` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `type_scope_id` INT NOT NULL ,
  `description` TEXT NULL ,
  `comment` VARCHAR(200) NULL ,
  PRIMARY KEY (`id`) ,
  INDEX `fk_value_type_type_scope` (`type_scope_id` ASC) ,
  CONSTRAINT `fk_value_type_type_scope`
    FOREIGN KEY (`type_scope_id` )
    REFERENCES `type_scope` (`id` )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table `analysis`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `analysis` (
  `id` BIGINT(20) NOT NULL AUTO_INCREMENT ,
  `analysisDate` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP ,
  PRIMARY KEY (`id`) )
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

-- -----------------------------------------------------
-- Table `per_partition_value`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `per_partition_value` (
  `id` BIGINT(20) NOT NULL AUTO_INCREMENT ,
  `analysis_id` BIGINT(20) NOT NULL ,
  `position` INT(11) NOT NULL ,
  `size` INT(11) NOT NULL,
  `value` DOUBLE NOT NULL ,
  `value_type_id` INT NOT NULL ,
  PRIMARY KEY (`id`) ,
  INDEX `fk_per_partition_value_analysis` (`analysis_id` ASC) ,
  INDEX `fk_per_partition_value_value_type1` (`value_type_id` ASC) ,
  CONSTRAINT `fk_per_base_gc_content_analysis1`
    FOREIGN KEY (`analysis_id` )
    REFERENCES `analysis` (`id` )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_per_partition_value_value_type1`
    FOREIGN KEY (`value_type_id` )
    REFERENCES `value_type` (`id` )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

-- -----------------------------------------------------
-- Table `per_position_value`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `per_position_value` (
  `id` BIGINT(20) NOT NULL AUTO_INCREMENT ,
  `analysis_id` BIGINT(20) NOT NULL ,
  `position` INT(11) NOT NULL ,
  `value` DOUBLE NOT NULL ,
  `value_type_id` INT NOT NULL ,
  PRIMARY KEY (`id`) ,
  INDEX `fkper_position_value_analysis1` (`analysis_id` ASC) ,
  INDEX `fk_per_position_value_value_type1` (`value_type_id` ASC) ,
  CONSTRAINT `fk_per_position_value_content_analysis1`
    FOREIGN KEY (`analysis_id` )
    REFERENCES `analysis` (`id` )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_per_position_value_value_type1`
    FOREIGN KEY (`value_type_id` )
    REFERENCES `value_type` (`id` )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;


-- -----------------------------------------------------
-- Table `analysis_value`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `analysis_value` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `value` DOUBLE NULL ,
  `analysis_id` BIGINT(20) NOT NULL ,
  `value_type_id` INT NOT NULL ,
  PRIMARY KEY (`id`) ,
  INDEX `fk_analysis_value_analysis1` (`id` ASC) ,
  INDEX `fk_analysis_value_value_type1` (`value_type_id` ASC) ,
  CONSTRAINT `fk_analysis_value_analysis2`
    FOREIGN KEY (`analysis_id` )
    REFERENCES `analysis` (`id` )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_analysis_value_value_type3`
    FOREIGN KEY (`value_type_id` )
    REFERENCES `value_type` (`id` )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `analysis_property`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `analysis_property` (
  `id` BIGINT(20) NOT NULL AUTO_INCREMENT ,
  `property` VARCHAR(45) NULL ,
  `value` VARCHAR(500) NULL ,
  `analysis_id` BIGINT(20) NOT NULL ,
  PRIMARY KEY (`id`) ,
  INDEX `fk_analysis_property_analysis1` (`id` ASC) ,
  CONSTRAINT `fk_analysis_property_analysis2`
    FOREIGN KEY (`analysis_id` )
    REFERENCES `analysis` (`id` )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;




SET SQL_MODE=@OLD_SQL_MODE;
SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;

