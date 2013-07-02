package uk.ac.bbsrc.tgac.qc.dao;

import uk.ac.bbsrc.tgac.qc.analysis.QCAnalysis;
import uk.ac.bbsrc.tgac.qc.exception.QCAnalysisException;

/**
 * uk.ac.bbsrc.tgac.qc.dao
 * <p/>
 * Defines a DAO contract for storing QCAnalysis objects and related properties and values.
 *
 * @author Rob Davey
 * @date 02/07/13
 * @since 1.0-SNAPSHOT
 */
public interface QCAnalysisStore {
  public void insertAnalysis(QCAnalysis analysis) throws QCAnalysisException;
  public void insertValues(QCAnalysis analysis) throws QCAnalysisException;
  public void insertProperties(QCAnalysis analysis) throws QCAnalysisException;
  public void insertPartitionValues(QCAnalysis analysis) throws QCAnalysisException;
  public void insertPositionValues(QCAnalysis analysis) throws QCAnalysisException;
}
