package uk.ac.bbsrc.tgac.statsdb.analysis;

import java.util.ArrayList;
import java.util.HashMap;

/**
 * uk.ac.bbsrc.tgac.qc.analysis
 * <p/>
 * Info
 *
 * @author Rob Davey
 * @date 03/07/13
 * @since 1.0-SNAPSHOT
 */
public class DefaultQCAnalysis extends AbstractQCAnalysis {
  public DefaultQCAnalysis() {
    properties = new HashMap<>();
    valueTypes = new HashMap<>();
    valueDescriptions = new HashMap<>();
    generalValues = new HashMap<>();
    partitionValues = new ArrayList<>();
    positionValues = new ArrayList<>();
  }
}
