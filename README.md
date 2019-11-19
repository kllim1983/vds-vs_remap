# vds-vs_remap
VMware PowerCLI VDS/VS portgroup remap

This Powershell file utilizes VMware PowerCLI module to automate port mapping between both Virtual Distributed Switch and Virtual Switch portgroups to reduce the chances of human error if it was done manually.



The logic of the script is:
1) login to vCenter (via Option 1 - Prompt or Option 2 - from a predefined list).
2) List all the hosts available from that vCenter.
3) List all VMs and their associated NetworkAdapter for the selected host.
4) The script will filter all the unique portgroups for all the VMs and then put into a Hash Table.
5) The script will list all available portgroups for that Host (with filtered vmkernel portgroup).
6) Script will prompt user for mapping Unique Source portgroup to selectable Target portgroup and map into a Hash Table.
7) Script will execute the commands and then output to a log file with the Source and Target portgroup and their respective VMs.
8) User can choose to rerun the script if wanted to.
