package uk.ac.bbsrc.tgac.qc.run.parser;

import net.sourceforge.fluxion.spi.Spi;
import uk.ac.bbsrc.tgac.qc.analysis.QCAnalysis;
import uk.ac.bbsrc.tgac.qc.exception.QCAnalysisException;

/**
 * uk.ac.bbsrc.tgac.qc.run.parser
 * <p/>
 * Interface defining contract to parse the output of a QC application into the StatsDB
 *
 * @author Rob Davey
 * @date 01/07/13
 * @since 1.0-SNAPSHOT
 */
@Spi
public interface QcReportParser<T> {
  void parseReport(T in, QCAnalysis qcAnalysis) throws QCAnalysisException;
}
