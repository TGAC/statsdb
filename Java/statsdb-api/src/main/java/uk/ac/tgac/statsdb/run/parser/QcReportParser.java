package uk.ac.tgac.statsdb.run.parser;

import net.sourceforge.fluxion.spi.Spi;
import uk.ac.tgac.statsdb.analysis.QCAnalysis;
import uk.ac.tgac.statsdb.exception.QCAnalysisException;

/**
 * Interface defining contract to parse the output of a QC application into the StatsDB QCAnalysis data type.
 *
 * This interface is marked with the @Spi annotation, meaning it can be resolved at runtime by the ServiceLoader
 * architecture.
 *
 * @author Rob Davey
 * @date 01/07/13
 * @since 1.0-SNAPSHOT
 */
@Spi
public interface QcReportParser<T> {
  /**
   * Parse a report of type T, populating a given QCAnalysis object properties and values
   * @param in object of type T
   * @param qcAnalysis to populate with report contents
   * @throws QCAnalysisException when the report could not be parsed
   */
  void parseReport(T in, QCAnalysis qcAnalysis) throws QCAnalysisException;
}
