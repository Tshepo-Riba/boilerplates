# Ollama Kubernetes Deployment

This repository contains Kubernetes manifests for deploying Ollama and its WebUI in a Kubernetes cluster. The deployment includes GPU support, persistent storage, and uses Kubernetes secrets for sensitive information.

## Prerequisites

- A Kubernetes cluster (version 1.16+)
- `kubectl` configured to communicate with your cluster
- GPU support in your cluster (if using GPU features)

## Components

The deployment consists of the following Kubernetes resources:

1. `namespace.yaml`: Defines the `ollama` namespace
2. `secret.yaml`: Stores the Ollama API key
3. `ollama-pvc.yaml`: Persistent Volume Claim for Ollama data
4. `ollama-deployment.yaml`: Deployment for the Ollama service
5. `ollama-service.yaml`: Service to expose Ollama API
6. `ollama-webui-deployment.yaml`: Deployment for Ollama WebUI
7. `ollama-webui-service.yaml`: Service to expose Ollama WebUI

## Deployment Steps

1. Clone this repository:
git clone <repository-url>

cd <repository-directory>

2. Update the `OLLAMA_API_KEY` in `secret.yaml` with your actual API key.

3. Apply the Kubernetes manifests in the following order:

```bash
kubectl apply -f namespace.yaml
kubectl apply -f secret.yaml
kubectl apply -f ollama-pvc.yaml
kubectl apply -f ollama-deployment.yaml
kubectl apply -f ollama-service.yaml
kubectl apply -f ollama-webui-deployment.yaml
kubectl apply -f ollama-webui-service.yaml
```
```bash
kubectl apply -f .
```
## Customization
### GPU Support
The Ollama deployment is configured for NVIDIA GPUs by default. To use AMD GPUs:

1. Open ollama-deployment.yaml
2. In the resources section, comment out the NVIDIA GPU limit and uncomment the AMD GPU limit:
 ```bash 
resources:
  limits:
    # nvidia.com/gpu: 1  # For NVIDIA GPUs
    amd.com/gpu: 1   # For AMD GPUs
```
### Storage
The Persistent Volume Claim (ollama-pvc.yaml) is set to request 10Gi of storage. Adjust this value based on your needs:
 ```bash 
resources:
  requests:
    storage: 10Gi  # Modify this value as needed
```
### Scaling
To adjust the number of replicas for Ollama or its WebUI, modify the replicas field in the respective deployment files.

#### Accessing the Services
- Ollama API: The Ollama service is exposed within the cluster at ollama.ollama.svc.cluster.local:11434
- Ollama WebUI: The WebUI service is exposed within the cluster at ollama-webui.ollama.svc.cluster.local:3000

To access these services externally, you may need to set up an Ingress or use a LoadBalancer service type, depending on your cluster configuration.

### Troubleshooting
1. Check the status of the pods:
    ```bash 
    kubectl get pods -n ollama
    ```
2. View logs for a specific pod:
    ```bash 
    kubectl logs <pod-name> -n ollama
    ```
3. Describe a pod for more details:
    ```bash 
    kubectl describe pod <pod-name> -n ollama
    ```