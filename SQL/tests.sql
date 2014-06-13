--This tests are written for the TGAC database. 
--Change as appropiate accoring to your instrument names. 


call general_summaries_for_run(NULL, NULL, NULL, NULL, NULL);

call general_summaries_for_run(NULL, NULL, "1", NULL, NULL);

call general_summaries_for_run(NULL, NULL, "2", NULL, NULL);

call summary_per_position_for_run("quality_mean", NULL, NULL, NULL, NULL, NULL);

call list_runs( NULL, NULL, NULL, NULL, NULL);

call list_runs_for_instrument( "M00841");

call list_lanes_for_run( "140307_M00841_0059_000000000-A81V3");

call list_barcodes_for_run_and_lane( "140603_SN7001150_0264_BH9H2NADXX", 2);

call get_sample_from_run_lane_barcode("GTGAAA","140603_SN7001150_0264_BH9H2NADXX", 2) ;

call summary_value_with_comment("overrepresented_sequence", NULL, NULL, NULL, NULL, NULL);

call summary_value("multiplex_tag", NULL, NULL, NULL, NULL, NULL);

