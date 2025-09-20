#!/bin/bash
#
# Install extra software
#

set -euxo pipefail

# This script is executed on the master node, but triggered from the last worker.
# It needs to be self-contained.

# Install yq
sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq && sudo chmod +x /usr/bin/yq

# Read settings from settings.yaml
SETTINGS_FILE="/vagrant/settings.yaml"
DASHBOARD=$(yq e '.software.tools.dashboard' $SETTINGS_FILE)
ARGO_EVENTS=$(yq e '.software.tools.argo-events' $SETTINGS_FILE)
ARGO_WORKFLOW=$(yq e '.software.tools.argo-workflow' $SETTINGS_FILE)
ARGO_ROLLOUT=$(yq e '.software.tools.argo-rollout' $SETTINGS_FILE)
ISTIO=$(yq e '.software.tools.istio' $SETTINGS_FILE)
NUM_WORKER_NODES=$(yq e '.nodes.workers.count' $SETTINGS_FILE)

# The rest of the script is executed as the vagrant user
sudo -i -u vagrant bash -s "${DASHBOARD}" "${ARGO_EVENTS}" "${ARGO_WORKFLOW}" "${ARGO_ROLLOUT}" "${ISTIO}" "${NUM_WORKER_NODES}" << 'EOF'
export KUBECONFIG=/home/vagrant/.kube/config

DASHBOARD=$1
ARGO_EVENTS=$2
ARGO_WORKFLOW=$3
ARGO_ROLLOUT=$4
ISTIO=$5
NUM_WORKER_NODES=$6

echo "Waiting for all nodes to be ready..."
# The +1 is for the master node
EXPECTED_NODES=$((${NUM_WORKER_NODES} + 1))
while [ "$(kubectl get nodes --no-headers | wc -l)" -lt "$EXPECTED_NODES" ]; do
  echo "Not all nodes have joined yet, waiting..."
  sleep 10
done

while [ "$(kubectl get nodes --no-headers | grep -c -v 'Ready')" -gt 0 ]; do
  echo "Not all nodes are ready yet, waiting..."
  sleep 10
done
echo "All nodes are ready."

# Install Kubernetes Dashboard
if [ "${DASHBOARD}" != "null" ]; then
  echo 'Metrics server is ready. Installing dashboard...'

  kubectl create namespace kubernetes-dashboard || true

  echo "Creating the dashboard user..."

  cat <<EOT | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
EOT

  cat <<EOT | kubectl apply -f -
apiVersion: v1
kind: Secret
type: kubernetes.io/service-account-token
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
  annotations:
    kubernetes.io/service-account.name: admin-user
EOT

  cat <<EOT | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOT

  echo "Deploying the dashboard..."
  kubectl apply -f "https://raw.githubusercontent.com/kubernetes/dashboard/v${DASHBOARD}/aio/deploy/recommended.yaml"

  kubectl -n kubernetes-dashboard get secret/admin-user -o go-template="{{.data.token | base64decode}}" >> "/vagrant/configs/token"
  echo "The following token was also saved to: configs/token"
  cat "/vagrant/configs/token"
  echo -e "\nUse it to log in at:\nhttp://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/#/overview?namespace=kubernetes-dashboard\n"
fi

# Install Istio
if [[ "${ISTIO}" == "true" || "${ARGO_ROLLOUT}" == "true" ]]; then
  echo "Installing Istio with minimal configuration..."
  helm repo add istio https://istio-release.storage.googleapis.com/charts
  helm repo update
  kubectl create namespace istio-system || true

  # Install Istio base (CRDs)
  helm install istio-base istio/base -n istio-system --set defaultRevision=default --wait

  # Install Istio control plane (istiod)
  helm install istiod istio/istiod -n istio-system \
    --set pilot.resources.requests.cpu=100m \
    --set pilot.resources.requests.memory=128Mi \
    --set global.proxy.resources.requests.cpu=10m \
    --set global.proxy.resources.requests.memory=32Mi \
    --wait

  # Install Istio ingress gateway
  helm install istio-ingress istio/gateway -n istio-system \
    --set resources.requests.cpu=10m \
    --set resources.requests.memory=32Mi \
    --set replicaCount=1 \
    --wait
fi

# Add argo repo
if [[ "${ARGO_WORKFLOW}" == "true" ]] || [[ "${ARGO_EVENTS}" == "true" ]] || [[ "${ARGO_ROLLOUT}" == "true" ]]; then
  helm repo add argo https://argoproj.github.io/argo-helm
  helm repo update
fi

# Install Argo Workflows
if [ "${ARGO_WORKFLOW}" = "true" ]; then
  echo "Installing Argo Workflows..."
  kubectl create namespace argo || true
  helm install argo-workflow argo/argo-workflows -n argo --set server.extraArgs[0]="--auth-mode=server" --wait
fi

# Install Argo Events
if [ "${ARGO_EVENTS}" = "true" ]; then
  echo "Installing Argo Events..."
  kubectl create namespace argo-events || true
  helm install argo-events argo/argo-events -n argo-events --wait
fi

# Install Argo Rollouts
if [ "${ARGO_ROLLOUT}" = "true" ]; then
  echo "Installing Argo Rollouts..."
  kubectl create namespace argo-rollouts || true
  helm install argo-rollouts argo/argo-rollouts -n argo-rollouts --wait
fi
EOF
