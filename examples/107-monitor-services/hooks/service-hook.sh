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
    resourceEvent=$(jq -r ".[0].watchEvent" $BINDING_CONTEXT_PATH)
    serviceType=$(jq -r '.[0].object.spec.type' $BINDING_CONTEXT_PATH)
    if [[ "$serviceType" == "LoadBalancer" ]]; then
      serviceName=$(jq -r '.[0].object.metadata.name' $BINDING_CONTEXT_PATH)
      serviceNodePort=$(jq -r '.[0].object.spec.ports[0].nodePort' $BINDING_CONTEXT_PATH)
      printf "*** Service '%s' type '%s' %s ***\n" "$serviceName" "$serviceType" "$resourceEvent"
      nodesIP=($(kubectl get nodes -ojson | jq -r '.items[] | select(.metadata.labels | has("node.kubernetes.io/exclude-from-external-load-balancers") | not) | .status.addresses[0].address'))
      member_list_or_upstream=$(for node in "${nodesIP[@]}"; do echo -n "$node:$serviceNodePort, "; done)
      from_to=$([[ "$resourceEvent" == "Added" ]] && echo "to" || echo "from")
      printf "*** Members/Upstream [%s] %s %s External-LB ***\n" "${member_list_or_upstream%, }" "$resourceEvent" "$from_to"
      if [[ "$resourceEvent" == "Added" ]]; then
        kubectl patch svc "$serviceName" --subresource='status' --type=json --patch='[{"op":"add","path":"/status/loadBalancer/ingress","value":[{"hostname":"vs-bigip.gs.lab"}]}]'
        printf "*** Added External-Hostname vs-bigip.gs.lab to '%s' ***" "$serviceName"
      fi
    fi
  fi
fi
