#!/bin/bash
#
# Check and manage installed services in the Kubernetes cluster
#

set -euo pipefail

KUBECONFIG_PATH="/home/vagrant/.kube/config"
SETTINGS_FILE="/vagrant/settings.yaml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    case $status in
        "OK")
            echo -e "${GREEN}✓${NC} $message"
            ;;
        "ERROR")
            echo -e "${RED}✗${NC} $message"
            ;;
        "WARNING")
            echo -e "${YELLOW}⚠${NC} $message"
            ;;
        "INFO")
            echo -e "${BLUE}ℹ${NC} $message"
            ;;
    esac
}

# Function to check if a namespace exists and has running pods
check_namespace() {
    local namespace=$1
    local service_name=$2

    if kubectl --kubeconfig=$KUBECONFIG_PATH get namespace "$namespace" >/dev/null 2>&1; then
        local running_pods=$(kubectl --kubeconfig=$KUBECONFIG_PATH get pods -n "$namespace" --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
        local total_pods=$(kubectl --kubeconfig=$KUBECONFIG_PATH get pods -n "$namespace" --no-headers 2>/dev/null | wc -l)

        if [ $running_pods -eq $total_pods ] && [ $total_pods -gt 0 ]; then
            print_status "OK" "$service_name is running ($running_pods/$total_pods pods ready)"
            return 0
        else
            print_status "WARNING" "$service_name has issues ($running_pods/$total_pods pods ready)"
            return 1
        fi
    else
        print_status "ERROR" "$service_name namespace not found"
        return 1
    fi
}

# Function to get service URLs and access commands
show_access_info() {
    local service=$1

    case $service in
        "dashboard")
            if check_namespace "kubernetes-dashboard" "Kubernetes Dashboard" >/dev/null 2>&1; then
                echo "  Access: kubectl --kubeconfig=$KUBECONFIG_PATH proxy"
                echo "  URL: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
                echo "  Token: cat /vagrant/configs/token"
            fi
            ;;
        "istio")
            if check_namespace "istio-system" "Istio" >/dev/null 2>&1; then
                echo "  Ingress Gateway: kubectl --kubeconfig=$KUBECONFIG_PATH get svc -n istio-system istio-ingress"
                echo "  Kiali (if installed): kubectl --kubeconfig=$KUBECONFIG_PATH port-forward -n istio-system svc/kiali 20001:20001"
            fi
            ;;
        "argo-workflows")
            if check_namespace "argo" "Argo Workflows" >/dev/null 2>&1; then
                echo "  UI Access: kubectl --kubeconfig=$KUBECONFIG_PATH port-forward -n argo svc/argo-workflow-argo-workflows-server 2746:2746"
                echo "  URL: http://localhost:2746"
            fi
            ;;
        "argo-events")
            if check_namespace "argo-events" "Argo Events" >/dev/null 2>&1; then
                echo "  Check sensors: kubectl --kubeconfig=$KUBECONFIG_PATH get sensors -n argo-events"
                echo "  Check event sources: kubectl --kubeconfig=$KUBECONFIG_PATH get eventsources -n argo-events"
            fi
            ;;
        "argo-rollouts")
            if check_namespace "argo-rollouts" "Argo Rollouts" >/dev/null 2>&1; then
                echo "  Dashboard: kubectl --kubeconfig=$KUBECONFIG_PATH port-forward -n argo-rollouts svc/argo-rollouts-dashboard 3100:3100"
                echo "  URL: http://localhost:3100"
                echo "  CLI: kubectl --kubeconfig=$KUBECONFIG_PATH argo rollouts get rollout ROLLOUT_NAME"
            fi
            ;;
    esac
}

# Main function to check all services
main() {
    echo "=================================================="
    echo "         Kubernetes Services Status Check        "
    echo "=================================================="
    echo ""

    # Check if kubectl is available and cluster is reachable
    if ! kubectl --kubeconfig=$KUBECONFIG_PATH cluster-info >/dev/null 2>&1; then
        print_status "ERROR" "Cannot connect to Kubernetes cluster"
        exit 1
    fi

    print_status "OK" "Connected to Kubernetes cluster"
    echo ""

    # Check for services by detecting if their namespaces exist
    # This is more reliable than parsing YAML files
    print_status "INFO" "Detecting installed services..."

    echo "Service Status:"
    echo "---------------"

    # Check Kubernetes Dashboard
    if kubectl --kubeconfig=$KUBECONFIG_PATH get namespace kubernetes-dashboard >/dev/null 2>&1; then
        check_namespace "kubernetes-dashboard" "Kubernetes Dashboard"
    fi

    # Check Istio
    if kubectl --kubeconfig=$KUBECONFIG_PATH get namespace istio-system >/dev/null 2>&1; then
        check_namespace "istio-system" "Istio Service Mesh"
    fi

    # Check Argo Workflows
    if kubectl --kubeconfig=$KUBECONFIG_PATH get namespace argo >/dev/null 2>&1; then
        check_namespace "argo" "Argo Workflows"
    fi

    # Check Argo Events
    if kubectl --kubeconfig=$KUBECONFIG_PATH get namespace argo-events >/dev/null 2>&1; then
        check_namespace "argo-events" "Argo Events"
    fi

    # Check Argo Rollouts
    if kubectl --kubeconfig=$KUBECONFIG_PATH get namespace argo-rollouts >/dev/null 2>&1; then
        check_namespace "argo-rollouts" "Argo Rollouts"
    fi

    echo ""
    echo "Access Information:"
    echo "-------------------"

    # Show access information for installed services
    if kubectl --kubeconfig=$KUBECONFIG_PATH get namespace kubernetes-dashboard >/dev/null 2>&1; then
        echo "• Kubernetes Dashboard:"
        show_access_info "dashboard"
        echo ""
    fi

    if kubectl --kubeconfig=$KUBECONFIG_PATH get namespace istio-system >/dev/null 2>&1; then
        echo "• Istio Service Mesh:"
        show_access_info "istio"
        echo ""
    fi

    if kubectl --kubeconfig=$KUBECONFIG_PATH get namespace argo >/dev/null 2>&1; then
        echo "• Argo Workflows:"
        show_access_info "argo-workflows"
        echo ""
    fi

    if kubectl --kubeconfig=$KUBECONFIG_PATH get namespace argo-events >/dev/null 2>&1; then
        echo "• Argo Events:"
        show_access_info "argo-events"
        echo ""
    fi

    if kubectl --kubeconfig=$KUBECONFIG_PATH get namespace argo-rollouts >/dev/null 2>&1; then
        echo "• Argo Rollouts:"
        show_access_info "argo-rollouts"
        echo ""
    fi

    echo "=================================================="
    echo "Tip: Run this script with 'watch' for live updates:"
    echo "watch -n 5 /vagrant/scripts/check-services.sh"
    echo "=================================================="
}

# Run main function
main
