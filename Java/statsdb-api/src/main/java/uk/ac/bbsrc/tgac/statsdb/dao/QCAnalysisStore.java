package uk.ac.bbsrc.tgac.statsdb.dao;

import uk.ac.bbsrc.tgac.statsdb.analysis.QCAnalysis;
import uk.ac.bbsrc.tgac.statsdb.exception.QCAnalysisException;
import uk.ac.bbsrc.tgac.statsdb.util.VerbosityAware;

/**
 * Defines a DAO contract for storing QCAnalysis objects and related properties and values.
 *
 * @author Rob Davey
 * @date 02/07/13
 * @since 1.0-SNAPSHOT
 */
public interface QCAnalysisStore extends VerbosityAware {
  /**
   * Given an analysis parameter, insert that analysis into the database. This method would usually call the other
   * interface methods in turn.
   *
   * @param analysis
   * @throws QCAnalysisException when the QCAnalysis object could not be inserted
   */
  public void insertAnalysis(QCAnalysis analysis) throws QCAnalysisException;

  /**
   * Given an analysis parameter, insert the general values contained within
   *
   * @param analysis
   * @throws QCAnalysisException
   */
  public void insertValues(QCAnalysis analysis) throws QCAnalysisException;

  /**
   * Given an analysis parameter, insert the analysis properties contained within
   *
   * @param analysis
   * @throws QCAnalysisException
   */
  public void insertProperties(QCAnalysis analysis) throws QCAnalysisException;

  /**
   * Given an analysis parameter, insert the partition values contained within
   *
   * @param analysis
   * @throws QCAnalysisException
   */
  public void insertPartitionValues(QCAnalysis analysis) throws QCAnalysisException;

  /**
   * Given an analysis parameter, insert the position values contained within
   *
   * @param analysis
   * @throws QCAnalysisException
   */
  public void insertPositionValues(QCAnalysis analysis) throws QCAnalysisException;
}
