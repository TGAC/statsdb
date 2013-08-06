package uk.ac.bbsrc.tgac.statsdb.dao;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import uk.ac.bbsrc.tgac.statsdb.analysis.QCAnalysis;
import uk.ac.bbsrc.tgac.statsdb.exception.QCAnalysisException;

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
  protected static final Logger log = LoggerFactory.getLogger(QCAnalysisDAO.class);
  private JdbcTemplate template;

  public JdbcTemplate getJdbcTemplate() {
    return template;
  }

  public void setJdbcTemplate(JdbcTemplate template) {
    this.template = template;
  }

  @Override
  public void insertAnalysis(QCAnalysis analysis) throws QCAnalysisException {
/*
        my $new_analysis = shift;
        my $dbh = $self->{connection};
        my $q = "INSERT INTO analysis () values ();";
        my $inserted = $dbh->do($q);
        my $id = $dbh->last_insert_id(undef, undef, undef, undef);
        $new_analysis->{id} = $id;
        $inserted &= $self->insert_properties($new_analysis);
        $inserted &= $self->insert_values($new_analysis);
        $inserted &= $self->insert_partitions($new_analysis);
        $inserted &= $self->insert_positions($new_analysis);

        print "inserted $id\n" if($inserted);

     */
  }

  @Override
  public void insertValues(QCAnalysis analysis) throws QCAnalysisException {
    /*
        my $db = $self->{connection};
#       print "in insert values\n";
        (my $values, my $values_desc) = $analysis->get_value_types();
        my %id_values;
#       print $values."\n";
        my $id_value;
        while ((my $key, my $value) = each(%$values)){
                my $value_desc = $values_desc->{$key};
                $id_values{$key} = $self->get_value_id($key, $value, $value_desc);

        }
        my $inserted = 1;
        my $general_values = $analysis->get_general_values();
        while ((my $key, my $value) = each(%$general_values)){
                if(defined $id_values{$key}){
                        $id_value = $id_values{$key};
                        my $ins_gv = "INSERT INTO analysis_value (analysis_id, value_type_id, value) VALUES ('".$analysis->{id}."', $id_value, $value);";
#                       print $ins_gv."\n";
                        $inserted &= $db->do($ins_gv);
                }else{
                        unless(defined $warn_printed{$key} ){
                                print "WARN: Value not defined '".$key."'\n";
                                 $warn_printed{$key} = 1;

                        }
                }
        }
        return $inserted;
        */

  }

  @Override
  public void insertProperties(QCAnalysis analysis) throws QCAnalysisException {
    /*
        my $dbh = $self->{connection};
        my $id = $analysis->{id};
        my $properties = $analysis->{property};
        my $success=1;
        foreach my $key ( keys %{$properties} )
        {
        #  print "key: $key, value: " .."\n";
                my $value = $properties->{$key};
                my $statement = "INSERT INTO analysis_property(analysis_id, property, value) VALUES ('$id', '$key', '$value');";
#               print $statement."\n";
                $success &= $dbh->do($statement);
        }

        return $success;
        */



  }

  @Override
  public void insertPartitionValues(QCAnalysis analysis) throws QCAnalysisException {
    /*
        my $db = $self->{connection};
        #print "in insert values\n";
        (my $values, my $val_desc ) = $analysis->get_value_types();
        my %id_values;
        #       print $values."\n";
        my $id_value;
        while ((my $key, my $value) = each(%$values)){
                $id_values{$key} = $self->get_value_id($key, $value);
        }
        my $inserted = 1;
        my $partition_values = $analysis->get_partition_values();
        my $analysis_id = $analysis->{id};
        foreach(@$partition_values){
                if($id_values{$_->[2]} > 0){
                        my $position = $_->[0];
                        my $size = $_->[1];
                        my $value_type_id = $id_values{$_->[2]};
                        my $value =  $_->[3];

                        my $ins_pv = "INSERT INTO per_partition_value (analysis_id, position, size, value, value_type_id) VALUES ($analysis_id, $position, $size, $value, $value_type_id);\n";
                #       print $ins_pv;
                        $inserted &= $db->do($ins_pv);
                }else{

                        unless(defined $warn_printed{$_->[2]} ){
                                print "WARN: Not defined ".$_->[2]."\n";
                                 $warn_printed{$_->[2]} = 1;

                        }
                }
        }
        return $inserted;
*/
  }

  @Override
  public void insertPositionValues(QCAnalysis analysis) throws QCAnalysisException {
/*
        my $db = $self->{connection};
        #print "in insert values\n";
        (my $values, my $val_desc ) = $analysis->get_value_types();
        my %id_values;
        #       print $values."\n";
        my $id_value;
        while ((my $key, my $value) = each(%$values)){
                $id_values{$key} = $self->get_value_id($key, $value);
        }
        my $inserted = 1;
        my $position_values = $analysis->get_position_values();
        my $analysis_id = $analysis->{id};
        foreach(@$position_values){
                if($id_values{$_->[1]} > 0){
                        my $position = $_->[0];
                        my $value_type_id = $id_values{$_->[1]};
                        my $value =  $_->[2];

                        my $ins_pv = "INSERT INTO per_position_value (analysis_id, position, value, value_type_id) VALUES ($analysis_id, $position, $value, $value_type_id);\n";
                #       print $ins_pv;
                        $inserted &= $db->do($ins_pv);
                }else{

                        unless(defined $warn_printed{$_->[1]} ){

                                print "WARN: Not defined ".$_->[1]."\n";
                                $warn_printed{$_->[1]} = 1;
                        }

                }
        }
        return $inserted;

     */
  }
}
