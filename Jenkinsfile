pipeline {
    agent {
        kubernetes {
            cloud 'minikube-local'
            label 'jenkins-agent'
            yamlFile 'jenkins-pod-template.yaml'
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
                echo "📦 Repository: ${env.GIT_URL}"
            }
        }
        
        stage('Verify Kubernetes Access') {
            steps {
                container('kubectl') {
                    sh """
                    echo "🔧 Verificando acesso ao Kubernetes..."
                    kubectl get nodes
                    kubectl get ns ${K8S_NAMESPACE} || kubectl create ns ${K8S_NAMESPACE}
                    echo "✅ Kubernetes access verified"
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
                        # Deploy usando Helm
                        helm upgrade --install hextris ./helm/hextris/ \
                          --namespace ${K8S_NAMESPACE} \
                          --set image.repository=${IMAGE_NAME} \
                          --set image.tag=latest \
                          --wait --timeout 300s
                        
                        echo "📊 Deployment status:"
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
                        echo "✅ Deployment verified!"
                        """
                    }
                }
            }
        }
    }
    
    post {
        always {
            echo "📊 Pipeline execution completed"
            script {
                // Removemos o container do post para evitar o erro de contexto
                echo "🏷️ Image used: ${IMAGE_NAME}:${IMAGE_TAG}"
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
        }
    }
    
    options {
        timeout(time: 15, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '5'))
    }
}