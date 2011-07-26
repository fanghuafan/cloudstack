#!/bin/bash
# Version @VERSION@

#set -x

# propagate VLANs to other host
for networkname in $(xe network-list | grep "name-label ( RW): VLAN" | awk '{print $NF}');
do 
  network=$(xe network-list name-label=$networkname --minimal)
  tagpif=$(xe pif-list  network-uuid=$network --minimal | cut -d, -f 1)
  device=$(xe pif-param-get uuid=$tagpif param-name=device)
  vlan=$(xe pif-param-get uuid=$tagpif param-name=VLAN)
  for host in $(xe host-list | grep ^uuid | awk '{print $NF}')
  do
    tagpif=$(xe pif-list network-uuid=$network  host-uuid=$host --minimal)
    if [ -z $tagpif ]; then
      pif=$(xe pif-list host-uuid=$host device=$device --minimal)
      xe vlan-create network-uuid=$network pif-uuid=$pif vlan=$vlan
    fi
  done
done


# fake PV for PV VM

fake_pv_driver() {
  local vm=$1
  res=$(xe vm-param-get uuid=$vm param-name=PV-drivers-version)
  if [ ! "$res" = "<not in database>" ]; then
    return 1
  fi
  res=$(xe vm-param-get uuid=$vm param-name=HVM-boot-policy)
  if [ ! -z $res ]; then
    echo "Warning VM $vm is HVM, but PV driver is not installed, you may need to stop it manually"
    return 0
  fi
  make_migratable.sh $vm
}


vms=$(xe vm-list is-control-domain=false| grep ^uuid | awk '{print $NF}')
for vm in $vms
do  
  state=$(xe vm-param-get uuid=$vm param-name=power-state)
  if [ $state = "running" ]; then
    fake_pv_driver $vm
  elif [ $state = "halted" ]; then
    echo "VM $vm is in $state"
  else
    echo "Warning : Don't know how to handle VM $vm, it is in $state state"
  fi
done

