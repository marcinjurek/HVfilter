# vecchiaFilter
code for a fast filter using the Vecchia approximation. In order to reproduce simulations form the paper use the commands in the script `run-simulations.sh` located in each `simulations-*` folder. For the large-scale simulations it might be inadvisable to run the script as is as it might take several hours to complete. Rather, one can consider running each command separately. Since the output of these simulations is piped to a log file, the current progress can be seen by using the `tail -f gauss.log` command (after appropriately changing the name of the log file).
