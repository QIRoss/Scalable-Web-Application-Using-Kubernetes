pipeline {
    agent any
    
    triggers {
        pollSCM('* * * * *')  // Checa GitHub a cada minuto
    }
    
    environment {
        IMAGE_NAME = "hextris:${env.BUILD_NUMBER}"
        NAMESPACE = "hextris"
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Build Docker Image') {
            steps {
                sh """
                docker build -t ${IMAGE_NAME} .
                minikube image load ${IMAGE_NAME}
                """
            }
        }
        
        stage('Deploy to Minikube') {
            steps {
                sh """
                # Criar namespace se não existir
                kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
                
                # Deploy com Helm
                helm upgrade --install hextris ./helm/hextris \
                  --namespace ${NAMESPACE} \
                  --set image.tag=${env.BUILD_NUMBER} \
                  --set replicaCount=2 \
                  --wait
                """
            }
        }
        
        stage('Verify') {
            steps {
                sh """
                kubectl rollout status deployment/hextris -n ${NAMESPACE} --timeout=300s
                echo "✅ Deploy completed successfully!"
                """
            }
        }
    }
    
    post {
        always {
            sh "kubectl get pods -n ${NAMESPACE}"
        }
    }
}