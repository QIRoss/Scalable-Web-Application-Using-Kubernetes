pipeline {
    agent {
        kubernetes {
            cloud 'minikube-local'
            yaml """
apiVersion: v1
kind: Pod
metadata:
  namespace: hextris
spec:
  containers:
  - name: jnlp
    image: jenkins/inbound-agent:latest
    args: ['\$(JENKINS_SECRET)', '\$(JENKINS_NAME)']
  
  - name: docker
    image: docker:latest
    command: ['sleep']
    args: ['infinity']
    volumeMounts:
    - name: docker-sock
      mountPath: /var/run/docker.sock

  - name: kubectl
    image: bitnami/kubectl:latest
    command: ['sleep']
    args: ['infinity']

  volumes:
  - name: docker-sock
    hostPath:
      path: /var/run/docker.sock
"""
        }
    }
    
    environment {
        IMAGE_NAME = "hextris"
        IMAGE_TAG = "latest"
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                echo "📦 Repository: ${env.GIT_URL}"
            }
        }
        
        stage('Build Docker Image') {
            steps {
                container('docker') {
                    sh """
                    echo "🏗️ Building Docker image..."
                    docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
                    echo "📋 Images built:"
                    docker images | grep ${IMAGE_NAME}
                    """
                }
            }
        }
        
        stage('Load to Minikube') {
            steps {
                container('docker') {
                    sh """
                    echo "🎯 Loading image to Minikube..."
                    minikube image load ${IMAGE_NAME}:${IMAGE_TAG}
                    """
                }
            }
        }
        
        stage('Deploy') {
            steps {
                container('kubectl') {
                    sh """
                    echo "🚀 Deploying to Kubernetes..."
                    kubectl set image deployment/hextris hextris=${IMAGE_NAME}:${IMAGE_TAG} -n hextris
                    sleep 10
                    kubectl get pods -n hextris
                    """
                }
            }
        }
    }
    
    post {
        always {
            echo "✅ Pipeline completed"
        }
    }
}