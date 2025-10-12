# Scalable-Web-Application-Using-Kubernetes
Docker, NginX, Helm, Ingress, Terraform and Jenkins to deploy an example app

## Application

Use a simple web application ([Hextris](https://github.com/Hextris/hextris))

Create a Dockerfile to containerize the application.

Provide a Helm chart to deploy the application.

### Generate/Run image (local test)

```
docker build -t hextris:latest .
docker run -d -p 80:80 --name hextris-test hextris:latest
```

## Kubernetes Cluster & Ingress Configuration

### Kubernetes Cluster Setup with Minikube

1. Start and Configure Minikube
```
# Start Minikube cluster
minikube start --memory=4096 --cpus=2

# Enable ingress addon (required for external access)
minikube addons enable ingress

# Verify cluster status
kubectl cluster-info
kubectl get nodes

# Check ingress controller
kubectl get pods -n ingress-nginx
```

2. Load Docker Image into Minikube
```
# Build your image first
docker build -t hextris:latest .

# Load image into Minikube (CRITICAL STEP)
minikube image load hextris:latest

# Verify image is available in Minikube
minikube image list | grep hextris
```

3. Deploy Application using Helm
```
# Navigate to helm chart directory
cd helm/hextris

# Install the application
helm install hextris . --namespace hextris --create-namespace

# Alternative: upgrade if already installed
helm upgrade --install hextris . --namespace hextris --create-namespace

# Verify deployment
kubectl get all -n hextris
```

4. Verify Deployment Status
```
# Check pods (should show 2 replicas running)
kubectl get pods -n hextris -o wide

# Check services
kubectl get svc -n hextris

# Check deployment status
kubectl get deployment -n hextris

# View pod details and resources
kubectl describe deployment hextris -n hextris
```

### Ingress Configuration

1. Check Ingress Resources
```
# Verify ingress controller is running
kubectl get pods -n ingress-nginx

# Check ingress resource
kubectl get ingress -n hextris

# View detailed ingress information
kubectl describe ingress hextris-ingress -n hextris
```

2. Configure Local DNS Access 
```
# Get Minikube IP address
minikube ip

# Add to hosts file (Linux/Mac)
echo "$(minikube ip) hextris.local" | sudo tee -a /etc/hosts

# For Windows, add to: C:\Windows\System32\drivers\etc\hosts
# <minikube-ip> hextris.local
```

3. Test the Application
```
# Test via curl
curl http://hextris.local

# Test load balancing between pods
for i in {1..10}; do
  curl -s http://hextris.local > /dev/null
  echo "Request $i completed"
done

# Check which pods received requests
kubectl get pods -n hextris -l app=hextris -o name | while read pod; do
  echo "=== $pod ==="
  kubectl logs -n hextris $pod --tail=5 | grep "GET /" | wc -l
done
```

4. Useful Monitoring Commands
```
# Watch all resources in real-time
kubectl get all -n hextris --watch

# Check pod resource usage
kubectl top pods -n hextris

# View application logs
kubectl logs -n hextris -l app=hextris --tail=10

# Check ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=5
```

#### Troubleshooting
```
# If pods are not starting, check events
kubectl get events -n hextris --sort-by=.metadata.creationTimestamp

# If image pull issues, verify image is loaded in Minikube
minikube ssh docker images | grep hextris

# If ingress not working, check ingress controller
kubectl get service -n ingress-nginx

# If DNS not resolving, try accessing via Minikube IP directly
curl http://$(minikube ip)
```

#### Scale Application
```
# Scale up to 3 replicas
kubectl scale deployment hextris --replicas=3 -n hextris

# Scale down to 1 replica
kubectl scale deployment hextris --replicas=1 -n hextris

# Use Helm to update replicas
helm upgrade hextris . --namespace hextris --set replicaCount=3
```

#### Verify Load Balancing
```
# Create test script to verify load distribution
cat > test-load-balancing.sh << 'EOF'
#!/bin/bash
echo "Testing load balancing across pods..."
for i in {1..20}; do
  curl -s http://hextris.local > /dev/null
  sleep 0.5
done

echo "Request distribution:"
kubectl get pods -n hextris -l app=hextris -o name | while read pod; do
  count=$(kubectl logs -n hextris $pod --since=1m | grep "GET /" | wc -l)
  echo "  $pod: $count requests"
done
EOF

chmod +x test-load-balancing.sh
./test-load-balancing.sh
```

### Jenkins Configuration
Used these IP tables commands so Minikube could respond Jenkins
```
sudo iptables -I INPUT -s 192.168.49.0/24 -p tcp --dport 8080 -j ACCEPT
sudo iptables -I INPUT -s 192.168.49.0/24 -p tcp --dport 50000 -j ACCEPT
```

Also apply Jenkins Role in Minikube
```
kubectl apply -f jenkins-role.yaml
```