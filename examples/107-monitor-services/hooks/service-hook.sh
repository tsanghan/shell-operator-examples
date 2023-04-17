#!/usr/bin/env bash

if [[ $1 == "--config" ]] ; then
  cat <<EOF
configVersion: v1
kubernetes:
- apiVersion: v1
  kind: Service
  executeHookOnEvent:
  - Added
  - Deleted
EOF
else
  type=$(jq -r '.[0].type' $BINDING_CONTEXT_PATH)
  if [[ $type == "Event" ]] ; then
    serviceType=$(jq -r '.[0].object.spec.type')
    if [[ "$serviceType" == "LoadBalancer" ]]; then
      serviceName=$(jq -r '.[0].object.metadata.name' $BINDING_CONTEXT_PATH)
      serviceNodePort=$(jq -r '[0].object.spec.ports[0].nodePort' $BINDING_CONTEXT_PATH)
      printf "*** Service '%s' added ***" "$serviceName"
      nodesIP=($(kubectl get nodes -ojson | jq -r '.items[] | select(.metadata.labels | has("node.kubernetes.io/exclude-from-external-load-balancers") | not) | .status.addresses[0].address'))
      member_list_or_upstream=$(for node in "$nodesIP" do echo -n "$node:$serviceNodePort "; done)
      printf "*** Member/Upstream added as [%s]" "${member_list_or_upstream# }"
    fi
  fi
fi
