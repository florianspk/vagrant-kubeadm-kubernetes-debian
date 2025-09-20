# Services Installés Automatiquement

Ce document décrit les services qui peuvent être installés automatiquement lors du déploiement du cluster Kubernetes avec Vagrant.

## Configuration

Les services sont configurés dans le fichier `settings.yaml` sous la section `software.tools` :

```yaml
software:
  tools:
    dashboard: 2.7.0        # Version du Dashboard Kubernetes
    argo-events: true       # Argo Events pour la gestion d'événements
    argo-workflow: true     # Argo Workflows pour l'orchestration
    argo-rollout: true      # Argo Rollouts pour les déploiements avancés
    istio: true            # Istio Service Mesh
```

## Services Disponibles

### 1. Kubernetes Dashboard
**Namespace:** `kubernetes-dashboard`

Interface web pour gérer votre cluster Kubernetes.

**Accès:**
```bash
kubectl proxy
```
Puis ouvrez: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/

**Token d'authentification:**
```bash
cat configs/token
```

### 2. Istio Service Mesh
**Namespace:** `istio-system`

Plateforme de service mesh pour connecter, sécuriser, contrôler et observer les microservices.

**Composants installés:**
- `istio-base`: CRDs et rôles cluster de base
- `istiod`: Plan de contrôle Istio
- `istio-ingress`: Gateway d'entrée

**Vérification:**
```bash
kubectl get pods -n istio-system
kubectl get svc -n istio-system
```

**Configuration minimale appliquée:**
- CPU requests réduits pour un environnement de développement
- Mémoire optimisée
- Une seule réplique par composant

### 3. Argo Workflows
**Namespace:** `argo`

Moteur de workflows containerisés pour Kubernetes.

**Accès à l'interface:**
```bash
kubectl port-forward -n argo svc/argo-workflow-argo-workflows-server 2746:2746
```
Puis ouvrez: http://localhost:2746

**Commandes utiles:**
```bash
# Lister les workflows
kubectl get workflows -n argo

# Voir les logs d'un workflow
kubectl logs -n argo -l workflows.argoproj.io/workflow=WORKFLOW_NAME

# Soumettre un workflow
argo submit -n argo --watch workflow.yaml
```

### 4. Argo Events
**Namespace:** `argo-events`

Framework d'automatisation de workflows basé sur les événements.

**Commandes utiles:**
```bash
# Lister les sources d'événements
kubectl get eventsources -n argo-events

# Lister les sensors
kubectl get sensors -n argo-events

# Voir les logs du contrôleur
kubectl logs -n argo-events -l app.kubernetes.io/name=argo-events
```

### 5. Argo Rollouts
**Namespace:** `argo-rollouts`

Contrôleur de déploiement progressif pour Kubernetes avec support des stratégies avancées.

**Dashboard:**
```bash
kubectl port-forward -n argo-rollouts svc/argo-rollouts-dashboard 3100:3100
```
Puis ouvrez: http://localhost:3100

**Commandes utiles:**
```bash
# Lister les rollouts
kubectl get rollouts -n argo-rollouts

# Voir le statut d'un rollout
kubectl argo rollouts get rollout ROLLOUT_NAME

# Promouvoir un rollout
kubectl argo rollouts promote ROLLOUT_NAME
```

## Scripts Utilitaires

### Vérification des Services
Un script est disponible pour vérifier l'état de tous les services installés :

```bash
/vagrant/scripts/check-services.sh
```

**Ou pour un suivi en temps réel:**
```bash
watch -n 5 /vagrant/scripts/check-services.sh
```

## Optimisations Appliquées

Toutes les installations utilisent des configurations minimales optimisées pour l'environnement de développement :

- **Ressources CPU/Mémoire réduites** pour économiser les ressources
- **Nombre de répliques minimal** (généralement 1)
- **Mode d'authentification simplifié** pour Argo Workflows
- **Dashboard activé** pour Argo Rollouts

## Dépendances

- **Istio** est automatiquement installé si Argo Rollouts est activé (requis pour les fonctionnalités avancées)
- **Helm** est utilisé pour toutes les installations
- Les **charts officiels** sont utilisés depuis les repositories suivants :
  - Istio: `https://istio-release.storage.googleapis.com/charts`
  - Argo: `https://argoproj.github.io/argo-helm`

## Troubleshooting

### Services qui ne démarrent pas
```bash
# Vérifier les pods en erreur
kubectl get pods --all-namespaces | grep -v Running

# Voir les logs d'un pod spécifique
kubectl logs -n NAMESPACE POD_NAME

# Décrire un pod pour voir les événements
kubectl describe pod -n NAMESPACE POD_NAME
```

### Problèmes de ressources
Si le cluster manque de ressources, vous pouvez :

1. Désactiver certains services dans `settings.yaml`
2. Augmenter la mémoire des VMs dans `settings.yaml` :
   ```yaml
   nodes:
     control:
       memory: 6144  # Au lieu de 4096
     workers:
       memory: 4096  # Au lieu de 2048
   ```

### Réinstaller un service
```bash
# Supprimer l'installation Helm
helm uninstall SERVICE_NAME -n NAMESPACE

# Supprimer le namespace si nécessaire
kubectl delete namespace NAMESPACE

# Redémarrer la VM pour réinstaller
vagrant reload
```

## Accès depuis l'Host

Tous les services sont accessibles depuis votre machine hôte via port-forwarding. Les commandes sont fournies dans la sortie du script `check-services.sh`.

## Intégration avec ArgoCD

Si vous avez ArgoCD installé, vous pouvez l'utiliser pour déployer et gérer des applications utilisant ces services. Consultez la documentation ArgoCD pour plus de détails sur l'intégration avec Argo Workflows, Events, et Rollouts.