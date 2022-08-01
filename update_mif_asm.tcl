# add to your flow / tasks to update the MIF & assemble

# update mif
execute_module -tool cdb -args "--update_mif"

# assemble
execute_module -tool asm 

#quartus_cdb $quartus(project) -c $quartus(project) --update_mif

#execute_module -tool cpf -args "-c --option=<full_path>/config_options.txt --sfl_device=\"5CEFA2\" --device=\"EPCS16\" <full_path>/simpleled.sof <full_path>/ simpleled.jic"