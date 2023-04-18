k logs shell-operator -f | jq -r --stream 'select(.[0][0] == "msg") | select(.[1]|startswith("***")) | .[1]'
