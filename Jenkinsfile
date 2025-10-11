pipeline {
    agent {
        kubernetes {
            cloud 'minikube-local'
            label 'jenkins-agent'
            yamlFile 'helm/jenkins-agent/templates/pod-template.yaml'
        }
    }
    
    triggers {
        pollSCM('H/2 * * * *')
    }
    
    environment {
        IMAGE_NAME = "hextris"
        IMAGE_TAG = "${env.GIT_COMMIT ? env.GIT_COMMIT.substring(0, 7) : 'latest'}"
        K8S_NAMESPACE = "hextris"
    }
    
    stages {
        stage('Checkout & Setup') {
            steps {
                checkout scm
                container('kubectl') {
                    sh """
                    echo "🔧 Configurando ambiente..."
                    kubectl get nodes
                    kubectl get ns ${K8S_NAMESPACE} || kubectl create ns ${K8S_NAMESPACE}
                    """
                }
            }
        }
        
        stage('Build Docker Image') {
            steps {
                container('docker') {
                    script {
                        echo "🏗️ Building Docker image..."
                        sh """
                        docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
                        docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest
                        
                        echo "📋 Images built:"
                        docker images | grep ${IMAGE_NAME}
                        """
                    }
                }
            }
        }
        
        stage('Load to Minikube') {
            steps {
                container('docker') {
                    script {
                        echo "🎯 Loading image to Minikube..."
                        sh """
                        minikube image load ${IMAGE_NAME}:${IMAGE_TAG}
                        minikube image load ${IMAGE_NAME}:latest
                        
                        echo "✅ Images loaded to Minikube"
                        minikube image list | grep ${IMAGE_NAME} || echo "⚠️ No images found"
                        """
                    }
                }
            }
        }
        
        stage('Deploy to Kubernetes') {
            steps {
                container('kubectl') {
                    script {
                        echo "🚀 Deploying application..."
                        sh """
                        # Usar Helm para deploy
                        helm upgrade --install hextris ./helm/hextris/ \
                          --namespace ${K8S_NAMESPACE} \
                          --set image.repository=${IMAGE_NAME} \
                          --set image.tag=latest \
                          --wait --timeout 300s
                        
                        # Verificar deploy
                        kubectl get pods,svc -n ${K8S_NAMESPACE}
                        """
                    }
                }
            }
        }
        
        stage('Verify Deployment') {
            steps {
                container('kubectl') {
                    script {
                        echo "🔍 Verifying deployment..."
                        sh """
                        # Aguardar pods ficarem ready
                        kubectl wait --for=condition=ready pod -l app=hextris -n ${K8S_NAMESPACE} --timeout=120s
                        
                        # Verificar status
                        kubectl get deployment hextris -n ${K8S_NAMESPACE}
                        kubectl get pods -n ${K8S_NAMESPACE} -o wide
                        
                        echo "✅ Deployment verified!"
                        """
                    }
                }
            }
        }
        
        stage('Smoke Test') {
            steps {
                container('kubectl') {
                    script {
                        echo "🚬 Running smoke test..."
                        sh """
                        # Testar aplicação
                        kubectl port-forward -n ${K8S_NAMESPACE} service/hextris-service 8080:80 &
                        sleep 5
                        
                        echo "🌐 Testing application..."
                        curl -s http://localhost:8080 && echo "✅ Application is accessible" || echo "⚠️ Application not accessible"
                        
                        # Parar port-forward
                        pkill kubectl
                        """
                    }
                }
            }
        }
    }
    
    post {
        always {
            echo "📊 Pipeline execution completed"
            container('kubectl') {
                sh """
                echo "🎯 Final status:"
                kubectl get pods -n ${K8S_NAMESPACE}
                echo "🏷️ Image used: ${IMAGE_NAME}:${IMAGE_TAG}"
                """
            }
        }
        success {
            echo "🎉 Pipeline executado com sucesso!"
            script {
                currentBuild.description = "✅ Success - ${IMAGE_TAG}"
            }
        }
        failure {
            echo "❌ Pipeline falhou!"
            container('kubectl') {
                sh """
                echo "🔍 Debug information:"
                kubectl describe deployment hextris -n ${K8S_NAMESPACE} || true
                kubectl logs -n ${K8S_NAMESPACE} -l app=hextris --tail=20 || true
                """
            }
        }
    }
    
    options {
        timeout(time: 15, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '5'))
    }
}