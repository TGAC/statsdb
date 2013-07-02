package uk.ac.bbsrc.tgac.qc.dao;

import uk.ac.bbsrc.tgac.qc.analysis.QCAnalysis;
import uk.ac.bbsrc.tgac.qc.exception.QCAnalysisException;

/**
 * uk.ac.bbsrc.tgac.qc.dao
 * <p/>
 * Implementation of a QCAnalysisStore
 *
 * @author Rob Davey
 * @date 02/07/13
 * @since 1.0-SNAPSHOT
 */
public class QCAnalysisDAO implements QCAnalysisStore {
  @Override
  public void insertAnalysis(QCAnalysis analysis) throws QCAnalysisException {
  }

  @Override
  public void insertValues(QCAnalysis analysis) throws QCAnalysisException {
  }

  @Override
  public void insertProperties(QCAnalysis analysis) throws QCAnalysisException {
  }

  @Override
  public void insertPartitionValues(QCAnalysis analysis) throws QCAnalysisException {
  }

  @Override
  public void insertPositionValues(QCAnalysis analysis) throws QCAnalysisException {
  }
}
